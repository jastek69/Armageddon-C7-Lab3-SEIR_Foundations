# Tokyo Outputs - Exposes resources for São Paulo remote state consumption

# TRANSIT GATEWAY OUTPUTS (Critical for São Paulo)
output "tokyo_transit_gateway_id" {
  value       = aws_ec2_transit_gateway.shinjuku_tgw01.id
  description = "Tokyo Transit Gateway ID - used by São Paulo for peering"
}

output "tokyo_transit_gateway_arn" {
  value       = aws_ec2_transit_gateway.shinjuku_tgw01.arn
  description = "Tokyo Transit Gateway ARN"
}

# VPC INFORMATION
output "tokyo_vpc_id" {
  value       = aws_vpc.shinjuku_vpc01.id
  description = "Tokyo VPC ID"
}

output "tokyo_vpc_cidr" {
  value       = aws_vpc.shinjuku_vpc01.cidr_block
  description = "Tokyo VPC CIDR block - needed for São Paulo routing"
}

# DATABASE OUTPUTS (Critical for cross-region access)
output "database_endpoint" {
  value       = aws_rds_cluster.taaops_rds_cluster.endpoint
  description = "RDS Aurora cluster endpoint - accessible from São Paulo via TGW"
}

output "database_reader_endpoint" {
  value       = aws_rds_cluster.taaops_rds_cluster.reader_endpoint
  description = "RDS Aurora reader endpoint"
}

output "database_secret_arn" {
  value       = aws_secretsmanager_secret.db_secret.arn
  description = "Database secret ARN - for São Paulo apps to access DB credentials"
}

output "database_security_group_id" {
  value       = aws_security_group.tokyo_rds_sg.id
  description = "Database security group ID - for São Paulo security group rules"
}

# TGW PEERING OUTPUTS
output "tokyo_sao_peering_id" {
  value       = aws_ec2_transit_gateway_peering_attachment.tokyo_to_sao_peering.id
  description = "TGW peering attachment ID from Tokyo to São Paulo - for São Paulo accepter"
}

# São Paulo Transit Gateway ID (will be enabled after cross-region setup)
# output "saopaulo_transit_gateway_id" {
#   value       = data.terraform_remote_state.saopaulo.outputs.saopaulo_transit_gateway_id
#   description = "São Paulo Transit Gateway ID - referenced from remote state"
# }

# SHARED SERVICES
output "kms_key_id" {
  value       = local.taaops_kms_key_id
  description = "KMS key ID for encryption"
}

output "cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.taaops_cw_log_group01.name
  description = "CloudWatch log group name"
}

# DOMAIN
output "domain_name" {
  value       = var.domain_name
  description = "Primary domain name"
}

output "regional_waf_arn" {
  value       = aws_wafv2_web_acl.taaops_regional_waf_acl.arn
  description = "Regional ALB WAF ARN"
}

output "tokyo_alb_dns_name" {
  value       = aws_lb.tokyo_alb.dns_name
  description = "Tokyo ALB DNS name."
}

output "tokyo_alb_zone_id" {
  value       = aws_lb.tokyo_alb.zone_id
  description = "Tokyo ALB hosted zone ID."
}

output "tokyo_alb_sg_id" {
  value       = aws_security_group.taaops_alb01_sg443.id
  description = "Tokyo ALB security group ID."
}

output "tokyo_alb_https_listener_arn" {
  value       = aws_lb_listener.tokyo_alb_https_listener.arn
  description = "Tokyo ALB HTTPS listener ARN."
}

output "tokyo_alb_tg_arn" {
  value       = aws_lb_target_group.tokyo_tg80.arn
  description = "Tokyo ALB target group ARN."
}

# INCIDENT REPORTING OUTPUTS
output "incident_reports_bucket_name" {
  value       = aws_s3_bucket.tokyo_ir_reports_bucket.bucket
  description = "S3 bucket name for Tokyo incident reports"
}

output "incident_reports_bucket_arn" {
  value       = aws_s3_bucket.tokyo_ir_reports_bucket.arn
  description = "S3 bucket ARN for Tokyo incident reports"
}

output "ir_lambda_function_name" {
  value       = aws_lambda_function.tokyo_ir_lambda.function_name
  description = "Incident report Lambda function name"
}

output "ir_lambda_function_arn" {
  value       = aws_lambda_function.tokyo_ir_lambda.arn
  description = "Incident report Lambda function ARN"
}

output "ir_trigger_topic_arn" {
  value       = aws_sns_topic.tokyo_ir_trigger_topic.arn
  description = "SNS topic for triggering incident reports"
}

output "ir_reports_topic_arn" {
  value       = aws_sns_topic.tokyo_ir_reports_topic.arn
  description = "SNS topic for incident report notifications"
}

output "ssm_automation_document_name" {
  value       = aws_ssm_document.tokyo_alarm_report_runbook.name
  description = "SSM automation document for incident response"
}

output "route53_zone_id" {
  value       = data.aws_route53_zone.main-taaops.zone_id
  description = "Route53 hosted zone ID"
}

# REGION INFORMATION
output "tokyo_region" {
  value       = data.aws_region.current.name
  description = "Tokyo region name"
}

output "account_id" {
  value       = data.aws_caller_identity.taaops_self01.account_id
  description = "AWS Account ID"
}

# TRANSLATION MODULE OUTPUTS
output "translation_input_bucket_name" {
  value       = module.tokyo_translation.input_bucket_name
  description = "Translation input bucket name - upload incident reports here"
}

output "translation_input_bucket_arn" {
  value       = module.tokyo_translation.input_bucket_arn
  description = "Translation input bucket ARN"
}

output "translation_output_bucket_name" {
  value       = module.tokyo_translation.output_bucket_name
  description = "Translation output bucket name - temporary translated content"
}

output "translation_lambda_function_name" {
  value       = module.tokyo_translation.lambda_function_name
  description = "Translation Lambda function name"
}

output "translation_lambda_function_arn" {
  value       = module.tokyo_translation.lambda_function_arn
  description = "Translation Lambda function ARN"
}