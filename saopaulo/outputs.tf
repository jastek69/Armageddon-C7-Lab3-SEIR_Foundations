# São Paulo Region Outputs

# VPC Outputs
output "vpc_id" {
  description = "ID of the São Paulo VPC"
  value       = aws_vpc.liberdade_vpc01.id
}

output "vpc_cidr" {
  description = "CIDR block of the São Paulo VPC"
  value       = aws_vpc.liberdade_vpc01.cidr_block
}

# Subnet Outputs
output "private_subnet_ids" {
  description = "IDs of the São Paulo private subnets"
  value = [
    aws_subnet.sao_subnet_private_a.id,
    aws_subnet.sao_subnet_private_b.id,
    aws_subnet.sao_subnet_private_c.id
  ]
}

output "public_subnet_ids" {
  description = "IDs of the São Paulo public subnets"
  value = [
    aws_subnet.sao_subnet_public_a.id,
    aws_subnet.sao_subnet_public_b.id,
    aws_subnet.sao_subnet_public_c.id
  ]
}

# Transit Gateway Outputs
output "saopaulo_transit_gateway_id" {
  description = "ID of the São Paulo Transit Gateway"
  value       = aws_ec2_transit_gateway.liberdade_tgw01.id
}

output "transit_gateway_arn" {
  description = "ARN of the São Paulo Transit Gateway"
  value       = aws_ec2_transit_gateway.liberdade_tgw01.arn
}

# Application Load Balancer Outputs
output "alb_dns_name" {
  description = "DNS name of the São Paulo Application Load Balancer"
  value       = aws_lb.sao_app_lb.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer (to be used in a Route 53 Alias record)"
  value       = aws_lb.sao_app_lb.zone_id
}

output "alb_arn" {
  description = "ARN of the São Paulo Application Load Balancer"
  value       = aws_lb.sao_app_lb.arn
}

# Auto Scaling Group Outputs
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.sao_app_asg.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.sao_app_asg.arn
}

# IAM Outputs
output "instance_profile_name" {
  description = "Name of the EC2 instance profile from regional IAM module"
  value       = module.regional_iam.ec2_instance_profile_name
}

output "instance_role_arn" {
  description = "ARN of the EC2 instance role from regional IAM module"
  value       = module.regional_iam.ec2_role_arn
}

# S3 Outputs
output "s3_alb_logs_bucket" {
  description = "S3 bucket for ALB access logs in São Paulo"
  value       = module.s3_logging.alb_logs_bucket_name
}

output "s3_app_logs_bucket" {
  description = "S3 bucket for application logs in São Paulo"
  value       = module.s3_logging.application_logs_bucket_name
}

# Monitoring Outputs
output "cloudwatch_log_group_app" {
  description = "CloudWatch log group for application logs"
  value       = module.monitoring.application_log_group_name
}

output "cloudwatch_log_group_system" {
  description = "CloudWatch log group for system logs"
  value       = module.monitoring.system_log_group_name
}

output "sns_topic_alerts_arn" {
  description = "SNS topic ARN for regional alerts"
  value       = module.monitoring.alerts_topic_arn
}

# Region Information
output "region" {
  description = "AWS region"
  value       = var.aws_region
}