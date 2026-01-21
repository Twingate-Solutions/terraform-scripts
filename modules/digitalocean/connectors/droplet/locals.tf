locals {
  # Generate label ID based on label_order variable
  # Combines name and environment in the order specified
  labels_id = join("-", [
    for label in var.label_order :
    label == "name" ? var.name :
    label == "environment" ? var.environment :
    label == "managedby" ? var.managedby :
    ""
    if label != ""
  ])

  # SSH key IDs extracted from created SSH key resources
  ssh_key_ids = [for key, ssh_key in digitalocean_ssh_key.ssh_keys : ssh_key.id]
}