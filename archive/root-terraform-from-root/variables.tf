# variable image_name {} # for AMI
variable "domain_name" {
  description = "domain name: jastek.click"
  type        = string
  default     = "jastek.click"
}

variable "app_subdomain" {
  description = "App hostname prefix (e.g., app.jastek.click)."
  type        = string
  default     = "app"
}

variable "alb_origin_subdomain" {
  description = "Dedicated ALB origin hostname prefix for CloudFront (e.g., origin.jastek.click)."
  type        = string
  default     = "origin"
}




variable "taaops" {
  description = "taaops"
  type        = string
  default     = "taaops"
}


#TOKYO VPC CIDR
variable "tokyo_vpc_cidr" {
  description = "VPC CIDR (use 10.x.x.x/xx as instructed)."
  type        = string
  default     = "10.233.0.0/16"
}


#SAO PAULO VPC CIDR
variable "saopaulo_vpc_cidr" {
  description = "VPC CIDR (use 10.x.x.x/xx as instructed)."
  type        = string
  default     = "10.234.0.0/16"
}


variable "admin_ssh_cidr" {
  description = "CIDR allowed to SSH into EC2 instances."
  type        = string
  default     = "0.0.0.0/0"
}

# SUBNET - Tokyo
variable "tokyo_subnet_public_cidrs" {
  description = "Public subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.233.1.0/24", "10.233.2.0/24", "10.233.3.0/24"]
}

variable "tokyo_subnet_private_cidrs" {
  description = "Private subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.233.10.0/24", "10.233.11.0/24", "10.233.12.0/24"]
}



# SUBNET - Sao Paulo
variable "sao_subnet_public_cidrs" {
  description = "Public subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.234.1.0/24", "10.234.2.0/24", "10.234.3.0/24"]
}

variable "sao_subnet_private_cidrs" {
  description = "Private subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.234.10.0/24", "10.234.11.0/24", "10.234.12.0/24"]
}

# AVAILABILITY ZONES - Tokyo
variable "tokyo_azs" {
  description = "Tokyo Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

# AVAILABILITY ZONES - São Paulo
variable "sao_azs" {
  description = "São Paulo Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
}



variable "azs" {
  description = "Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["sa-east-1", "ap-northeast-1"]
}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 app host."
  type        = string
  default     = "ami-0ebf411a80b6b22cb" # Amazon Linux 2 AMI ID for Oregon (us-west-2)
}

variable "ec2_instance_type" {
  description = "EC2 instance size for the app."
  type        = string
  default     = "t3.micro"
}


variable "kms_key_id" {
  # Optional override: use an existing CMK instead of the Terraform-managed key.
  type        = string
  description = "The ID/ARN of the AWS KMS key to use for encryption (optional override)."
  sensitive   = true
  default     = ""
}

variable "key_pair_name" {
  type        = string
  description = "The name of the existing key pair to use for EC2 instances."
  default     = "rds-ssh-lab01"
}

variable "TF_VAR_terraform_bucket" {
  type        = string
  description = "The name of the S3 bucket for Terraform state."
}

variable "TF_VAR_organization" {
  type        = string
  description = "taaops"
}

variable "project_name" {
  description = "Project name prefix for resources."
  type        = string
  default     = "taaops"
}

# TOKYO - Main Hub
variable "aws_region" {
  description = "AWS Region for the Taa 2 mothership."
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_region_tls" {
  description = "AWS Region for provider TLS"
  type        = string
  default     = "us-east-1"
}

variable "tokyo_availability_zones" {
  description = "List of Availability Zones to use."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1b", "ap-northeast-1c"]
}





variable "certificate_validation_method" {
  description = "ACM validation method. DNS (Route53) or EMAIL."
  type        = string
  default     = "DNS"
}

variable "alb_origin_cert_arn" {
  description = "Optional ACM cert ARN in us-west-2 for the ALB origin hostname (leave empty to create)."
  type        = string
  default     = ""
}

variable "enable_waf" {
  description = "Toggle WAF creation."
  type        = bool
  default     = true
}


variable "waf_log_destination" {
  description = "WAF log destination: 'cloudwatch' or 'firehose' (S3 via Firehose)."
  type        = string
  default     = "cloudwatch"
  validation {
    condition     = contains(["cloudwatch", "firehose"], var.waf_log_destination)
    error_message = "waf_log_destination must be 'cloudwatch' or 'firehose'. WAF does not support direct S3 logging; use Firehose for S3 storage."
  }
}

variable "waf_log_retention_days" {
  description = "CloudWatch Logs retention (days) for WAF logging when destination is cloudwatch."
  type        = number
  default     = 30
}


# Cloudwatch Alarm thresholds
variable "alb_5xx_threshold" {
  description = "Alarm threshold for ALB 5xx count."
  type        = number
  default     = 10
}

variable "alb_5xx_period_seconds" {
  description = "CloudWatch alarm period."
  type        = number
  default     = 300
}

variable "alb_5xx_evaluation_periods" {
  description = "Evaluation periods for alarm."
  type        = number
  default     = 1
}


# CLOUDWATCH AGENT VARIABLES
variable "cw_agent_config_param_name" {
  description = "SSM parameter name for CloudWatch Agent config."
  type        = string
  default     = "/cw/agent/config"
}

variable "cw_agent_log_file_path" {
  description = "Log file path to ship via CloudWatch Agent."
  type        = string
  default     = "/var/log/rdsapp.log"
}

variable "cw_agent_log_group_name" {
  description = "CloudWatch Logs group for EC2 app logs."
  type        = string
  default     = "/aws/ec2/rdsapp"
}

variable "cw_agent_target_tag_key" {
  description = "Tag key used to target instances for CW Agent SSM association."
  type        = string
  default     = "ManagedBy"
}

variable "cw_agent_target_tag_value" {
  description = "Tag value used to target instances for CW Agent SSM association."
  type        = string
  default     = "Terraform"
}

variable "sns_email_endpoint" {
  description = "Email address for CloudWatch alarm notifications (optional)."
  type        = string
  default     = ""
}

variable "alarm_reports_bucket_name" {
  description = "S3 bucket name to store alarm report bundles."
  type        = string
}

variable "alarm_logs_group_name" {
  description = "CloudWatch Logs group name used for Logs Insights queries."
  type        = string
  default     = "/aws/ec2/rdsapp"
}

variable "alarm_logs_insights_query" {
  description = "CloudWatch Logs Insights query for alarm evidence."
  type        = string
  default     = "fields @timestamp, @message | sort @timestamp desc | limit 50"
}

variable "alarm_ssm_param_name" {
  description = "SSM parameter name with DB connection config."
  type        = string
  default     = ""
}

variable "alarm_secret_id" {
  description = "Secrets Manager secret ID or ARN for DB credentials."
  type        = string
  default     = ""
}

variable "alarm_asg_name" {
  description = "Auto Scaling Group name to refresh when alarms fire (optional)."
  type        = string
  default     = ""
}

variable "automation_document_name" {
  description = "SSM Automation document name to trigger from the alarm hook."
  type        = string
  default     = ""
}

variable "automation_parameters_json" {
  description = "JSON map of parameters to pass to the SSM Automation document (optional)."
  type        = string
  default     = ""
}

variable "bedrock_model_id" {
  description = "Bedrock model ID for report generation (optional)."
  type        = string
  default     = ""
}


# DATABASE VARIABLES
variable "db_engine" {
  description = "RDS engine."
  type        = string
  default     = "mysql"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "taa2db"
}

variable "db_username" {
  description = "DB master username (use Secrets Manager in 1B/1C)."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "DB master password (DO NOT hardcode in real life; for lab only)."
  type        = string
  sensitive   = true
  default     = "armagedd0n"
}

variable "secrets_rotation_days" {
  description = "Secrets Manager rotation interval in days. Use 1 for testing; set to 30+ for production."
  type        = number
  default     = 30
}


/*

variable "sns_email_endpoint" {
  description = "Email for SNS subscription (PagerDuty simulation)."
  type        = string
  default     = "student@example.com" # TODO: student supplies
}

variable "domain_name" {
  description = "Base domain students registered (e.g., jastek.click)."
  type        = string
  default     = "jastek.click"
}

variable "app_subdomain" {
  description = "App hostname prefix (e.g., app.jastek.click)."
  type        = string
  default     = "app"
}

variable "certificate_validation_method" {
  description = "ACM validation method. Students can do DNS (Route53) or EMAIL."
  type        = string
  default     = "DNS"
}

variable "enable_waf" {
  description = "Toggle WAF creation."
  type        = bool
  default     = true
}

variable "alb_5xx_threshold" {
  description = "Alarm threshold for ALB 5xx count."
  type        = number
  default     = 10
}

variable "alb_5xx_period_seconds" {
  description = "CloudWatch alarm period."
  type        = number
  default     = 300
}

variable "alb_5xx_evaluation_periods" {
  description = "Evaluation periods for alarm."
  type        = number
  default     = 1
}

*/
