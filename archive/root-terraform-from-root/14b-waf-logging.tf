############################################
# Bonus B - WAF Logging (CloudWatch Logs OR Firehose)
# One destination per Web ACL, choose via var.waf_log_destination.
############################################

############################################
# Option 1: CloudWatch Logs destination
############################################

# Explanation: WAF logs in CloudWatch are your “blaster-cam footage”—fast search, fast triage, fast truth.
resource "aws_cloudwatch_log_group" "taaops_waf_log_group01" {
  count = var.waf_log_destination == "cloudwatch" ? 1 : 0

  # NOTE: AWS requires WAF log destination names start with aws-waf-logs- (students must not rename this).
  name              = "aws-waf-logs-${var.project_name}-webacl01"
  retention_in_days = var.waf_log_retention_days

  tags = {
    Name = "${var.project_name}-waf-log-group01"
  }
}

# Explanation: This wire connects the shield generator to the black box—WAF -> CloudWatch Logs.
resource "aws_wafv2_web_acl_logging_configuration" "taaops_waf_logging01" {
  count = var.enable_waf && var.waf_log_destination == "cloudwatch" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.taaops_waf_acl.arn
  log_destination_configs = [
    aws_cloudwatch_log_group.taaops_waf_log_group01[0].arn
  ]

  # TODO: Add redacted_fields (authorization headers, cookies, etc.) as a stretch goal.
  # redacted_fields { ... }

  depends_on = [aws_wafv2_web_acl.taaops_waf_acl]
}

############################################
# Option 2: Firehose -> S3 destination (recommended for S3 storage)
############################################

# Explanation: S3 WAF logs are the long-term archive—Galactus wants receipts that survive dashboards.
# NOTE: WAF does not support direct S3 logging; Firehose is required for S3 delivery.
resource "aws_s3_bucket" "taaops_waf_logs_bucket01" {
  count = var.waf_log_destination == "firehose" ? 1 : 0

  bucket = "aws-waf-logs-${var.project_name}-${data.aws_caller_identity.taaops_self01.account_id}"

  tags = {
    Name = "${var.project_name}-waf-logs-bucket01"
  }
}

# Explanation: Public access blocked - Taa has deployed shields
resource "aws_s3_bucket_public_access_block" "taaops_waf_logs_pab01" {
  count = var.waf_log_destination == "firehose" ? 1 : 0

  bucket                  = aws_s3_bucket.taaops_waf_logs_bucket01[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# NOTE: Direct WAF -> S3 logging is not supported. The logging configuration
# is wired to Firehose below, which delivers to this bucket.

# Explanation: Firehose is the conveyor belt—WAF logs ride it to storage (and can fork to SIEM later).
resource "aws_s3_bucket" "taaops_firehose_waf_dest_bucket01" {
  count = var.waf_log_destination == "firehose" ? 1 : 0

  bucket = "${var.project_name}-waf-firehose-dest-${data.aws_caller_identity.taaops_self01.account_id}"

  tags = {
    Name = "${var.project_name}-waf-firehose-dest-bucket01"
  }
}

# Explanation: Firehose needs a role—taaops doesn’t let random droids write into storage.
resource "aws_iam_role" "taaops_firehose_role01" {
  count = var.waf_log_destination == "firehose" ? 1 : 0
  name  = "${var.project_name}-firehose-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Explanation: Minimal permissions—allow Firehose to put objects into the destination bucket.
resource "aws_iam_role_policy" "taaops_firehose_policy01" {
  count = var.waf_log_destination == "firehose" ? 1 : 0
  name  = "${var.project_name}-firehose-policy01"
  role  = aws_iam_role.taaops_firehose_role01[0].id

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
          aws_s3_bucket.taaops_firehose_waf_dest_bucket01[0].arn,
          "${aws_s3_bucket.taaops_firehose_waf_dest_bucket01[0].arn}/*"
        ]
      }
    ]
  })
}

# Explanation: The delivery stream is the belt itself—logs move from WAF -> Firehose -> S3.
# NOTE: Firehose buffering and compression can be configured here as a stretch goal.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream

resource "aws_kinesis_firehose_delivery_stream" "taaops_waf_firehose01" {
  count       = var.waf_log_destination == "firehose" ? 1 : 0
  name        = "aws-waf-logs-${var.project_name}-firehose01"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.taaops_firehose_role01[0].arn
    bucket_arn = aws_s3_bucket.taaops_firehose_waf_dest_bucket01[0].arn
    prefix     = "waf-logs/"
  }
}


# Explanation: Connect shield generator to conveyor belt—WAF -> Firehose stream.
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration

resource "aws_wafv2_web_acl_logging_configuration" "taaops_waf_logging_firehose01" {
  count = var.enable_waf && var.waf_log_destination == "firehose" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.taaops_waf_acl.arn
  log_destination_configs = [
    aws_kinesis_firehose_delivery_stream.taaops_waf_firehose01[0].arn
  ]

  depends_on = [aws_wafv2_web_acl.taaops_waf_acl]
}
