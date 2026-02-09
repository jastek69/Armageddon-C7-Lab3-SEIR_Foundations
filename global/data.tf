data "aws_caller_identity" "current" {}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = var.tokyo_state_bucket
    key    = var.tokyo_state_key
    region = var.tokyo_state_region
  }
}
