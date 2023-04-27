resource "aws_s3_bucket" "website" {
    bucket_prefix = var.domain_name
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