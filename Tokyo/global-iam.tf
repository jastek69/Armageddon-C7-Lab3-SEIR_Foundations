# Tokyo Global IAM Configuration
# Global IAM roles and policies for CloudFront, WAF, cross-region services

################################################################################
# GLOBAL SERVICE IAM ROLES
################################################################################

# CloudFront/WAF Service Role
resource "aws_iam_role" "cloudfront_service_role" {
  name = "cloudfront-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "cloudfront-service-role"
    Service = "CloudFront"
    Scope   = "Global"
  }
}

# Lambda@Edge Execution Role
resource "aws_iam_role" "lambda_edge_role" {
  name = "lambda-edge-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = {
    Name    = "lambda-edge-role"
    Service = "LambdaEdge"
    Scope   = "Global"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic_execution" {
  role       = aws_iam_role.lambda_edge_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

################################################################################
# CROSS-REGION AUTOMATION ROLES
################################################################################

# Cross-Region Automation Role (for secrets replication, etc.)
resource "aws_iam_role" "cross_region_automation" {
  name = "cross-region-automation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "ssm.amazonaws.com"
          ]
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.taaops_self01.account_id}:root"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = ["ap-northeast-1", "sa-east-1"]
          }
        }
      }
    ]
  })

  tags = {
    Name  = "cross-region-automation"
    Scope = "MultiRegion"
  }
}

# Cross-Region Automation Policy
data "aws_iam_policy_document" "cross_region_automation" {
  statement {
    sid    = "SecretsManagerCrossRegion"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:ReplicateSecretToRegions",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:ap-northeast-1:${data.aws_caller_identity.taaops_self01.account_id}:secret:taaops/*",
      "arn:aws:secretsmanager:sa-east-1:${data.aws_caller_identity.taaops_self01.account_id}:secret:taaops/*"
    ]
  }

  statement {
    sid    = "SSMCrossRegion"
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:DeleteParameter"
    ]
    resources = [
      "arn:aws:ssm:ap-northeast-1:${data.aws_caller_identity.taaops_self01.account_id}:parameter/taaops/*",
      "arn:aws:ssm:sa-east-1:${data.aws_caller_identity.taaops_self01.account_id}:parameter/taaops/*"
    ]
  }

  statement {
    sid    = "KMSCrossRegion"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:CreateGrant"
    ]
    resources = [
      aws_kms_key.taaops_kms_key01.arn,
      "arn:aws:kms:sa-east-1:${data.aws_caller_identity.taaops_self01.account_id}:key/*"
    ]
  }

  statement {
    sid    = "CloudWatchLogsCrossRegion"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:ap-northeast-1:${data.aws_caller_identity.taaops_self01.account_id}:*",
      "arn:aws:logs:sa-east-1:${data.aws_caller_identity.taaops_self01.account_id}:*"
    ]
  }
}

resource "aws_iam_policy" "cross_region_automation" {
  name        = "cross-region-automation-policy"
  description = "Cross-region automation capabilities"
  policy      = data.aws_iam_policy_document.cross_region_automation.json
}

resource "aws_iam_role_policy_attachment" "cross_region_automation" {
  role       = aws_iam_role.cross_region_automation.name
  policy_arn = aws_iam_policy.cross_region_automation.arn
}

################################################################################
# BEDROCK / AI SERVICE ROLES
################################################################################

# Bedrock Service Role
resource "aws_iam_role" "bedrock_service_role" {
  name = "bedrock-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "bedrock-service-role"
    Service = "Bedrock"
    Scope   = "Global"
  }
}

# Bedrock Application Access Policy
data "aws_iam_policy_document" "bedrock_application_access" {
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = [
      "arn:aws:bedrock:ap-northeast-1::foundation-model/*",
      "arn:aws:bedrock:sa-east-1::foundation-model/*"
    ]
  }

  statement {
    sid    = "BedrockKnowledgeBase"
    effect = "Allow"
    actions = [
      "bedrock:Retrieve",
      "bedrock:RetrieveAndGenerate"
    ]
    resources = [
      "arn:aws:bedrock:ap-northeast-1:${data.aws_caller_identity.taaops_self01.account_id}:knowledge-base/*"
    ]
  }
}

resource "aws_iam_policy" "bedrock_application_access" {
  name        = "bedrock-application-access"
  description = "Application access to Bedrock services"
  policy      = data.aws_iam_policy_document.bedrock_application_access.json
}

################################################################################
# ROUTE53 / DNS MANAGEMENT ROLES
################################################################################

# Route53 Health Check Role
resource "aws_iam_role" "route53_health_check_role" {
  name = "route53-health-check-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "route53.amazonaws.com"
        }
      }
    ]
  })
}

# Route53 CloudWatch Integration Policy
data "aws_iam_policy_document" "route53_cloudwatch" {
  statement {
    sid    = "Route53CloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["AWS/Route53"]
    }
  }
}

resource "aws_iam_policy" "route53_cloudwatch" {
  name        = "route53-cloudwatch-policy"
  description = "Route53 CloudWatch integration"
  policy      = data.aws_iam_policy_document.route53_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "route53_cloudwatch" {
  role       = aws_iam_role.route53_health_check_role.name
  policy_arn = aws_iam_policy.route53_cloudwatch.arn
}

################################################################################
# ASSUMABLE ROLES FOR REGIONAL SERVICES
################################################################################

# São Paulo Assumable Role (allows São Paulo services to assume Tokyo roles)
resource "aws_iam_role" "saopaulo_assumable_role" {
  name = "saopaulo-assumable-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.taaops_self01.account_id}:root"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "sa-east-1"
          }
          StringLike = {
            "aws:userid" = "*:taaops-*"
          }
        }
      }
    ]
  })

  tags = {
    Name   = "saopaulo-assumable-role"
    Region = "SaoPaulo"
    Type   = "CrossRegionAccess"
  }
}

# Attach database access policy to São Paulo assumable role
resource "aws_iam_role_policy_attachment" "saopaulo_database_access" {
  role       = aws_iam_role.saopaulo_assumable_role.name
  policy_arn = aws_iam_policy.global_database_access.arn
}

# Attach Bedrock access to São Paulo assumable role
resource "aws_iam_role_policy_attachment" "saopaulo_bedrock_access" {
  role       = aws_iam_role.saopaulo_assumable_role.name
  policy_arn = aws_iam_policy.bedrock_application_access.arn
}