data "archive_file" "alarm_hook_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/alarm_hook.js"
  output_path = "${path.module}/lambda/alarm_hook.zip"
}

resource "aws_iam_role" "alarm_hook_lambda_role" {
  name = "${var.project_name}-alarm-hook-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alarm_hook_basic" {
  role       = aws_iam_role.alarm_hook_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "alarm_hook_inline" {
  name = "${var.project_name}-alarm-hook-inline"
  role = aws_iam_role.alarm_hook_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:StartQuery",
          "logs:GetQueryResults",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:StartAutomationExecution"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:StartInstanceRefresh",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.alarm_reports.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket" "alarm_reports" {
  bucket        = var.alarm_reports_bucket_name
  force_destroy = true # Allow Terraform to delete the bucket even if it contains objects. - Only for DEV/TEST use!
}

resource "aws_s3_bucket_public_access_block" "alarm_reports" {
  bucket                  = aws_s3_bucket.alarm_reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alarm_reports" {
  bucket = aws_s3_bucket.alarm_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "alarm_reports" {
  bucket = aws_s3_bucket.alarm_reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_lambda_function" "alarm_hook" {
  filename         = data.archive_file.alarm_hook_zip.output_path
  function_name    = "${var.project_name}-alarm-hook"
  role             = aws_iam_role.alarm_hook_lambda_role.arn
  handler          = "alarm_hook.handler"
  runtime          = "nodejs18.x"
  source_code_hash = data.archive_file.alarm_hook_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      LOG_GROUP_NAME             = var.alarm_logs_group_name
      LOGS_INSIGHTS_QUERY        = var.alarm_logs_insights_query
      SSM_PARAM_NAME             = var.alarm_ssm_param_name
      SECRET_ID                  = var.alarm_secret_id != "" ? var.alarm_secret_id : aws_secretsmanager_secret.db_secret.arn
      REPORTS_BUCKET             = aws_s3_bucket.alarm_reports.bucket
      BEDROCK_MODEL_ID           = var.bedrock_model_id
      ALARM_ASG_NAME             = var.alarm_asg_name
      AUTOMATION_DOCUMENT_NAME   = var.automation_document_name != "" ? var.automation_document_name : aws_ssm_document.alarm_report_runbook.name
      AUTOMATION_PARAMETERS_JSON = var.automation_parameters_json
    }
  }
}

resource "aws_lambda_permission" "allow_sns_alarm_hook" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alarm_hook.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.cloudwatch_alarms.arn
}

resource "aws_sns_topic_subscription" "cloudwatch_alarms_lambda" {
  topic_arn = aws_sns_topic.cloudwatch_alarms.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alarm_hook.arn
}
