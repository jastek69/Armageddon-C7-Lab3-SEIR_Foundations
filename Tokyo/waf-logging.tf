# =============================================================================
# WAF LOGGING CONFIGURATION
# =============================================================================
# Flexible logging configuration for regional WAF ACLs
# Supports CloudWatch Logs and Kinesis Data Firehose destinations

################################################################################
# CLOUDWATCH LOGS DESTINATION
################################################################################

# Regional WAF CloudWatch Log Group
resource "aws_cloudwatch_log_group" "taaops_regional_waf_log_group" {
  count = var.waf_log_destination == "cloudwatch" ? 1 : 0

  # AWS requires WAF log destination names start with aws-waf-logs-
  name              = "aws-waf-logs-${var.project_name}-tokyo-regional-waf"
  retention_in_days = var.waf_log_retention_days

  tags = {
    Name        = "${var.project_name}-regional-waf-logs"
    Region      = "Tokyo"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}


# Regional WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "taaops_regional_waf_logging" {
  count = var.enable_waf && var.waf_log_destination == "cloudwatch" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.taaops_regional_waf_acl.arn
  log_destination_configs = [
    aws_cloudwatch_log_group.taaops_regional_waf_log_group[0].arn
  ]

  # Redact sensitive fields
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  depends_on = [aws_wafv2_web_acl.taaops_regional_waf_acl]
}


################################################################################
# FIREHOSE DESTINATION (Alternative to CloudWatch)
################################################################################

# S3 Bucket for Regional WAF logs via Firehose
resource "aws_s3_bucket" "taaops_regional_waf_firehose_dest" {
  count = var.waf_log_destination == "firehose" ? 1 : 0

  bucket = "${var.project_name}-tokyo-waf-firehose-${data.aws_caller_identity.taaops_self01.account_id}"

  tags = {
    Name        = "${var.project_name}-regional-waf-firehose-dest"
    Region      = "Tokyo"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Block public access to Firehose destination bucket
resource "aws_s3_bucket_public_access_block" "taaops_regional_waf_firehose_pab" {
  count = var.waf_log_destination == "firehose" ? 1 : 0

  bucket                  = aws_s3_bucket.taaops_regional_waf_firehose_dest[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Firehose IAM Role for Regional WAF
resource "aws_iam_role" "taaops_regional_waf_firehose_role" {
  count = var.waf_log_destination == "firehose" ? 1 : 0
  name  = "${var.project_name}-tokyo-waf-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.project_name}-regional-waf-firehose-role"
    Region      = "Tokyo"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Firehose IAM Policy for Regional WAF
resource "aws_iam_role_policy" "taaops_regional_waf_firehose_policy" {
  count = var.waf_log_destination == "firehose" ? 1 : 0
  name  = "${var.project_name}-tokyo-waf-firehose-policy"
  role  = aws_iam_role.taaops_regional_waf_firehose_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.taaops_regional_waf_firehose_dest[0].arn,
          "${aws_s3_bucket.taaops_regional_waf_firehose_dest[0].arn}/*"
        ]
      }
    ]
  })
}

# Firehose Delivery Stream for Regional WAF
resource "aws_kinesis_firehose_delivery_stream" "taaops_regional_waf_firehose" {
  count       = var.waf_log_destination == "firehose" ? 1 : 0
  name        = "aws-waf-logs-${var.project_name}-tokyo-waf-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.taaops_regional_waf_firehose_role[0].arn
    bucket_arn = aws_s3_bucket.taaops_regional_waf_firehose_dest[0].arn
    prefix     = "regional-waf-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"

    # Buffering configuration
    buffering_size     = 5   # 5 MB buffer
    buffering_interval = 300 # 5 minutes

    # Compression
    compression_format = "GZIP"
  }

  tags = {
    Name        = "${var.project_name}-regional-waf-firehose"
    Region      = "Tokyo"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# Regional WAF Firehose Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "taaops_regional_waf_logging_firehose" {
  count = var.enable_waf && var.waf_log_destination == "firehose" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.taaops_regional_waf_acl.arn
  log_destination_configs = [
    aws_kinesis_firehose_delivery_stream.taaops_regional_waf_firehose[0].arn
  ]

  # Redact sensitive fields
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  depends_on = [aws_wafv2_web_acl.taaops_regional_waf_acl]
}