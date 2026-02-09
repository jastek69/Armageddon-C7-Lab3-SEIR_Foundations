# WAF Implementation for Multi-Region Architecture
# Regional WAF for ALB

################################################################################
# REGIONAL WAF for ALB (Tokyo Region)
################################################################################

# IP Block List for Regional WAF
resource "aws_wafv2_ip_set" "taaops_regional_ip_block_list" {
  name               = "${var.project_name}-tokyo-ip-block-list"
  description        = "Tokyo regional blocked IP addresses"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses = [
    "1.188.0.0/16",
    "1.80.0.0/16",
    "101.144.0.0/16",
    "101.16.0.0/16"
  ]

  tags = {
    Name        = "${var.project_name}-regional-ip-block-list"
    Region      = "Tokyo"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Regional WAF Web ACL for ALB
resource "aws_wafv2_web_acl" "taaops_regional_waf_acl" {
  name        = "${var.project_name}-tokyo-regional-waf"
  description = "Regional Web ACL for Tokyo ALB protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # IP Block Rule
  rule {
    name     = "IPBlockRule"
    priority = 1
    action {
      block {}
    }
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.taaops_regional_ip_block_list.arn
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-regional-ip-block"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules: Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputs"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-regional-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules: Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-regional-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-regional-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project_name}-regional-waf"
    Region      = "Tokyo"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Associate Regional WAF with ALB
resource "aws_wafv2_web_acl_association" "taaops_regional_waf_alb_association" {
  resource_arn = aws_lb.tokyo_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.taaops_regional_waf_acl.arn
}

