output "domain_name_servers" {
    value = aws_route53_zone.primary.name_servers
}

output "bucket_name" {
    value = aws_s3_bucket.website.id
}

output "content_upload_command" {
    value = "aws s3 sync dist s3://${aws_s3_bucket.website.id}"
}

output "cloudfront_distribution_id" {
    value = aws_cloudfront_distribution.cloudfront.id
}
