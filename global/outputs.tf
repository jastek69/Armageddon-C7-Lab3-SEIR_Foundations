output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.galactus_cf01.id
  description = "CloudFront distribution ID."
}

output "cloudfront_distribution_domain_name" {
  value       = aws_cloudfront_distribution.galactus_cf01.domain_name
  description = "CloudFront distribution domain name."
}

output "cloudfront_logs_bucket" {
  value       = data.aws_s3_bucket.cloudfront_logs.bucket
  description = "CloudFront standard logs bucket."
}

output "route53_zone_id" {
  value       = data.aws_route53_zone.main.zone_id
  description = "Route53 hosted zone ID."
}

output "origin_fqdn" {
  value       = local.alb_origin_fqdn
  description = "Origin hostname used by CloudFront."
}

output "cloudfront_waf_arn" {
  value       = aws_wafv2_web_acl.taaops_cf_waf01.arn
  description = "CloudFront WAF Web ACL ARN."
}
