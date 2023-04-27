resource "aws_route53_zone" "primary" {
    name = var.domain_name

    # lifecycle {
    #     prevent_destroy = true
    # }
}

resource "aws_route53_record" "domain" {
    zone_id = aws_route53_zone.primary.zone_id
    name = var.domain_name
    type = "A"

    alias {
        name = aws_cloudfront_distribution.cloudfront.domain_name
        zone_id = aws_cloudfront_distribution.cloudfront.hosted_zone_id
        evaluate_target_health = false
    }
}

resource "aws_route53_record" "www" {
    zone_id = aws_route53_zone.primary.zone_id
    name = "www"
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

resource "aws_route53_record" "domain_ownership_cname" {
    zone_id = aws_route53_zone.primary.zone_id
    name = "_."
    type = "TXT"
    ttl = 900
    records = [aws_cloudfront_distribution.cloudfront.domain_name]
}

resource "aws_route53_record" "www_domain_ownership_cname" {
    zone_id = aws_route53_zone.primary.zone_id
    name = "_www"
    type = "TXT"
    ttl = 900
    records = [aws_cloudfront_distribution.cloudfront.domain_name]
}
