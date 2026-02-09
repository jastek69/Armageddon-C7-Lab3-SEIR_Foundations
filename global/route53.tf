resource "aws_route53_record" "taaops_apex_to_cf01" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.galactus_cf01.domain_name
    zone_id                = aws_cloudfront_distribution.galactus_cf01.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "taaops_apex_to_cf01_aaaa" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.galactus_cf01.domain_name
    zone_id                = aws_cloudfront_distribution.galactus_cf01.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "taaops_app_to_cf01" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.galactus_cf01.domain_name
    zone_id                = aws_cloudfront_distribution.galactus_cf01.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "taaops_app_to_cf01_aaaa" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.galactus_cf01.domain_name
    zone_id                = aws_cloudfront_distribution.galactus_cf01.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "taaops_origin_to_alb01" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.alb_origin_fqdn
  type    = "A"

  alias {
    name                   = data.terraform_remote_state.tokyo.outputs.tokyo_alb_dns_name
    zone_id                = data.terraform_remote_state.tokyo.outputs.tokyo_alb_zone_id
    evaluate_target_health = false
  }
}
