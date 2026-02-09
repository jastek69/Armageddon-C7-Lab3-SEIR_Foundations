# São Paulo Data Sources - Reads Tokyo remote state for cross-region dependencies

# TOKYO REMOTE STATE
data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = var.tokyo_state_bucket
    key    = var.tokyo_state_key
    region = var.tokyo_state_region
  }
}

# LOCAL AWS DATA SOURCES
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# LOCALS for easy reference to Tokyo outputs
locals {
  # Tokyo TGW information from remote state
  tokyo_tgw_id   = data.terraform_remote_state.tokyo.outputs.tokyo_transit_gateway_id
  tokyo_vpc_cidr = data.terraform_remote_state.tokyo.outputs.tokyo_vpc_cidr
  tokyo_vpc_id   = data.terraform_remote_state.tokyo.outputs.tokyo_vpc_id
  
  # Database information from Tokyo
  rds_endpoint          = data.terraform_remote_state.tokyo.outputs.database_endpoint
  rds_reader_endpoint   = data.terraform_remote_state.tokyo.outputs.database_reader_endpoint
  db_secret_arn         = data.terraform_remote_state.tokyo.outputs.database_secret_arn
  rds_security_group_id = data.terraform_remote_state.tokyo.outputs.database_security_group_id
  
  # Shared services from Tokyo
  kms_key_id             = data.terraform_remote_state.tokyo.outputs.kms_key_id
  cloudwatch_log_group   = data.terraform_remote_state.tokyo.outputs.cloudwatch_log_group_name
  account_id             = data.terraform_remote_state.tokyo.outputs.account_id
  
  # Naming
  name_prefix = var.project_name
  common_tags = {
    ManagedBy   = "Terraform"
    Region      = "SaoPaulo"
    Purpose     = "ComputeSpoke"
    Environment = "production"
    Project     = var.project_name
  }
}