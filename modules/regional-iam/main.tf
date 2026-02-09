# Regional IAM Module
# Creates region-specific IAM roles and policies for EC2, monitoring, and regional services

# Variables
variable "region_name" {
  description = "Region name for IAM role naming (e.g., tokyo, saopaulo)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "taaops"
}

variable "enable_database_access" {
  description = "Whether this region needs database access (false for saopaulo)"
  type        = bool
  default     = false
}

variable "database_secret_arn" {
  description = "Database secret ARN for cross-region access (when enable_database_access is true)"
  type        = string
  default     = ""
}

# Locals
locals {
  role_prefix = "${var.project_name}-${var.region_name}"
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# EC2 INSTANCE ROLE (Regional)
################################################################################

# EC2 assume role policy
data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Regional EC2 Role
resource "aws_iam_role" "regional_ec2_role" {
  name               = "${local.role_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json

  tags = {
    Name   = "${local.role_prefix}-ec2-role"
    Region = var.region_name
  }
}

# Basic EC2 policies
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance_core" {
  role       = aws_iam_role.regional_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent" {
  role       = aws_iam_role.regional_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile
resource "aws_iam_instance_profile" "regional_ec2_instance_profile" {
  name = "${local.role_prefix}-ec2-instance-profile"
  role = aws_iam_role.regional_ec2_role.name
}

################################################################################
# DATABASE ACCESS POLICY (Conditional)
################################################################################

# Database access policy (only if enabled)
data "aws_iam_policy_document" "database_access" {
  count = var.enable_database_access ? 1 : 0

  statement {
    sid    = "ReadDatabaseSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [var.database_secret_arn]
  }

  statement {
    sid    = "ReadDatabaseParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/taaops/database/*"
    ]
  }
}

resource "aws_iam_policy" "database_access" {
  count = var.enable_database_access ? 1 : 0

  name        = "${local.role_prefix}-database-access"
  description = "Database access policy for ${var.region_name}"
  policy      = data.aws_iam_policy_document.database_access[0].json
}

resource "aws_iam_role_policy_attachment" "ec2_database_access" {
  count = var.enable_database_access ? 1 : 0

  role       = aws_iam_role.regional_ec2_role.name
  policy_arn = aws_iam_policy.database_access[0].arn
}

################################################################################
# REGIONAL MONITORING POLICIES
################################################################################

# CloudWatch and logging policies
data "aws_iam_policy_document" "regional_monitoring" {
  statement {
    sid    = "CloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }
}

resource "aws_iam_policy" "regional_monitoring" {
  name        = "${local.role_prefix}-monitoring"
  description = "Regional monitoring policy for ${var.region_name}"
  policy      = data.aws_iam_policy_document.regional_monitoring.json
}

resource "aws_iam_role_policy_attachment" "ec2_regional_monitoring" {
  role       = aws_iam_role.regional_ec2_role.name
  policy_arn = aws_iam_policy.regional_monitoring.arn
}

################################################################################
# APPLICATION-SPECIFIC POLICIES
################################################################################

# Regional application policies (S3 access, etc.)
data "aws_iam_policy_document" "regional_application" {
  statement {
    sid    = "RegionalS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.region_name}-*/*"
    ]
  }

  statement {
    sid    = "RegionalS3ListBuckets"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.region_name}-*"
    ]
  }

  statement {
    sid    = "SNSPublish"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.region_name}-*"
    ]
  }
}

resource "aws_iam_policy" "regional_application" {
  name        = "${local.role_prefix}-application"
  description = "Regional application policy for ${var.region_name}"
  policy      = data.aws_iam_policy_document.regional_application.json
}

resource "aws_iam_role_policy_attachment" "ec2_regional_application" {
  role       = aws_iam_role.regional_ec2_role.name
  policy_arn = aws_iam_policy.regional_application.arn
}