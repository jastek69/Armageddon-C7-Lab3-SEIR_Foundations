output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_secret.arn
}

output "db_endpoint" {
  value = aws_rds_cluster.taaops_rds_cluster.endpoint
}

output "db_cluster_id" {
  value = aws_rds_cluster_instance.taaops_rds_cluster_instances.*.id
}

output "ec2_instance_profile_name" {
  value = aws_iam_instance_profile.taaops_ec2_instance_profile.name
}

output "ec2_instance_profile_arn" {
  value = aws_iam_instance_profile.taaops_ec2_instance_profile.arn
}

output "ec2_role_name" {
  value = aws_iam_role.taaops_ec2_role.name
}

output "ec2_role_arn" {
  value = aws_iam_role.taaops_ec2_role.arn
}

output "secrets_manager_db_secret_name" {
  value = aws_secretsmanager_secret.db_secret.name
}

output "secrets_manager_db_secret_arn" {
  value = aws_secretsmanager_secret.db_secret.arn
}

output "secrets_manager_db_secret_version_id" {
  value = aws_secretsmanager_secret_version.db_secret_version.version_id
}

output "alb_target_group_arn" {
  value       = aws_lb_target_group.taaops_lb_tg80.arn
  description = "ALB target group ARN."
}

output "cloudwatch_alarms_topic_arn" {
  value       = aws_sns_topic.cloudwatch_alarms.arn
  description = "SNS topic ARN for CloudWatch alarms."
}

output "vpc_id" {
  value       = aws_vpc.shinjuku_vpc01.id
  description = "VPC ID."
}

output "rds_security_group_name" {
  value       = aws_security_group.taaops_rds_sg.name
  description = "RDS security group name."
}

output "rds_db_instance_id" {
  value       = try(aws_rds_cluster_instance.taaops_rds_cluster_instances[0].id, null)
  description = "First RDS cluster instance ID."
}


output "app_subdomain" {
  value       = var.app_subdomain
  description = "App hostname prefix."
}

output "app_domain" {
  value       = "${var.app_subdomain}.${var.domain_name}"
  description = "App fully qualified domain name."
}

output "origin_region" {
  value       = data.aws_region.current.name
  description = "Origin region (used for gates)."
}

output "domain_name" {
  value       = var.domain_name
  description = "Apex domain name."
}


output "log_bucket" {
  value       = aws_s3_bucket.alb_logs.bucket
  description = "ALB logs bucket (used for gates)."
}


output "origin_sg_id" {
  value       = aws_security_group.tokyo_alb_sg.id
  description = "Origin/ALB security group ID."
}

########################## TRANSIT GATEWAY OUTPUTS ##########################

output "tokyo_transit_gateway_id" {
  value       = aws_ec2_transit_gateway.shinjuku_tgw01.id
  description = "Tokyo Transit Gateway ID (Data Authority Hub)."
}

output "tokyo_transit_gateway_arn" {
  value       = aws_ec2_transit_gateway.shinjuku_tgw01.arn
  description = "Tokyo Transit Gateway ARN."
}

output "sao_transit_gateway_id" {
  value       = aws_ec2_transit_gateway.liberdade_tgw01.id
  description = "São Paulo Transit Gateway ID (Compute Spoke)."
}

output "sao_transit_gateway_arn" {
  value       = aws_ec2_transit_gateway.liberdade_tgw01.arn
  description = "São Paulo Transit Gateway ARN."
}

output "tokyo_vpc_attachment_id" {
  value       = aws_ec2_transit_gateway_vpc_attachment.tokyo_vpc_attachment.id
  description = "Tokyo VPC attachment to Transit Gateway."
}

output "sao_vpc_attachment_id" {
  value       = aws_ec2_transit_gateway_vpc_attachment.sao_vpc_attachment.id
  description = "São Paulo VPC attachment to Transit Gateway."
}

output "inter_region_peering_attachment_id" {
  value       = aws_ec2_transit_gateway_peering_attachment.tokyo_to_sao_peering.id
  description = "Inter-region peering attachment ID between Tokyo and São Paulo."
}

output "tokyo_vpc_id" {
  value       = aws_vpc.shinjuku_vpc01.id
  description = "Tokyo VPC ID."
}

output "sao_vpc_id" {
  value       = aws_vpc.liberdade_vpc01.id
  description = "São Paulo VPC ID."
}

output "tokyo_vpc_cidr" {
  value       = aws_vpc.shinjuku_vpc01.cidr_block
  description = "Tokyo VPC CIDR block."
}

output "sao_vpc_cidr" {
  value       = aws_vpc.liberdade_vpc01.cidr_block
  description = "São Paulo VPC CIDR block."
}
