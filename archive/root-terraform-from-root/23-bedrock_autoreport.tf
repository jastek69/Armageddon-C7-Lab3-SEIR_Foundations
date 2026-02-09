############################################
# Bonus G - Bedrock Auto Incident Report Pipeline (SNS -> Lambda -> S3)
############################################

# Package local Lambda source (no console zip needed)
data "archive_file" "galactus_ir_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ir_reporter/handler.py"
  output_path = "${path.module}/lambda/ir_reporter.zip"
}

# Explanation: The incident reports archive—Galactus's digital filing cabinet for postmortem artifacts.
resource "aws_s3_bucket" "galactus_ir_reports_bucket01" {
  bucket = "${var.project_name}-incident-reports-${data.aws_caller_identity.galactus_self01.account_id}"

  tags = {
    Name        = "${var.project_name}-incident-reports"
    Purpose     = "Incident report storage"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

# S3 bucket versioning for report history
resource "aws_s3_bucket_versioning" "galactus_ir_reports_versioning" {
  bucket = aws_s3_bucket.galactus_ir_reports_bucket01.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "galactus_ir_reports_encryption" {
  bucket = aws_s3_bucket.galactus_ir_reports_bucket01.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block (security)
resource "aws_s3_bucket_public_access_block" "galactus_ir_reports_public_block" {
  bucket = aws_s3_bucket.galactus_ir_reports_bucket01.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 lifecycle rule for report retention
resource "aws_s3_bucket_lifecycle_configuration" "galactus_ir_reports_lifecycle" {
  bucket = aws_s3_bucket.galactus_ir_reports_bucket01.id

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
resource "aws_sns_topic" "galactus_ir_reports_topic" {
  name = "${var.project_name}-ir-reports-topic"
}

# Dedicated SNS topic to trigger the reporter Lambda (prevents recursion)
resource "aws_sns_topic" "galactus_ir_trigger_topic" {
  name = "${var.project_name}-ir-trigger-topic"
}

# Explanation: This role is the droid brain—Lambda assumes it to collect evidence and call Bedrock.
resource "aws_iam_role" "galactus_ir_reports_bucket01_ir_lambda_role01" {
  name = "${var.project_name}-ir-lambda-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Explanation: Galactus grants the minimum needed—logs, S3, SSM, Secrets, CloudWatch, and Bedrock invoke.
resource "aws_iam_policy" "galactus_ir_lambda_policy01" {
  name = "${var.project_name}-ir-lambda-policy01"

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
        Resource = "arn:aws:ssm:*:${data.aws_caller_identity.galactus_self01.account_id}:parameter/lab/db/*"
      },
      # Secrets Manager
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.galactus_self01.account_id}:secret:${var.project_name}/rds/mysql*"
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
          aws_s3_bucket.galactus_ir_reports_bucket01.arn,
          "${aws_s3_bucket.galactus_ir_reports_bucket01.arn}/*"
        ]
      },
      # SNS notify "Report Ready"
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = aws_sns_topic.galactus_ir_reports_topic.arn
      },
      # Bedrock invoke
      {
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel"
        ],
        Resource = "*"
      }
    ]
  })
}

# Explanation: Attach the policy—Galactus equips the Lambda like a proper Wookiee engineer.
resource "aws_iam_role_policy_attachment" "galactus_ir_lambda_attach01" {
  role       = aws_iam_role.galactus_ir_reports_bucket01_ir_lambda_role01.name
  policy_arn = aws_iam_policy.galactus_ir_lambda_policy01.arn
}

# Explanation: Basic Lambda logging—because even droids need diaries.
resource "aws_iam_role_policy_attachment" "galactus_ir_lambda_basiclogs01" {
  role       = aws_iam_role.galactus_ir_reports_bucket01_ir_lambda_role01.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Explanation: The Lambda itself—Galactus’s incident scribe that writes your postmortem while you fight fires.
resource "aws_lambda_function" "galactus_ir_lambda01" {
  function_name = "${var.project_name}-ir-reporter01"
  role          = aws_iam_role.galactus_ir_reports_bucket01_ir_lambda_role01.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60

  filename         = data.archive_file.galactus_ir_lambda_zip.output_path
  source_code_hash = data.archive_file.galactus_ir_lambda_zip.output_base64sha256

  environment {
    variables = {
      REPORT_BUCKET    = aws_s3_bucket.galactus_ir_reports_bucket01.bucket # S3 for JSON + Markdown reports
      APP_LOG_GROUP    = "/aws/ec2/rdsapp"                                 # App log group (CloudWatch Agent default)
      WAF_LOG_GROUP    = "aws-waf-logs-${var.project_name}-webacl01"       # WAF log group (if enabled)
      SECRET_ID        = "${var.project_name}/rds/mysql"                   # Secrets Manager secret name/ARN
      SSM_PARAM_PATH   = "/lab/db/"                                        # Parameter Store path for DB config
      BEDROCK_MODEL_ID = "mistral.mistral-large-3-675b-instruct"           # Bedrock model ID (optional)
      SNS_TOPIC_ARN    = aws_sns_topic.galactus_ir_reports_topic.arn       # SNS topic for "Report Ready"
    }
  }
}

# Explanation: This subscription wires the trigger topic to the reporter Lambda.
resource "aws_sns_topic_subscription" "galactus_ir_lambda_sub01" {
  topic_arn = aws_sns_topic.galactus_ir_trigger_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.galactus_ir_lambda01.arn
}

# Explanation: Allow SNS to invoke Lambda—Galactus authorizes the distress beacon to wake the droid.
resource "aws_lambda_permission" "galactus_allow_sns_invoke01" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.galactus_ir_lambda01.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.galactus_ir_trigger_topic.arn
}

# Explanation: Output report bucket—Galactus needs the archive coordinates for grading.
output "galactus_ir_reports_bucket" {
  value = aws_s3_bucket.galactus_ir_reports_bucket01.bucket
}
