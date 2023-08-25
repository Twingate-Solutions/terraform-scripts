# HOW TO USE

1. AWS Credentials (export or terraform.tfvars)
    - Choose 1 of the following methods for adding AWS credentials:
        - **Export to terminal/shell:** copy and paste to terminal/shell from AWS console (command line or programmatic access)
        - **Add to terraform.tfvars:** uncomment lines 10:30 in variables.tf and lines 18:22 in providers.tf and fill out (command line or programmatic access)


2. Fill out terraform.tfvars
    - Specify AWS settings
        - Application name
        - AWS Region
        - VPC CIDR Block
    - Specify Twingate settings
        - Pull an api key from the admin console (read, write, & provision)
        - Grab network slug (<slug>.twingate.com)
        - Grab user ids that you want to use to access the connector + private resource (Admin Console -> Team -> Users -> <USER> -> Grab ID from URL <slug>.twingate.com/users/<userID>)
        - Specify analytics version and log level


3. Generate public SSH key and align path in aws_ec2.tf to where it is stored
    - Terminal/shell:
        - ssh-keygen -b 4096
        - /Users/<User>/.ssh/aws_id_rsa
    - Update file path in aws_ec2.tf for aws_key_pair resource

4. Terraform init       (pull the required dependencies)
5. Terraform plan       (plan out what will be implemented and check for errors)
6. Terraform apply      (apply the plan)
7. Terraform destroy    (tear down the infrastructure when finished)

## Accessing the Resource
* Ensure you are logged into the client with access to the Twingate network specified
* ssh -i ~/.ssh/aws_id_rsa ubuntu@tf-demo-aws.server (may require adjustment of known_hosts file or specifying an IP as the destination - the IPs change on VM startup if terraform destroy/apply are used)
