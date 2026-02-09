# CloudFront Distribution for global entry point

resource "random_password" "galactus_origin_header_value01" {
  length  = 32
  special = false
}

resource "aws_cloudfront_distribution" "galactus_cf01" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.project_name}-cf01"

  logging_config {
    bucket          = data.aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  origin {
    origin_id   = "${var.project_name}-alb-origin01"
    domain_name = local.alb_origin_fqdn

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-Galactus-Code"
      value = random_password.galactus_origin_header_value01.result
    }
  }

  default_cache_behavior {
    target_origin_id       = "${var.project_name}-alb-origin01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.galactus_caching_disabled01.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.galactus_orp_all_viewer_except_host01.id
  }

  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "${var.project_name}-alb-origin01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id            = data.aws_cloudfront_cache_policy.galactus_cache_static01.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.galactus_orp_static01.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.galactus_rsp_static01.id
  }

  ordered_cache_behavior {
    path_pattern           = "/api/public-feed"
    target_origin_id       = "${var.project_name}-alb-origin01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.galactus_use_origin_cache_headers01.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.galactus_orp_all_viewer_except_host01.id
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "${var.project_name}-alb-origin01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.galactus_caching_disabled01.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.galactus_orp_all_viewer_except_host01.id
  }

  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.taaops_cf_waf01.arn : null

  aliases = [
    var.domain_name,
    "${var.app_subdomain}.${var.domain_name}"
  ]

  viewer_certificate {
    acm_certificate_arn      = local.cloudfront_acm_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_acm_certificate" "cloudfront" {
  provider                  = aws.us-east-1
  count                     = var.cloudfront_acm_cert_arn == "" ? 1 : 0
  domain_name               = var.domain_name
  subject_alternative_names = ["${var.app_subdomain}.${var.domain_name}"]
  validation_method         = var.certificate_validation_method
}

resource "aws_route53_record" "cloudfront_cert_validation" {
  for_each = var.cloudfront_acm_cert_arn == "" ? {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options :
    dvo.domain_name => dvo
  } : {}

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider                = aws.us-east-1
  count                   = var.cloudfront_acm_cert_arn == "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cloudfront_cert_validation : r.fqdn]
}

# Managed cache policies

data "aws_cloudfront_cache_policy" "galactus_use_origin_cache_headers01" {
  name = "UseOriginCacheControlHeaders"
}

data "aws_cloudfront_cache_policy" "galactus_use_origin_cache_headers_qs01" {
  name = "UseOriginCacheControlHeaders-QueryStrings"
}

data "aws_cloudfront_cache_policy" "galactus_caching_disabled01" {
  name = "Managed-CachingDisabled"
}

# Managed origin request policies

data "aws_cloudfront_origin_request_policy" "galactus_orp_all_viewer01" {
  name = "Managed-AllViewer"
}

data "aws_cloudfront_origin_request_policy" "galactus_orp_all_viewer_except_host01" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_cache_policy" "galactus_cache_static01" {
  name = "${var.project_name}-cache-static01"
}

data "aws_cloudfront_origin_request_policy" "galactus_orp_static01" {
  name = "${var.project_name}-orp-static01"
}

data "aws_cloudfront_response_headers_policy" "galactus_rsp_static01" {
  name = "${var.project_name}-rsp-static01"
}
