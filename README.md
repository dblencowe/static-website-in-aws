# Secure Static Website on AWS using Terraform Modules

This Terraform module allows you create multiple static websites hosted on AWS, 
complete with https encryption.

## A Chicken / Egg Problem
In order to run this module in its entirety you must be able to validate the ACM 
Certificate using DNS validation, but DNS is configured as part of the this module.

To bypass this restriction, you can create the Route53 Hosted Zone using the below 
command and update your domains Name Servers using this [AWS Help Guide](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/migrate-dns-domain-in-use.html#migrate-dns-change-name-servers-with-provider).

```bash
terraform apply -target=module.website.aws_route53_zone.primary
```

You can check when your domains DNS has been updated by running the dig command below
```bash
dig ns example.com
```

## Usage

Edit the main.tf file to suit your needs. The module block can be repeated to setup multiple 
websites.
```tf
module "example_com" {
    source = "./modules/static-site"
    domain_name = "example.com"
}
```

Run [terraform](httos://terraform.io) to create the resources within your AWS account. 

```bash
terraform init
terraform apply
```

Update your domains nameservers at its registrar.

See docs/tutorial.md for more information
