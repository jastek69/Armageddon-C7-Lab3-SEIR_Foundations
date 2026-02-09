# Translation Module Outputs

output "input_bucket_name" {
  description = "Name of the input S3 bucket for translation"
  value       = aws_s3_bucket.input_bucket.id
}

output "input_bucket_arn" {
  description = "ARN of the input S3 bucket for translation"
  value       = aws_s3_bucket.input_bucket.arn
}

output "output_bucket_name" {
  description = "Name of the output S3 bucket for translation"
  value       = aws_s3_bucket.output_bucket.id
}

output "output_bucket_arn" {
  description = "ARN of the output S3 bucket for translation"
  value       = aws_s3_bucket.output_bucket.arn
}

output "lambda_function_name" {
  description = "Name of the translation Lambda function"
  value       = aws_lambda_function.translation_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the translation Lambda function"
  value       = aws_lambda_function.translation_lambda.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.translation_lambda_role.arn
}

output "lambda_log_group_name" {
  description = "Name of the CloudWatch log group for the Lambda function"
  value       = aws_cloudwatch_log_group.translation_lambda_logs.name
}