# Twingate TF Quickstart for AWS (EC2 Deployment)

The Twingate SE team built this quickstart to serve as a guide in deploying Twingate using Terraform to AWS. This script is apply-ready OOTB and will stand up a sandbox demo environment for testing purposes. The sandbox demo environment consists of:

- AWS VPC, Public & Private Subnets, Route Tables, NAT & Internet Gateways, EIPs, Security Groups, VPC Peering (Optional), & a Private Hosted Zone (Optional)
- Twingate Remote Network, Connector, Private Resource

There are two approaches to deploying Connectors for this quickstart.

#### Private Subnet Deployment:

![Private Subnet Deployment](./aws-ec2-cd-private.png)

-or-

#### Public Subnet Deployment:

![Public Subnet Deployment](./aws-ec2-cd-public.png)

## Important (Optional) Callouts

### Peer-to-peer connectivity

This script uses [fck-nat](https://fck-nat.dev/) as the NAT gateway for the Connector, since it is a cost-effective alternative to AWS's managed NAT gateway and is considered NAT traversal-friendly that supports peer-to-peer connectivity OOTB (another great alternative is [Cohesive's VNS3 NATe](https://www.cohesive.net/vns3/cloud-nat/)). If you choose to use AWS's managed NAT gateway and require peer-to-peer connectivity, refer to Twingate's section on [What to do if your Connector is behind an incompatible NAT](https://www.twingate.com/docs/troubleshooting-p2p#what-to-do-if-your-connector-is-behind-an-incompatible-nat).

### Private Hosted Zone

This quickstart includes standing up a private hosted zone to resolve a FQDN within the AWS VPC by default. The address on the Twingate resource has lines commented out if an IP-based address is desired instead.

### VPC Peering

This quickstart also includes a VPC peering connection by default. This is useful if there is a need to connect the sandbox VPC to existing infrastructure.

## How to Setup & Use

1. AWS Credentials (choose either):

   - **Export to terminal/shell:** copy and paste to terminal/shell from AWS console (command line or programmatic access)
   - **Add to terraform.tfvars:** uncomment lines 10:30 in variables.tf and lines 18:22 in providers.tf and fill out (command line or programmatic access)

2. Fill out terraform.tfvars

   - Specify AWS settings
     - Application name
     - AWS Region
     - VPC CIDR Block
     - SSH key to use
     - VPC peering
   - Specify Twingate settings
     - Pull an api key from the admin console (read, write, & provision)
     - Grab network slug (`<slug>.twingate.com`)
     - Grab user ids that you want to use to access the connector + private resource (Admin Console -> Team -> Users -> `<USER>` -> Grab ID from URL `<slug>.twingate.com/users/<userID>`)
     - Specify analytics version and log level

3. Decide whether you want to deploy connector in a private or public subnet (lines 19:79 in aws_ec2.tf). Diagrams provided for both [private](./aws-ec2-cd-private.png) and [public](./aws-ec2-cd-public.png) subnet deployments.

4. Create a Policy in the Twingate admin console named `Trusted-30Day-noMFA` to work with the existing data source in the script (otherwise change it to one that exists in your tenant)

5. Run the script
   - `Terraform init` (pull the required dependencies)
   - `Terraform plan` (plan out what will be implemented and check for errors)
   - `Terraform apply` (apply the plan)
6. Remove the instructure when finished
   - `Terraform destroy` (tear down the infrastructure when finished)

## Accessing the Resource

- Ensure you are logged into the client with access to the Twingate network specified
- SSH = `ssh -i ~/.ssh/<your_key_here> ubuntu@tg-tf-demo.int` (swap for your SSH key)
- Web = Navigate to `tg-tf-demo.int` in your browser
