##############################################################
#
# AWS
#
##############################################################

# Tags
app_name                    = "tg-tf-demo"                             
app_environment             = "demo"                                    

# Region
aws_region                  = "us-west-1"                       

# VPC
aws_vpc_cidr_block          = "10.37.0.0/16"        

# Existing SSH key
aws_ssh_key_pair            = "my-key-pair-1"

# VPC Peering
enable_vpc_peering          = true
peer_vpc_id                 = "vpc-XXXXXXXXXXXX"
peer_region                 = "us-east-1"
peer_vpc_cidr_block         = "10.49.0.0/16"

##############################################################
#
# Twingate
#
##############################################################

# Twingate api token (pulled from the Twingate admin console)
tg_api_token                = "<TG_KEY>"                                      

# Twingate network (your tenant name, i.e. "twindemo" from twindemo.twingate.com)
tg_network                  = "<TENANT>"                                     

# Twingate users allowed access to connector + private resource (pulled from URL in Twingate admin console, i.e. ["VXNabc=", "VXNdef="] from twindemo.twingate.com/users/VXNabc=)
tg_users                    = ["VXNlcjoyXXXXXXX="]                                  

# Example existing Twingate groups
tg_eng_group                = ""

# Twingate connector details (remove tg_log_level if debug logging isn't needed)
tg_log_analytics_version    = "v2"
tg_log_level                = "3"     # The default is 3, but can be set to 7 for debug
