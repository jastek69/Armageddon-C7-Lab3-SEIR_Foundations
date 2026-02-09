# São Paulo Region Variables - Lab 2 minus DB + TGW Spoke Configuration

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "taaops"
}

# SÃO PAULO VPC CONFIGURATION
variable "saopaulo_vpc_cidr" {
  description = "São Paulo VPC CIDR (use 10.x.x.x/xx as instructed)."
  type        = string
  default     = "10.234.0.0/16"
}

variable "sao_subnet_public_cidrs" {
  description = "São Paulo public subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.234.1.0/24", "10.234.2.0/24", "10.234.3.0/24"]
}

variable "sao_subnet_private_cidrs" {
  description = "São Paulo private subnet CIDRs (use 10.x.x.x/xx)."
  type        = list(string)
  default     = ["10.234.10.0/24", "10.234.11.0/24", "10.234.12.0/24"]
}

variable "sao_azs" {
  description = "São Paulo Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
}

# TOKYO REFERENCE (for TGW peering - actual values come from remote state)
variable "tokyo_vpc_cidr" {
  description = "Tokyo VPC CIDR for routing (overridden by remote state)"
  type        = string
  default     = "10.233.0.0/16"
}

variable "tokyo_region" {
  description = "Tokyo region for TGW peering"
  type        = string
  default     = "ap-northeast-1"
}

# SECURITY
variable "admin_ssh_cidr" {
  description = "CIDR allowed to SSH into EC2 instances."
  type        = string
  default     = "0.0.0.0/0"
}

# EC2 CONFIGURATION
variable "ec2_ami_id" {
  description = "AMI ID for the EC2 app host (São Paulo region)"
  type        = string
  default     = "ami-0f85876b1aff99dde"  # Amazon Linux 2023 (x86_64) for sa-east-1
}

variable "ec2_instance_type" {
  description = "EC2 instance size for the app."
  type        = string
  default     = "t3.micro"
}

# REGIONAL CONFIGURATION
variable "aws_region" {
  description = "São Paulo AWS region"
  type        = string
  default     = "sa-east-1"
}

# REMOTE STATE CONFIGURATION
variable "tokyo_state_bucket" {
  description = "S3 bucket containing Tokyo Terraform state"
  type        = string
}

variable "tokyo_state_key" {
  description = "S3 key for Tokyo Terraform state"
  type        = string
  default     = "tokyo/terraform.tfstate"
}

variable "tokyo_state_region" {
  description = "Region where Tokyo state bucket is located"
  type        = string
  default     = "ap-northeast-1"
}