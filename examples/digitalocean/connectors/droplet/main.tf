module "droplet" {
    source             = "../../../../modules/digitalocean/connectors/droplet"
    #version            = "0.0.1"
    name               = "droplet"
    environment        = "twingate-poc"
    label_order        = ["environment", "name"]
    droplet_count      = 1
    region             = "bangalore-1"
    ssh_keys           =  [module.ssh_key.fingerprint]
    vpc_uuid           = module.vpc.id
    droplet_size       = "nano"
    monitoring         = false
    private_networking = true
    ipv6               = false
    floating_ip        = true
    block_storage_size = 5
    user_data          = file("user-data.sh")
}