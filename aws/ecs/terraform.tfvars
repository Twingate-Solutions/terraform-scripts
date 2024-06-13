##############################################################
#
# AWS
#
##############################################################

# Tags
app_name                    = "tg-tf-demo"                             
app_environment             = "demo"                                    

# Region
aws_region                  = "ca-central-1"                       

# VPC
aws_vpc_cidr_block          = "10.37.0.0/16"                      

##############################################################
#
# Twingate
#
##############################################################

# Twingate api token (pulled from the Twingate admin console)
tg_api_token                = ""                                      

# Twingate network (your tenant name, i.e. "twindemo" from twindemo.twingate.com)
tg_network                  = ""                                     

# Twingate users allowed access to connector + private resource (pulled from URL in Twingate admin console, i.e. ["VXNabc=", "VXNdef="] from twindemo.twingate.com/users/VXNabc=)
tg_users                    = ["",""]                                  

# Twingate connector details (remove tg_log_level if debug logging isn't needed)
tg_log_analytics_version    = "v2"
tg_log_level                = "3"     # The default is 3, but can be set to 7 for debug
