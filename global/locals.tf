locals {
  alb_origin_fqdn = "${var.alb_origin_subdomain}.${var.domain_name}"

  cloudfront_acm_cert_arn = var.cloudfront_acm_cert_arn != "" ? var.cloudfront_acm_cert_arn : aws_acm_certificate.cloudfront[0].arn
}
