# São Paulo Backend Configuration  
# Configure S3 backend for São Paulo state management with DynamoDB state locking

terraform {
  backend "s3" {
    bucket       = "taaops-terraform-state-saopaulo"
    key          = "saopaulo/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Note: Backend configurations cannot use data sources or interpolations  
# The S3 bucket for state storage should be created separately using:
# 
# resource "aws_s3_bucket" "taaops_terraform_state" {
#   bucket = "taaops-terraform-state-saopaulo-${data.aws_caller_identity.current.account_id}"
#   # Add versioning, encryption, etc.
# }
#
# Note: DynamoDB table must be created in the same region as the S3 bucket
# Use setup-dynamodb-locking.tf to create the required tables
# São Paulo reads Tokyo remote state for TGW peering and database access

