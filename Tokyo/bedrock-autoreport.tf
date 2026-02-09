############################################
# Tokyo Bedrock Auto Incident Report Pipeline (SNS -> Lambda -> S3)
############################################

# Data source for current AWS account
data "aws_caller_identity" "tokyo_self01" {}

# Package local Lambda source (no console zip needed)
data "archive_file" "tokyo_ir_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/ir_reporter/handler.py"
  output_path = "${path.module}/lambda/ir_reporter.zip"
}

# Explanation: The incident reports archive—Galactus's digital filing cabinet for postmortem artifacts.
resource "aws_s3_bucket" "tokyo_ir_reports_bucket" {
  bucket = "${var.project_name}-tokyo-incident-reports-${data.aws_caller_identity.tokyo_self01.account_id}"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-tokyo-incident-reports"
    Purpose     = "Incident report storage"
    Environment = "production"
    Region      = "Tokyo"
  })
}

# S3 bucket versioning for report history
resource "aws_s3_bucket_versioning" "tokyo_ir_reports_versioning" {
  bucket = aws_s3_bucket.tokyo_ir_reports_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "tokyo_ir_reports_encryption" {
  bucket = aws_s3_bucket.tokyo_ir_reports_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.taaops_kms_key01.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block (security)
resource "aws_s3_bucket_public_access_block" "tokyo_ir_reports_public_block" {
  bucket = aws_s3_bucket.tokyo_ir_reports_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 lifecycle rule for report retention
resource "aws_s3_bucket_lifecycle_configuration" "tokyo_ir_reports_lifecycle" {
  bucket = aws_s3_bucket.tokyo_ir_reports_bucket.id

  rule {
    id     = "incident_reports_retention"
    status = "Enabled"

    # Move reports to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after 90 days  
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Move to Deep Archive after 365 days
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    # Delete after 7 years (compliance)
    expiration {
      days = 2555
    }
  }
}

# Dedicated SNS topic for report-ready notifications
resource "aws_sns_topic" "tokyo_ir_reports_topic" {
  name = "${var.project_name}-tokyo-ir-reports-topic"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-tokyo-ir-reports"
    Purpose     = "Incident report notifications"
    Environment = "production"
    Region      = "Tokyo"
  })
}

# Dedicated SNS topic to trigger the reporter Lambda (prevents recursion)
resource "aws_sns_topic" "tokyo_ir_trigger_topic" {
  name = "${var.project_name}-tokyo-ir-trigger-topic"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-tokyo-ir-trigger"
    Purpose     = "Lambda trigger for incident reports"
    Environment = "production"
    Region      = "Tokyo"
  })
}

# Explanation: This role is the droid brain—Lambda assumes it to collect evidence and call Bedrock.
resource "aws_iam_role" "tokyo_ir_lambda_role" {
  name = "${var.project_name}-tokyo-ir-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-tokyo-ir-lambda-role"
    Purpose     = "Incident report Lambda execution role"
    Environment = "production"
    Region      = "Tokyo"
  })
}

# Explanation: Galactus grants the minimum needed—logs, S3, SSM, Secrets, CloudWatch, and Bedrock invoke.
resource "aws_iam_policy" "tokyo_ir_lambda_policy" {
  name = "${var.project_name}-tokyo-ir-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # CloudWatch Logs Insights queries
      {
        Effect = "Allow",
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents"
        ],
        Resource = "*"
      },
      # CloudWatch alarm/metrics read
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics"
        ],
        Resource = "*"
      },
      # Parameter Store
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.tokyo_self01.account_id}:parameter/lab/db/*"
      },
      # Secrets Manager
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.tokyo_self01.account_id}:secret:${var.project_name}/rds/mysql*"
      },
      # S3 report write
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.tokyo_ir_reports_bucket.arn,
          "${aws_s3_bucket.tokyo_ir_reports_bucket.arn}/*"
        ]
      },
      # Translation buckets access for integration
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          module.tokyo_translation.input_bucket_arn,
          "${module.tokyo_translation.input_bucket_arn}/*"
        ]
      },
      # SNS notify "Report Ready"
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.tokyo_ir_reports_topic.arn
      },
      # Bedrock invoke
      {
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel"
        ],
        Resource = "*"
      },
      # SSM Automation document execution
      {
        Effect = "Allow",
        Action = [
          "ssm:StartAutomationExecution",
          "ssm:GetAutomationExecution",
          "ssm:DescribeAutomationExecutions",
          "ssm:DescribeAutomationStepExecutions"
        ],
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.tokyo_self01.account_id}:automation-definition/${var.project_name}-tokyo-incident-report:*",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.tokyo_self01.account_id}:automation-execution/*"
        ]
      },
      # KMS access for encrypted resources
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.taaops_kms_key01.arn
      },
      # Auto Scaling Group permissions for SSM automation
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:StartInstanceRefresh"
        ],
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-tokyo-ir-lambda-policy"
    Purpose     = "Incident report Lambda permissions"
    Environment = "production"
    Region      = "Tokyo"
  })
}

# Explanation: Attach the policy—Galactus equips the Lambda like a proper Wookiee engineer.
resource "aws_iam_role_policy_attachment" "tokyo_ir_lambda_attach" {
  role       = aws_iam_role.tokyo_ir_lambda_role.name
  policy_arn = aws_iam_policy.tokyo_ir_lambda_policy.arn
}

# Explanation: Basic Lambda logging—because even droids need diaries.
resource "aws_iam_role_policy_attachment" "tokyo_ir_lambda_basiclogs" {
  role       = aws_iam_role.tokyo_ir_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Explanation: The Lambda itself—Galactus's incident scribe that writes your postmortem while you fight fires.
resource "aws_lambda_function" "tokyo_ir_lambda" {
  function_name = "${var.project_name}-tokyo-ir-reporter"
  role          = aws_iam_role.tokyo_ir_lambda_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60

  filename         = data.archive_file.tokyo_ir_lambda_zip.output_path
  source_code_hash = data.archive_file.tokyo_ir_lambda_zip.output_base64sha256

  environment {
    variables = {
      REPORT_BUCKET       = aws_s3_bucket.tokyo_ir_reports_bucket.bucket          # S3 for JSON + Markdown reports
      TRANSLATION_BUCKET  = module.tokyo_translation.input_bucket_name            # Translation integration
      APP_LOG_GROUP       = "/aws/ec2/rdsapp"                                     # App log group (CloudWatch Agent default)
      WAF_LOG_GROUP       = "aws-waf-logs-${var.project_name}-tokyo-regional-waf" # Regional WAF log group
      SECRET_ID           = "${var.project_name}/rds/mysql"                       # Secrets Manager secret name/ARN
      SSM_PARAM_PATH      = "/lab/db/"                                            # Parameter Store path for DB config
      BEDROCK_MODEL_ID    = "mistral.mistral-large-3-675b-instruct"               # Bedrock model ID (optional)
      SNS_TOPIC_ARN       = aws_sns_topic.tokyo_ir_reports_topic.arn              # SNS topic for "Report Ready"
      AUTOMATION_DOC_NAME = "${var.project_name}-tokyo-incident-report"           # SSM automation document
    }
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-tokyo-ir-reporter"
    Purpose     = "Automated incident report generation"
    Environment = "production"
    Region      = "Tokyo"
  })
}

# Explanation: This subscription wires the trigger topic to the reporter Lambda.
resource "aws_sns_topic_subscription" "tokyo_ir_lambda_sub" {
  topic_arn = aws_sns_topic.tokyo_ir_trigger_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.tokyo_ir_lambda.arn
}

# Explanation: Allow SNS to invoke Lambda—Galactus authorizes the distress beacon to wake the droid.
resource "aws_lambda_permission" "tokyo_allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tokyo_ir_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.tokyo_ir_trigger_topic.arn
}

# Subscribe CloudWatch alarms to trigger incident reports
resource "aws_sns_topic_subscription" "tokyo_ir_alarm_subscription" {
  topic_arn = module.tokyo_monitoring.alerts_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.tokyo_ir_lambda.arn
}

# Allow CloudWatch alarms to invoke the incident report Lambda
resource "aws_lambda_permission" "tokyo_allow_cloudwatch_invoke" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tokyo_ir_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = module.tokyo_monitoring.alerts_topic_arn
}