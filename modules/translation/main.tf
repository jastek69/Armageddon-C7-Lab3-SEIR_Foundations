# Translation Module - Amazon Translate with S3 Integration
# Handles automated English ↔ Japanese translation for incident reports

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

# Local values
locals {
  name_prefix = "taaops-translate-${var.region}"
}

################################################################################
# S3 BUCKETS FOR TRANSLATION WORKFLOW
################################################################################

# Input bucket - where original incident reports are uploaded
resource "aws_s3_bucket" "input_bucket" {
  bucket = var.input_bucket_name != "" ? var.input_bucket_name : "${local.name_prefix}-input"
  force_destroy = true

  tags = merge(var.common_tags, {
    Name        = "${local.name_prefix}-input"
    Purpose     = "TranslationInput"
    ContentType = "IncidentReports"
  })
}

# Output bucket - where translated reports are stored temporarily  
resource "aws_s3_bucket" "output_bucket" {
  bucket = var.output_bucket_name != "" ? var.output_bucket_name : "${local.name_prefix}-output"
  force_destroy = true

  tags = merge(var.common_tags, {
    Name        = "${local.name_prefix}-output"
    Purpose     = "TranslationOutput"
    ContentType = "TranslatedReports"
  })
}

# Versioning for both buckets
resource "aws_s3_bucket_versioning" "input_versioning" {
  bucket = aws_s3_bucket.input_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "output_versioning" {
  bucket = aws_s3_bucket.output_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "input_encryption" {
  bucket = aws_s3_bucket.input_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output_encryption" {
  bucket = aws_s3_bucket.output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "input_pab" {
  bucket = aws_s3_bucket.input_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "output_pab" {
  bucket = aws_s3_bucket.output_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# IAM ROLES AND POLICIES FOR LAMBDA
################################################################################

# Lambda execution role
resource "aws_iam_role" "translation_lambda_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-lambda-role"
    Purpose = "TranslationLambdaExecution"
  })
}

# Policy for Lambda function
resource "aws_iam_policy" "translation_lambda_policy" {
  name        = "${local.name_prefix}-lambda-policy"
  description = "Policy for translation Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" = "Allow"
        "Action" = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        "Resource" = "arn:aws:logs:${var.region}:*:*"
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        "Resource" = [
          "${aws_s3_bucket.input_bucket.arn}/*",
          "${aws_s3_bucket.output_bucket.arn}/*",
          "${var.reports_bucket_arn}/*"
        ]
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "s3:ListBucket"
        ]
        "Resource" = [
          aws_s3_bucket.input_bucket.arn,
          aws_s3_bucket.output_bucket.arn,
          var.reports_bucket_arn
        ]
      },
      {
        "Effect" = "Allow"
        "Action" = [
          "translate:TranslateText",
          "translate:TranslateDocument"
        ]
        "Resource" = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-lambda-policy"
    Purpose = "TranslationLambdaPermissions"
  })
}


# Translation Lambda function needs permissions to write to S3 and create logs
resource "aws_iam_policy" "translation_lambda_s3_logs_policy" {
  name        = "${local.name_prefix}-lambda-s3-logs-policy"
  description = "Policy for translation Lambda function to write to S3 and create logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.input_bucket.arn}/*",
          "${aws_s3_bucket.output_bucket.arn}/*",
          "${var.reports_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "translate:TranslateText",
          "translate:TranslateDocument"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "comprehend:DetectDominantLanguage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:ap-northeast-1:015195098145:key/fd93b975-d339-407e-8745-9149a1b2e973"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-lambda-s3-logs-policy"
    Purpose = "TranslationLambdaS3LogsPermissions"
  })
}



# Attach policy to role
resource "aws_iam_role_policy_attachment" "translation_lambda_policy_attachment" {
  role       = aws_iam_role.translation_lambda_role.name
  policy_arn = aws_iam_policy.translation_lambda_policy.arn
}

################################################################################
# LAMBDA FUNCTION FOR TRANSLATION
################################################################################

# Package Lambda function code
data "archive_file" "translation_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/translation.zip"
}

# Lambda function
resource "aws_lambda_function" "translation_lambda" {
  filename         = data.archive_file.translation_lambda_zip.output_path
  function_name    = "${local.name_prefix}-processor"
  role             = aws_iam_role.translation_lambda_role.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.translation_lambda_zip.output_base64sha256
  runtime          = "python3.10"
  timeout          = 300 # 5 minutes for document processing

  environment {
    variables = {
      INPUT_BUCKET   = aws_s3_bucket.input_bucket.id
      OUTPUT_BUCKET  = aws_s3_bucket.output_bucket.id
      REPORTS_BUCKET = var.reports_bucket_name
    }
  }

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-processor"
    Purpose = "IncidentReportTranslation"
  })
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "translation_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.translation_lambda.function_name}"
  retention_in_days = 14

  tags = merge(var.common_tags, {
    Name    = "${local.name_prefix}-lambda-logs"
    Purpose = "TranslationLogging"
  })
}

################################################################################
# S3 TRIGGER CONFIGURATION
################################################################################

# Lambda permission for S3 to invoke the function
resource "aws_lambda_permission" "s3_invoke_translation_lambda" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translation_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input_bucket.arn
}

# S3 bucket notification to trigger Lambda
resource "aws_s3_bucket_notification" "translation_trigger" {
  bucket      = aws_s3_bucket.input_bucket.id
  eventbridge = false

  lambda_function {
    lambda_function_arn = aws_lambda_function.translation_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "" # Process all files
    filter_suffix       = "" # All file types
  }

  depends_on = [aws_lambda_permission.s3_invoke_translation_lambda]
}
