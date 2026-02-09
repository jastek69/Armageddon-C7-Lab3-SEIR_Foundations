# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
# IAM Role for EC2 Instances


resource "aws_iam_role" "taaops_ec2_role" {
  name               = "taaops_ec2_role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}


# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "taaops_ec2_role_attachment" {
  role       = aws_iam_role.taaops_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "taaops_ec2_cw_agent_attachment" {
  role       = aws_iam_role.taaops_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}




resource "aws_iam_policy" "ec2_read_db_secret" {
  name   = "ec2_read_db_secret_policy"
  policy = data.aws_iam_policy_document.ec2_read_db_secret.json
}


resource "aws_iam_role_policy_attachment" "taaops_ec2_read_db_secret_attachment" {
  role       = aws_iam_role.taaops_ec2_role.name
  policy_arn = aws_iam_policy.ec2_read_db_secret.arn
}

data "aws_iam_policy_document" "ec2_ssm_param_read" {
  statement {
    sid    = "ReadSsmParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParameterHistory"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.taaops_self01.account_id}:parameter/lab/*",
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.taaops_self01.account_id}:parameter/cw/agent/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_ssm_param_read" {
  name   = "ec2_ssm_param_read"
  policy = data.aws_iam_policy_document.ec2_ssm_param_read.json
}

resource "aws_iam_role_policy_attachment" "taaops_ec2_ssm_param_read_attachment" {
  role       = aws_iam_role.taaops_ec2_role.name
  policy_arn = aws_iam_policy.ec2_ssm_param_read.arn
}



# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
resource "aws_iam_instance_profile" "taaops_ec2_instance_profile" {
  name = "taaops_ec2_instance_profile"
  role = aws_iam_role.taaops_ec2_role.name
}



# IAM Role for EC2 to access S3 Bucket
resource "aws_iam_role_policy_attachment" "taaops_ec2_s3_access_attachment" {
  role       = aws_iam_role.taaops_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# IAM Role for EC2 to access KMS
resource "aws_iam_role_policy_attachment" "taaops_ec2_kms_access_attachment" {
  role       = aws_iam_role.taaops_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser"
}



resource "aws_iam_role" "lambda_exec" {
  name = "taaops_lambda_exec_role"

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
}


# Lambda basic logging + VPC access
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Secrets Manager rotation permissions (scoped to the RDS-managed secret)
data "aws_iam_policy_document" "lambda_secrets_rotation" {
  statement {
    sid    = "SecretsManagerRotation"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = [aws_secretsmanager_secret.db_secret.arn]
  }

  statement {
    sid    = "KmsDecryptForSecrets"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lambda_secrets_rotation" {
  name   = "lambda_secrets_rotation_policy"
  policy = data.aws_iam_policy_document.lambda_secrets_rotation.json
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_rotation" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_secrets_rotation.arn
}



# IAM LAMBDA for TRanslator


# Additional IAM Policies can be attached as needed
