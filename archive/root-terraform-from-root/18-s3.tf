resource "aws_s3_bucket" "rds_data" {
  bucket = "taaops-oregon-s3-rds"
}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "taaops-oregon-alb-logs"
  force_destroy = true # Allow Terraform to delete the bucket even if it contains objects. - Only for DEV/TEST use!
}


resource "aws_s3_bucket_public_access_block" "rds_data" {
  bucket                  = aws_s3_bucket.rds_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_versioning" "rds_data" {
  bucket = aws_s3_bucket.rds_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "rds_data" {
  bucket = aws_s3_bucket.rds_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.taaops_kms_key_id
    }
  }
}

# Dedicated ALB logs bucket encryption.
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# Allow ALB to deliver access logs into this bucket/prefix.
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryGetBucketAcl"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.taaops_self01.account_id
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb/taaops/AWSLogs/${data.aws_caller_identity.taaops_self01.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = data.aws_caller_identity.taaops_self01.account_id
          }
        }
      }
    ]
  })
}





# AI AWS TRANSLATOR: The following S3 buckets are used for various purposes in the TAAOPS environment. The `rds_data` bucket is intended for storing RDS data exports, while the `alb_logs` bucket is designated for Application Load Balancer access logs. All buckets have versioning enabled and server-side encryption configured to ensure data durability and security. Additionally, public access is blocked on all buckets to prevent unauthorized access, and specific policies are applied to allow necessary services (like ALB) to write logs to the appropriate buckets.
