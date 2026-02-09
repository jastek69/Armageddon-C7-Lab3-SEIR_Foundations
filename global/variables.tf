variable "project_name" {
  description = "Project name prefix for resources."
  type        = string
  default     = "taaops"
}

variable "domain_name" {
  description = "Apex domain name."
  type        = string
  default     = "jastek.click"
}

variable "app_subdomain" {
  description = "App hostname prefix (e.g., app.jastek.click)."
  type        = string
  default     = "app"
}

variable "alb_origin_subdomain" {
  description = "Dedicated ALB origin hostname prefix for CloudFront (e.g., origin.jastek.click)."
  type        = string
  default     = "origin"
}

variable "aws_region" {
  description = "Primary region for global resources (CloudFront/WAF/Route53)."
  type        = string
  default     = "us-east-1"
}

variable "tokyo_region" {
  description = "Tokyo region for origin resources."
  type        = string
  default     = "ap-northeast-1"
}

variable "tokyo_state_bucket" {
  description = "S3 bucket for Tokyo remote state."
  type        = string
  default     = "taaops-terraform-state-tokyo"
}

variable "tokyo_state_key" {
  description = "S3 key for Tokyo remote state."
  type        = string
  default     = "tokyo/terraform.tfstate"
}

variable "tokyo_state_region" {
  description = "Region of the Tokyo remote state bucket."
  type        = string
  default     = "ap-northeast-1"
}

variable "cloudfront_acm_cert_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront (optional override)."
  type        = string
  default     = ""
}

variable "certificate_validation_method" {
  description = "ACM validation method for CloudFront (DNS or EMAIL)."
  type        = string
  default     = "DNS"
}

variable "enable_waf" {
  description = "Toggle CloudFront WAF creation."
  type        = bool
  default     = true
}

variable "waf_log_destination" {
  description = "WAF log destination: cloudwatch or firehose."
  type        = string
  default     = "cloudwatch"
  validation {
    condition     = contains(["cloudwatch", "firehose"], var.waf_log_destination)
    error_message = "waf_log_destination must be cloudwatch or firehose."
  }
}

variable "waf_log_retention_days" {
  description = "CloudWatch Logs retention days for WAF logging."
  type        = number
  default     = 30
}
