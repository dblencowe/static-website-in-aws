# Introduction
By the end of this tutorial, we'll have set up the required AWS services 
for securely hosting a static website.

In our example, we'll use a simple HTML page to demonstrate the project is 
working, but the process is exactly the same for a more complicated static
site, such as a Vue or React App.

## A brief introduction to the components
By the end of this project, we'll be hosting our website on AWS using 
several different services, below is a little about the roles they'll
play;

### S3
AWS S3 is an object storage service. In terms of our project, we'll be
using it to store our website's production files, an index.html file
displaying a Hello World message.

### CloudFront
AWS CloudFront is a Content Delivery Network (CDN). The CDN will be
responsible for replicating our files from S3 into multiple regions.
This lowers the the response time of the website, regardless of the
geographical location the user is accessing the site.

### Route53
AWS Route53 will control the DNS for our website. It handles translating
our domain name into a location within the AWS network so that when a user
loads your website in their browser it knows where to connect them to.

### Certificate Manager
We'll use AWS Certificate Manager to generate an SSL certificate for our 
website. If you don't know about the benefits of SSL you can read more 
about them [here](https://www.https.in/blog/the-benefits-of-ssl-certificate/), 
although, SSL / HTTPS is the standard and is almost universally expected by 
consumers.

## Getting Started
If you've not used Terraform before you'll need to install it on your machine 
for this article. Instructions on how to do this can be found on the Terraform 
website [here](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
If you want to learn a bit more about what Terraform is, then have a read of 
[this](https://developer.hashicorp.com/terraform/intro).

If you've not setup AWS for command line access before, please read 
[this](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html#cli-quick-configuration).

## Terraform File Structure
Terraform is pretty flexible with how you can layout your infrastructure files. 
The techniques applied in this article will create a Terraform Module, with 
variables that will allow you to create multiple static websites without re-creating 
the entire project each time.

We start by creating the file structure we require, then fill out each one below.

The following commands will create the files and directories
```bash
mkdir -p modules/static-site
touch main.tf
touch inputs.tf
touch terraform.tf
```

### A quick list of what each file will do
#### terraform.tf
The terraform.tf file defines what external providers we'll be using in this project.
In our case we only need the AWS provider.

### main.tf
The main terraform file for our application, where we'll setup our static sites by 
including our module and passing in the relevant variables

### inputs.tf
The inputs.tf file is used for defining the root level variables we need for our project.
In our case we only need to define the AWS region we'd like to use for our application.

## The static site module
The files for the static site module will be placed within the `modules/static-site` 
directory and will define the components talked about within the introduction section by 
creating an S3 Bucket for storing the website, give it appropriate permissions & create a 
CloudFront distribution which will be responsible for serving the content securely to the 
end user using SSL.

## Create an S3 Bucket
We're going to use S3 to store the files used in our website. We'll begin by creating an 
S3.tf file that will contain any Terraform commands performed against S3. This service by 
service separation allows us to quickly see what services a module accesses just by looking 
at the file structure and helps us keep individual files small. Terraform includes all .tf 
files in the directory so you could use whatever method of sorting you prefer.

```bash
touch modules/static-site/s3.tf
```

Within this file we're going to define 5 resources; aws_s3_bucket, aws_s3_bucket_configuration,
aws_s3_bucket_acl, aws_s3_bucket_policy and aws_s3_bucket_ownership_controls. Together these 5 resources will create our S3 
bucket and then apply the appropriate permissions for hosting a static website.

```tf
# ./modules/static-website/s3.tf
resource "aws_s3_bucket" "website" {
    bucket = var.domain_name
}

resource "aws_s3_bucket_website_configuration" "website" {
    bucket = aws_s3_bucket.website.id

    index_document {
      suffix = "index.html"
    }

    error_document {
        key = "index.html"
    }
}

resource "aws_s3_bucket_acl" "website" {
    bucket = aws_s3_bucket.website.id

    acl = "private"
}

resource "aws_s3_bucket_policy" "website" {
    bucket = aws_s3_bucket.website.id
    policy = data.aws_iam_policy_document.website_policy.json 
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "ObjectWriter"
  }
}
```

Properties for several of these resources are automatically inferred by terraform in one of 
two ways.

```tf
resource "aws_s3_bucket_policy" "website" {
    bucket = aws_s3_bucket.website.id
    policy = data.aws_iam_policy_document.website_policy.json 
}
```
The first method, to populate the bucket property, references the aws_s3_bucket resource that 
we've defined elsewhere (earlier in this file) in our module.

The second method, to populate the policy attribute, uses a Terraform data resource to generate 
the input. You can read more about data resources [here](https://developer.hashicorp.com/terraform/language/data-sources)

We've used the variable (var.domain_name) as our bucket name, this is because bucket names 
have to be globally unique, and using our unique domain name makes mapping records to the 
bucket in Route53 easier. We want to define this as a module variable by adding the following 
code to our **inputs.tf**:

```tf
# ./modules/static-site/inputs.tf
variable "domain_name" {
    description = "Domain name for the static site"
    type = string
}
```

## Create an IAM policy document to manage bucket permissions
In order to allow the outside world to access our website we need to define an appropriate 
IAM Policy. To do this we'll use the terraform aws_iam_policy_document data source.

Create an iam.tf file for holding our data source:

```bash
touch ./modules/static-site/iam.tf
```

Create an IAM policy document using the [aws_iam_policy_document](https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html) data source:

```tf
# ./modules/static-site/iam.tf
data "aws_iam_policy_document" "website_policy" {
    statement {
        actions = [
            "s3:GetObject",
            "s3:ListBucket"
        ]

        principals {
            identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
            type = "AWS"
        }

        resources = [
            "arn:aws:s3:::${var.domain_name}/*",
            "arn:aws:s3:::${var.domain_name}"
        ]
    }
}
```

This document will provide CloudFront with permission to get objects within the bucket 
specified within the resources block (in this case the bucket we created earlier).

## Create an SSL Certificate using ACM
To generate an SSL certificate for our website we're going to Amazons certificate service ACM.
We'll then use this certificate to serve https encrypted content via CloudFront.
The first step is to create an acm.tf file.

```bash
touch modules/static-site/acm.tf
```

We'll then define the resources to create our certificate in this file

```tf
# ./modules/static-site/acm.tf
resource "aws_acm_certificate" "website_cert" {
  domain_name = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
```

As we've specified DNS validation for our certificate, ACM will requre a CNAME record created 
for the domain which validates ownership. Fortunately we can automate this process too.

## Create a CloudFront distribution to serve our content
To bring all of this together we're going to create a CloudFront Distribution. It will be 
responsible for accepting browser requests for our website and serving the content from our 
S3 bucket back via a HTTPS encrypted connection.

First create the cloudfront.tf file
```bash
touch modules/static-site/cloudfront.tf
```

We then define resources for our Distribution and the identity it'll use when accessing other 
AWS services.
```tf
# ./modules/static-site/cloudfront.tf
resource "aws_cloudfront_origin_access_identity" "oai" {}

resource "aws_cloudfront_distribution" "cloudfront" {
  default_root_object = "index.html"
  enabled = true
  is_ipv6_enabled = true
  aliases = [var.domain_name]
  # Distributes content to US and Europe
  price_class = "PriceClass_100"
  
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id = "S3-${aws_s3_bucket.website.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  custom_error_response {
    error_caching_min_ttl = 3000
    error_code = 404
    response_code = 200
    response_page_path = "/index.html"
  }

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400

    forwarded_values {
      query_string = true
       cookies {
          forward = "none"
       }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.website_cert.arn
    ssl_support_method = "sni-only"
  }
}

resource "aws_acm_certificate_validation" "website_cert" {
  certificate_arn = aws_acm_certificate.website_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation: record.fqdn]  
}
```

## Setup Route53 to handle our domain
Finally, when a user enters your website address in their browser it performs a series of 
background operations to translate that domain into a location of where to find the content.
To handle our websites DNS we're going to use Amazons Route53 service to route these requests 
to our CloudFront distribution.

First create a route53.tf file to hold our resources
```bash
touch modules/static-site/route53.tf
```

Within this file we'll define resources for a Hosted Zone and within it create records 
for routing requests to our website and validating the SSL certificate that we created with ACM. 
```tf
resource "aws_route53_zone" "primary" {
    name = var.domain_name
}

resource "aws_route53_record" "www" {
    zone_id = aws_route53_zone.primary.zone_id
    name = var.domain_name
    type = "A"

    alias {
        name = aws_cloudfront_distribution.cloudfront.domain_name
        zone_id = aws_cloudfront_distribution.cloudfront.hosted_zone_id
        evaluate_target_health = false
    }
}

resource "aws_route53_record" "cert_validation" {
    for_each = {
        for dvo in aws_acm_certificate.website_cert.domain_validation_options: dvo.domain_name => {
            name   = dvo.resource_record_name
            record = dvo.resource_record_value
            type   = dvo.resource_record_type
        }
    }
    allow_overwrite = true
    name            = each.value.name
    records         = [each.value.record]
    ttl             = 60
    type            = each.value.type
    zone_id         = aws_route53_zone.primary.zone_id
}
```

## Create main.tf file
Finally add the below to the main.tf file to tell terraform to run the static-site module and 
pass the domain_name from the input.
```tf
module "website" {
    source      = "./modules/static-site"
    domain_name = var.domain_name
}
```


Once created the Hosted Zone will be assigned 4 AWS Nameservers. To finalise setting up 
the website you'll need to update your domains nameservers at it's registrar. AWS provides 
helpful guide on how to do this [here](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/migrate-dns-domain-in-use.html#migrate-dns-change-name-servers-with-provider)
