output "nameservers" {
    value = module.website.domain_name_servers
}

output "s3_information" {
    value = {
        "bucket_name" : module.website.bucket_name,
        "upload_command" : module.website.content_upload_command
    }
}

output "cloudfront_distribution_id" {
    value = module.website.cloudfront_distribution_id
}
