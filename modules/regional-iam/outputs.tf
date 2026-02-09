# Regional IAM Module Outputs

output "ec2_role_arn" {
  description = "ARN of the regional EC2 role"
  value       = aws_iam_role.regional_ec2_role.arn
}

output "ec2_role_name" {
  description = "Name of the regional EC2 role"
  value       = aws_iam_role.regional_ec2_role.name
}

output "ec2_instance_profile_name" {
  description = "Name of the regional EC2 instance profile"
  value       = aws_iam_instance_profile.regional_ec2_instance_profile.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the regional EC2 instance profile"
  value       = aws_iam_instance_profile.regional_ec2_instance_profile.arn
}

output "monitoring_policy_arn" {
  description = "ARN of the regional monitoring policy"
  value       = aws_iam_policy.regional_monitoring.arn
}

output "application_policy_arn" {
  description = "ARN of the regional application policy"  
  value       = aws_iam_policy.regional_application.arn
}

output "database_access_policy_arn" {
  description = "ARN of the database access policy (if enabled)"
  value       = var.enable_database_access ? aws_iam_policy.database_access[0].arn : null
}