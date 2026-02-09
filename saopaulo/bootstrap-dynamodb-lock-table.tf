# DynamoDB lock table for Sao Paulo state
# Run once with local backend before switching to S3+DynamoDB backend.

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
    Purpose     = "State locking for Sao Paulo infrastructure"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
