# Regional S3 Logging Module
# Creates S3 buckets for regional log storage (ALB logs, etc.)

# Variables
variable "region_name" {
  description = "Region name for resource naming (e.g., tokyo, saopaulo)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "taaops"
}

variable "enable_alb_logging" {
  description = "Whether to create ALB logging bucket"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Whether to enable S3 access logging on the buckets"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Number of days to retain logs before deletion"
  type        = number
  default     = 90
}

variable "kms_key_id" {
  description = "KMS key ID for S3 encryption (optional, will use AES256 if not provided)"
  type        = string
  default     = null
}

# Locals
locals {
  bucket_prefix = "${var.project_name}-${var.region_name}"
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ELB service account for ALB logs (region-specific)
data "aws_elb_service_account" "main" {}

################################################################################
# ALB LOGS BUCKET
################################################################################

# ALB Logs S3 Bucket
resource "aws_s3_bucket" "alb_logs" {
  count = var.enable_alb_logging ? 1 : 0
  
  bucket        = "${local.bucket_prefix}-alb-logs"
  force_destroy = true

  tags = {
    Name        = "${local.bucket_prefix}-alb-logs"
    Purpose     = "ALBLogs"
    Region      = var.region_name
    Environment = "production"
  }
}

# ALB Logs Bucket Versioning
resource "aws_s3_bucket_versioning" "alb_logs" {
  count = var.enable_alb_logging ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# ALB Logs Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count = var.enable_alb_logging ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

# ALB Logs Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.enable_alb_logging ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

# ALB Logs Bucket Ownership Controls (required for log delivery ACLs)
resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  count  = var.enable_alb_logging ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "alb_logs" {
  count  = var.enable_alb_logging ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.alb_logs]
}

# ALB Logs Bucket Lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count = var.enable_alb_logging ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "delete_old_logs"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ALB Logs Bucket Policy
data "aws_iam_policy_document" "alb_logs_bucket_policy" {
  count = var.enable_alb_logging ? 1 : 0

  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]

    resources = [
      "${aws_s3_bucket.alb_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      "${aws_s3_bucket.alb_logs[0].arn}/*/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/*"]
    }
  }

  statement {
    sid    = "AWSLogDeliveryWriteService"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]

    resources = [
      "${aws_s3_bucket.alb_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      "${aws_s3_bucket.alb_logs[0].arn}/*/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/*"]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.alb_logs[0].arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/*"]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheckService"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.alb_logs[0].arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/*"]
    }
  }

  # Allow CloudTrail to verify bucket policy
  statement {
    sid    = "AllowCloudTrailAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = [
      "s3:GetBucketAcl",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.alb_logs[0].arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count = var.enable_alb_logging ? 1 : 0
  
  bucket = aws_s3_bucket.alb_logs[0].id
  policy = data.aws_iam_policy_document.alb_logs_bucket_policy[0].json
}

################################################################################
# APPLICATION LOGS BUCKET (Optional)
################################################################################

# Application Logs S3 Bucket (for application-specific logs)
resource "aws_s3_bucket" "application_logs" {
  bucket        = "${local.bucket_prefix}-app-logs"
  force_destroy = true

  tags = {
    Name        = "${local.bucket_prefix}-app-logs"
    Purpose     = "ApplicationLogs"
    Region      = var.region_name
    Environment = "production"
  }
}

# Application Logs Bucket Configuration
resource "aws_s3_bucket_versioning" "application_logs" {
  bucket = aws_s3_bucket.application_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "application_logs" {
  bucket = aws_s3_bucket.application_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : false
  }
}

resource "aws_s3_bucket_public_access_block" "application_logs" {
  bucket = aws_s3_bucket.application_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Application Logs Bucket Ownership Controls (required for CloudFront log delivery ACLs)
resource "aws_s3_bucket_ownership_controls" "application_logs" {
  bucket = aws_s3_bucket.application_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "application_logs" {
  bucket = aws_s3_bucket.application_logs.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.application_logs]
}

resource "aws_s3_bucket_lifecycle_configuration" "application_logs" {
  bucket = aws_s3_bucket.application_logs.id

  rule {
    id     = "delete_old_app_logs"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}