#!/usr/bin/env bash
set -euo pipefail

# Bootstrap DynamoDB lock table using local backend, then switch to S3+DynamoDB.

terraform init -backend=false
terraform apply -target=aws_dynamodb_table.terraform_lock
terraform init -reconfigure
terraform plan
