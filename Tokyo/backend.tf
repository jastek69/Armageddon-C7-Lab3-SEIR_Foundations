# Tokyo Backend Configuration
# Configure S3 backend for Tokyo state management with DynamoDB state locking

terraform {
  backend "s3" {
    bucket         = "taaops-terraform-state-tokyo"
    key            = "tokyo/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    use_lockfile   = true
  }
}

# Note: Backend configurations cannot use data sources or interpolations
# The S3 bucket for state storage should be created separately using:
# 
# resource "aws_s3_bucket" "tokyo_backend_logs" {
#   bucket = "taaops-terraform-state-tokyo-${data.aws_caller_identity.taaops_self01.account_id}"
#   # Add versioning, encryption, etc.
# }
#
# Benefits of DynamoDB State Locking:
# 1. Prevents concurrent Terraform runs from corrupting state
# 2. Essential for team environments and CI/CD pipelines
# 3. Provides atomic operations and consistency
# 4. Minimal cost - only charged for actual lock operations