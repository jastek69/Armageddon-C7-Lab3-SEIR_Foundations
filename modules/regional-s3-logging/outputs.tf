# Regional S3 Logging Module Outputs

output "alb_logs_bucket_name" {
  description = "Name of the ALB logs S3 bucket"
  value       = var.enable_alb_logging ? aws_s3_bucket.alb_logs[0].bucket : null
}

output "alb_logs_bucket_arn" {
  description = "ARN of the ALB logs S3 bucket"
  value       = var.enable_alb_logging ? aws_s3_bucket.alb_logs[0].arn : null
}

output "alb_logs_bucket_domain_name" {
  description = "Domain name of the ALB logs S3 bucket"
  value       = var.enable_alb_logging ? aws_s3_bucket.alb_logs[0].bucket_domain_name : null
}

output "application_logs_bucket_name" {
  description = "Name of the application logs S3 bucket"
  value       = aws_s3_bucket.application_logs.bucket
}

output "application_logs_bucket_arn" {
  description = "ARN of the application logs S3 bucket"
  value       = aws_s3_bucket.application_logs.arn
}

output "application_logs_bucket_domain_name" {
  description = "Domain name of the application logs S3 bucket"
  value       = aws_s3_bucket.application_logs.bucket_domain_name
}