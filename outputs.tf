output "nameservers" {
    value = module.website.domain_name_servers
}

output "s3_information" {
    value = {
        "bucket_name" : module.website.bucket_name,
        "upload_command" : module.website.content_upload_command
    }
}
