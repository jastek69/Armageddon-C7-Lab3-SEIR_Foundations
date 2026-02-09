# Tokyo Region Variables - Lab 2 + TGW Hub Configuration

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

variable "alb_origin_cert_arn" {
  description = "Optional ACM cert ARN for the ALB origin hostname."
  type        = string
  default     = ""
}

variable "taaops" {
  description = "taaops project identifier"
  type        = string
  default     = "taaops"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "taaops"
}

# TOKYO VPC CONFIGURATION
variable "tokyo_vpc_cidr" {
  description = "Tokyo VPC CIDR (use 10.x.x.x/xx as instructed)."
  type        = string
  default     = "10.233.0.0/16"
}

# SÃO PAULO VPC CONFIGURATION (for cross-region reference)
variable "saopaulo_vpc_cidr" {
  description = "São Paulo VPC CIDR for cross-region access rules"
  type        = string
  default     = "10.234.0.0/16"
}

variable "tokyo_subnet_public_cidrs" {
  description = "Tokyo public subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.233.1.0/24", "10.233.2.0/24", "10.233.3.0/24"]
}

variable "tokyo_subnet_private_cidrs" {
  description = "Tokyo private subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.233.10.0/24", "10.233.11.0/24", "10.233.12.0/24"]
}

variable "tokyo_azs" {
  description = "Tokyo Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

# SECURITY
variable "admin_ssh_cidr" {
  description = "CIDR allowed to SSH into EC2 instances."
  type        = string
  default     = "0.0.0.0/0"
}

# EC2 CONFIGURATION
variable "ec2_ami_id" {
  description = "AMI ID for the EC2 app host."
  type        = string
  default     = "ami-0ebf411a80b6b22cb"
}

variable "ec2_instance_type" {
  description = "EC2 instance size for the app."
  type        = string
  default     = "t3.micro"
}

# DATABASE
variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "certificate_validation_method" {
  description = "ACM validation method for origin cert."
  type        = string
  default     = "DNS"
}

# REGIONAL CONFIGURATION
variable "aws_region" {
  description = "Tokyo AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_region_tls" {
  description = "Region for ACM certificate (us-east-1 for CloudFront)"
  type        = string
  default     = "us-east-1"
}

# SNS AND NOTIFICATIONS
variable "sns_email_endpoint" {
  description = "Email endpoint for SNS notifications"
  type        = string
  default     = "jastek.sweeney@gmail.com"
}

# ALARM CONFIGURATION
variable "alarm_reports_bucket_name" {
  description = "S3 bucket name for alarm reports"
  type        = string
  default     = "taaops-tokyo-alarm-reports"
}

variable "rds_cluster_identifier" {
  description = "Aurora cluster identifier (override if a previous name is reserved)"
  type        = string
  default     = "taaops-aurora-cluster-02"
}

# SECRETS ROTATION
variable "secrets_rotation_days" {
  description = "Number of days between Secrets Manager rotations"
  type        = number
  default     = 30
}

# AUTOMATION CONFIGURATION
variable "automation_parameters_json" {
  description = "JSON parameters for automation document"
  type        = string
  default     = "{\"Param1\":[\"value1\"],\"Param2\":[\"value2\"]}"
}

# WAF LOGGING CONFIGURATION
variable "waf_log_destination" {
  description = "WAF log destination type: cloudwatch or firehose"
  type        = string
  default     = "cloudwatch"
  validation {
    condition     = contains(["cloudwatch", "firehose"], var.waf_log_destination)
    error_message = "WAF log destination must be either 'cloudwatch' or 'firehose'."
  }
}

variable "waf_log_retention_days" {
  description = "WAF log retention in days"
  type        = number
  default     = 14
}

variable "enable_waf" {
  description = "Enable WAF logging"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logging" {
  description = "Enable CloudWatch logging for WAF"
  type        = bool
  default     = true
}

variable "enable_firehose_logging" {
  description = "Enable Firehose logging for WAF"
  type        = bool
  default     = false
}

# INCIDENT REPORTING CONFIGURATION
variable "bedrock_model_id" {
  description = "Bedrock model ID for incident report generation"
  type        = string
  default     = "mistral.mistral-large-3-675b-instruct"
}

variable "incident_report_retention_days" {
  description = "Retention days for incident reports in S3"
  type        = number
  default     = 2555 # 7 years
}

variable "enable_bedrock" {
  description = "Enable Bedrock for AI-generated incident reports"
  type        = bool
  default     = true
}

variable "enable_translation" {
  description = "Enable automatic translation of incident reports"
  type        = bool
  default     = true
}

# COMMON TAGS
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Region      = "Tokyo"
    Purpose     = "LAB3-MultiRegion"
    Environment = "production"
  }
}

# AUTOMATION AND MONITORING CONFIGURATION
variable "alarm_asg_name" {
  description = "Auto Scaling Group name for alarm monitoring"
  type        = string
  default     = "tokyo-app-asg"
}

variable "automation_document_name" {
  description = "SSM automation document name for incident response"
  type        = string
  default     = "taaops-tokyo-incident-report"
}