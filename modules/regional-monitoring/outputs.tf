# Regional Monitoring Module Outputs

output "application_log_group_name" {
  description = "Name of the application CloudWatch log group"
  value       = aws_cloudwatch_log_group.application.name
}

output "application_log_group_arn" {
  description = "ARN of the application CloudWatch log group"
  value       = aws_cloudwatch_log_group.application.arn
}

output "system_log_group_name" {
  description = "Name of the system CloudWatch log group"
  value       = aws_cloudwatch_log_group.system.name
}

output "alb_log_group_name" {
  description = "Name of the ALB CloudWatch log group"
  value       = aws_cloudwatch_log_group.alb.name
}

output "alerts_topic_arn" {
  description = "ARN of the regional SNS alerts topic"
  value       = aws_sns_topic.regional_alerts.arn
}

output "alerts_topic_name" {
  description = "Name of the regional SNS alerts topic"
  value       = aws_sns_topic.regional_alerts.name
}

/*
Not being used
output "dashboard_url" {
  description = "URL of the regional CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.regional_dashboard.dashboard_name}"
}
*/