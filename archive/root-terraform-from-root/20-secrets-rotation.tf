# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
############################################  
# 20-secrets-rotation.tf
############################################
# IAM Role for Lambda to rotate Secrets Manager secrets
resource "aws_lambda_function" "secrets_rotation" {
  filename         = "lambda/SecretsManagertaaops-lab1-asm-rotation.zip"
  function_name    = "SecretsManagertaaops-lab1-asm-rotation"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda/SecretsManagertaaops-lab1-asm-rotation.zip")
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids = [
      aws_subnet.tokyo_subnet_private_a.id,
      aws_subnet.tokyo_subnet_private_b.id,
      aws_subnet.tokyo_subnet_private_c.id
    ]
    security_group_ids = [aws_security_group.tokyo_lambda_sg.id]
  }
}

# Allow Secrets Manager to invoke the Lambda function
resource "aws_lambda_permission" "allow_secretsmanager_invoke" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secrets_rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.db_secret.arn
}

# Rotate the RDS secret on a variable schedule (1 day for testing; 30+ for production)
resource "aws_secretsmanager_secret_rotation" "db_secret_rotation" {
  secret_id           = aws_secretsmanager_secret.db_secret.id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation.arn
  depends_on          = [aws_secretsmanager_secret_version.db_secret_version]

  rotation_rules {
    automatically_after_days = var.secrets_rotation_days
  }
}
