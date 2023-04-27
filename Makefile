deploy\:hosted-zone:
	terraform apply -target=module.website.aws_route53_zone.primary

deploy: deploy\:hosted-zone:
	terraform apply
