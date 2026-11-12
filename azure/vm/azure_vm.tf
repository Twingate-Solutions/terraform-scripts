##############################################################
#
# Admin SSH Key
#
##############################################################

# Azure requires an admin credential on Linux VMs. Without
# azure_ssh_public_key a throwaway key is generated; its private
# half stays in Terraform state only (no SSH access is intended).
resource "tls_private_key" "admin" {
  count = var.azure_ssh_public_key == null ? 1 : 0

  algorithm = "ED25519"
}

locals {
  admin_ssh_public_key = trimspace(coalesce(var.azure_ssh_public_key, one(tls_private_key.admin[*].public_key_openssh)))

  # Plain VMs need no subnet delegation
  private_subnet_delegation = null

  # Ubuntu 24.04 LTS (Gen2)
  ubuntu_image = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

##############################################################
#
# Twingate Connector VMs
#
##############################################################

resource "azurerm_network_interface" "connector" {
  count = var.tg_connector_count

  name                = "${var.app_name}-connector-${count.index + 1}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags

  # Private IP only; egress through the NAT gateway
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# One VM per Connector, spread across zones. Installed with Twingate's
# Linux setup script (systemd package); tokens land in custom_data and
# /etc/twingate/connector.conf in plaintext, as in Twingate's own guide.
resource "azurerm_linux_virtual_machine" "connector" {
  count = var.tg_connector_count

  name                  = "${var.app_name}-connector-${count.index + 1}"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = var.azure_connector_vm_size
  zone                  = length(var.azure_zones) == 0 ? null : var.azure_zones[count.index % length(var.azure_zones)]
  admin_username        = var.azure_admin_username
  network_interface_ids = [azurerm_network_interface.connector[count.index].id]
  tags                  = local.common_tags

  admin_ssh_key {
    username   = var.azure_admin_username
    public_key = local.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = local.ubuntu_image.publisher
    offer     = local.ubuntu_image.offer
    sku       = local.ubuntu_image.sku
    version   = local.ubuntu_image.version
  }

  # cloud-init runs custom_data once, at first boot. Retries cover the NAT
  # path or package mirrors not being reachable yet and dpkg locks held by
  # unattended-upgrades. setup.sh writes network, tokens and log analytics
  # (connector.conf is written last, after the package installs); log level
  # and the deployed-by label are appended afterwards. A non-zero exit is
  # recorded by cloud-init (`cloud-init status`).
  custom_data = base64encode(<<-EOT
    #!/bin/bash
    set -uo pipefail
    export DEBIAN_FRONTEND=noninteractive
    CONF=/etc/twingate/connector.conf
    SETUP=/run/twingate-connector-setup.sh

    # Already configured by an earlier run
    grep -qs '^TWINGATE_LABEL_DEPLOYED_BY=' "$CONF" && exit 0

    # setup.sh calls apt without a lock timeout; make every apt call wait for dpkg locks
    echo 'DPkg::Lock::Timeout "300";' > /etc/apt/apt.conf.d/90twingate-lock-timeout

    for attempt in $(seq 1 10); do
      # setup.sh refuses to run when connector.conf exists. A file holding the
      # tokens means a previous attempt installed the package and only the
      # service start failed (handled below); anything less is discarded.
      if [ -f "$CONF" ]; then
        grep -q '^TWINGATE_REFRESH_TOKEN=' "$CONF" && break
        rm -f "$CONF"
      fi
      curl -fsSL --retry 3 -o "$SETUP" https://binaries.twingate.com/connector/setup.sh && \
        TWINGATE_NETWORK="${var.tg_network}" \
        TWINGATE_ACCESS_TOKEN="${twingate_connector_tokens.this[count.index].access_token}" \
        TWINGATE_REFRESH_TOKEN="${twingate_connector_tokens.this[count.index].refresh_token}" \
        TWINGATE_LOG_ANALYTICS="${var.tg_log_analytics_version}" \
        bash "$SETUP" && break
      echo "Twingate Connector install attempt $attempt failed; retrying in 30s"
      sleep 30
    done
    rm -f "$SETUP"
    grep -qs '^TWINGATE_REFRESH_TOKEN=' "$CONF" || { echo "Twingate Connector install failed"; exit 1; }

    # Settings the installer does not write
    {
      echo TWINGATE_LOG_LEVEL="${var.tg_log_level}"
      echo TWINGATE_LABEL_DEPLOYED_BY="terraform-azure-vm"
    } >> "$CONF"
    systemctl enable twingate-connector && systemctl restart twingate-connector
  EOT
  )

  # Private-subnet VMs need the NAT path in place before first boot
  depends_on = [
    azurerm_subnet_nat_gateway_association.private,
    azurerm_nat_gateway_public_ip_association.this,
    azurerm_subnet_network_security_group_association.private,
  ]
}

##############################################################
#
# Private Resource VM (nginx on Ubuntu 24.04)
#
##############################################################

resource "azurerm_network_interface" "private_resource" {
  name                = "${var.app_name}-resource-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "private_resource" {
  name                  = "${var.app_name}-resource"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = "Standard_B2ats_v2"
  admin_username        = var.azure_admin_username
  network_interface_ids = [azurerm_network_interface.private_resource.id]
  tags                  = local.common_tags

  admin_ssh_key {
    username   = var.azure_admin_username
    public_key = local.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = local.ubuntu_image.publisher
    offer     = local.ubuntu_image.offer
    sku       = local.ubuntu_image.sku
    version   = local.ubuntu_image.version
  }

  # Runs once at first boot; retries cover NAT/mirrors not ready and dpkg locks
  custom_data = base64encode(<<-EOT
    #!/bin/bash
    set -uo pipefail
    export DEBIAN_FRONTEND=noninteractive
    command -v nginx >/dev/null && exit 0
    for attempt in $(seq 1 10); do
      apt-get -o DPkg::Lock::Timeout=300 update && \
        apt-get -o DPkg::Lock::Timeout=300 install -y nginx && exit 0
      echo "nginx install attempt $attempt failed; retrying in 30s"
      sleep 30
    done
    echo "nginx install failed"
    exit 1
  EOT
  )

  depends_on = [
    azurerm_subnet_nat_gateway_association.private,
    azurerm_nat_gateway_public_ip_association.this,
    azurerm_subnet_network_security_group_association.private,
  ]
}

##############################################################
#
# Azure Private DNS (FQDN for the private resource)
#
##############################################################

resource "azurerm_private_dns_zone" "this" {
  name                = var.azure_dns_zone_name
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                = "${var.app_name}-vnet-link"
  private_dns_zone_id = azurerm_private_dns_zone.this.id
  virtual_network_id  = azurerm_virtual_network.this.id
  tags                = local.common_tags
}

resource "azurerm_private_dns_a_record" "private_resource" {
  name                = "web-vm"
  private_dns_zone_id = azurerm_private_dns_zone.this.id
  ttl                 = 300
  records             = [azurerm_network_interface.private_resource.private_ip_address]
  tags                = local.common_tags
}
