# DynamoDB table for Terraform state locking
# This should be created BEFORE configuring the S3 backend

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "taaops-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock"
    Purpose     = "State locking for Tokyo infrastructure"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Note: This table needs to exist BEFORE using it in the backend configuration
# Run this first with a local state, then configure the S3 backend