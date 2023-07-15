.PHONY: init deploy deploy\:hosted-zone invalidate_cf_cache

init:
	terraform init

deploy\:hosted-zone: init
	terraform apply -target=module.website.aws_route53_zone.primary

deploy: deploy\:hosted-zone
	terraform apply

invalidate_cf_cache:
	aws cloudfront create-invalidation --paths /* --distribution-id $(shell terraform output cloudfront_distribution_id)
