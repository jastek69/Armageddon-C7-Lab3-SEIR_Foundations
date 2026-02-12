# Tokyo Region - Lab 2 + TGW Hub Configuration
# This contains the complete Lab 2 infrastructure plus Transit Gateway hub for cross-region connectivity

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.24.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# PROVIDERS
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Region    = "Tokyo"
      Purpose   = "DataAuthority"
    }
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = var.aws_region_tls
}

provider "aws" {
  alias  = "saopaulo"
  region = "sa-east-1"
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Region    = "SaoPaulo"
      Purpose   = "DataConsumer"
    }
  }
}

provider "tls" {}

# DATA SOURCES
data "aws_region" "current" {}
data "aws_caller_identity" "taaops_self01" {}

# São Paulo remote state for cross-region integration
data "terraform_remote_state" "saopaulo" {
  backend = "s3"
  config = {
    bucket  = "taaops-terraform-state-saopaulo"
    key     = "saopaulo/terraform.tfstate"
    region  = "sa-east-1"
  }
}

data "aws_route53_zone" "main-taaops" {
  name = var.domain_name
}

# LOCALS
locals {
  name_prefix       = var.taaops
  taaops_kms_key_id = aws_kms_key.taaops_kms_key01.arn
}


# S3 Backend
resource "aws_s3_bucket" "tokyo_backend_logs" {
  bucket        = "tokyo-backend-logs-${data.aws_caller_identity.taaops_self01.account_id}"
  force_destroy = true # Allow Terraform to delete the bucket even if it contains objects. - Only for DEV/TEST use!
}

################################################################################
# VPC AND NETWORKING
################################################################################

# Tokyo VPC
resource "aws_vpc" "shinjuku_vpc01" {
  cidr_block           = var.tokyo_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-tokyo-vpc01"
  }
}

# Tokyo Public Subnets
resource "aws_subnet" "tokyo_subnet_public_a" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_public_cidrs[0]
  availability_zone       = var.tokyo_azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-tokyo-public-subnet-a"
    Type = "Public"
  }
}

resource "aws_subnet" "tokyo_subnet_public_b" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_public_cidrs[1]
  availability_zone       = var.tokyo_azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-tokyo-public-subnet-b"
    Type = "Public"
  }
}

resource "aws_subnet" "tokyo_subnet_public_c" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_public_cidrs[2]
  availability_zone       = var.tokyo_azs[2]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-tokyo-public-subnet-c"
    Type = "Public"
  }
}

# Tokyo Private Subnets
resource "aws_subnet" "tokyo_subnet_private_a" {
  vpc_id            = aws_vpc.shinjuku_vpc01.id
  cidr_block        = var.tokyo_subnet_private_cidrs[0]
  availability_zone = var.tokyo_azs[0]

  tags = {
    Name = "${local.name_prefix}-tokyo-private-subnet-a"
    Type = "Private"
  }
}

resource "aws_subnet" "tokyo_subnet_private_b" {
  vpc_id            = aws_vpc.shinjuku_vpc01.id
  cidr_block        = var.tokyo_subnet_private_cidrs[1]
  availability_zone = var.tokyo_azs[1]

  tags = {
    Name = "${local.name_prefix}-tokyo-private-subnet-b"
    Type = "Private"
  }
}

resource "aws_subnet" "tokyo_subnet_private_c" {
  vpc_id            = aws_vpc.shinjuku_vpc01.id
  cidr_block        = var.tokyo_subnet_private_cidrs[2]
  availability_zone = var.tokyo_azs[2]

  tags = {
    Name = "${local.name_prefix}-tokyo-private-subnet-c"
    Type = "Private"
  }
}

# Transit Gateway Subnet (for TGW attachment)
resource "aws_subnet" "tokyo_tgw_subnet" {
  vpc_id            = aws_vpc.shinjuku_vpc01.id
  cidr_block        = "10.233.100.0/28"
  availability_zone = var.tokyo_azs[0]

  tags = {
    Name = "${local.name_prefix}-tokyo-tgw-subnet"
    Type = "TransitGateway"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "tokyo_igw01" {
  vpc_id = aws_vpc.shinjuku_vpc01.id

  tags = {
    Name = "${local.name_prefix}-tokyo-igw01"
  }
}

# EIP and NAT Gateway
resource "aws_eip" "tokyo_nat_eip" {
  domain = "vpc"
  tags = {
    Name = "tokyo-nat-eip"
  }
}

resource "aws_nat_gateway" "tokyo_regional_nat_gw" {
  allocation_id = aws_eip.tokyo_nat_eip.id
  subnet_id     = aws_subnet.tokyo_subnet_public_a.id
  tags = {
    Name = "tokyo-regional-nat-gw"
  }
  depends_on = [aws_internet_gateway.tokyo_igw01]
}

################################################################################
# ROUTING TABLES  
################################################################################

# Public Route Table
resource "aws_route_table" "tokyo_public_rt" {
  vpc_id = aws_vpc.shinjuku_vpc01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tokyo_igw01.id
  }

  route {
    cidr_block         = var.saopaulo_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  }

  tags = {
    Name = "${local.name_prefix}-tokyo-public-rt"
  }
}

# Private Route Table
resource "aws_route_table" "tokyo_private_rt" {
  vpc_id = aws_vpc.shinjuku_vpc01.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tokyo_regional_nat_gw.id
  }

  route {
    cidr_block         = var.saopaulo_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  }

  tags = {
    Name = "${local.name_prefix}-tokyo-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "tokyo_public_rt_assoc_a" {
  subnet_id      = aws_subnet.tokyo_subnet_public_a.id
  route_table_id = aws_route_table.tokyo_public_rt.id
}

resource "aws_route_table_association" "tokyo_public_rt_assoc_b" {
  subnet_id      = aws_subnet.tokyo_subnet_public_b.id
  route_table_id = aws_route_table.tokyo_public_rt.id
}

resource "aws_route_table_association" "tokyo_public_rt_assoc_c" {
  subnet_id      = aws_subnet.tokyo_subnet_public_c.id
  route_table_id = aws_route_table.tokyo_public_rt.id
}

resource "aws_route_table_association" "tokyo_private_rt_assoc_a" {
  subnet_id      = aws_subnet.tokyo_subnet_private_a.id
  route_table_id = aws_route_table.tokyo_private_rt.id
}

resource "aws_route_table_association" "tokyo_private_rt_assoc_b" {
  subnet_id      = aws_subnet.tokyo_subnet_private_b.id
  route_table_id = aws_route_table.tokyo_private_rt.id
}

resource "aws_route_table_association" "tokyo_private_rt_assoc_c" {
  subnet_id      = aws_subnet.tokyo_subnet_private_c.id
  route_table_id = aws_route_table.tokyo_private_rt.id
}

################################################################################
# TRANSIT GATEWAY - HUB CONFIGURATION
################################################################################

# Tokyo Transit Gateway (Hub)
resource "aws_ec2_transit_gateway" "shinjuku_tgw01" {
  description                     = "Tokyo Transit Gateway - Data Authority Hub"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name    = "shinjuku-tgw01"
    Purpose = "DataAuthorityHub"
  }
}

# VPC attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "tokyo_vpc_attachment" {
  subnet_ids         = [aws_subnet.tokyo_tgw_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  vpc_id             = aws_vpc.shinjuku_vpc01.id

  tags = {
    Name = "tokyo-vpc-attachment"
  }
}

# Inter-Region Peering to São Paulo
resource "aws_ec2_transit_gateway_peering_attachment" "tokyo_to_sao_peering" {
  count = can(data.terraform_remote_state.saopaulo.outputs.saopaulo_transit_gateway_id) ? 1 : 0

  transit_gateway_id      = aws_ec2_transit_gateway.shinjuku_tgw01.id
  peer_transit_gateway_id = data.terraform_remote_state.saopaulo.outputs.saopaulo_transit_gateway_id
  peer_region             = "sa-east-1"

  tags = {
    Name = "tokyo-to-sao-peering"
    Side = "Requester"
  }

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.tokyo_vpc_attachment]
}

# Optional: Data source for São Paulo remote state (if São Paulo deployed first)
# Tokyo state reference (will be enabled after initial deployment)
# data "terraform_remote_state" "tokyo-state" {
#   backend = "s3"
#   config = {
#     bucket = "taaops-terraform-state-tokyo"
#     key    = "tokyo/terraform.tfstate"
#     region = "ap-northeast-1"
#   }
# }

################################################################################
# SECURITY GROUPS
################################################################################

# ALB Security Group
resource "aws_security_group" "taaops_alb01_sg443" {
  name        = "tokyo-LB01-sg443"
  description = "Security group for Tokyo Load Balancer"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "tokyo_LB01-sg01-443"
    Service = "application1"
  }
}

# EC2 Security Group
resource "aws_security_group" "tokyo_ec2_app_sg" {
  name        = "tokyo_ec2_app_sg"
  description = "Security group for Tokyo EC2 application instances"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  ingress {
    description     = "HTTP from load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.taaops_alb01_sg443.id]
  }

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tokyo-ec2-app-sg"
  }
}

################################################################################
# SHARED SERVICES (KMS, SECRETS MANAGER, IAM)
################################################################################

# KMS Key
resource "aws_kms_key" "taaops_kms_key01" {
  description             = "TaaOps KMS key for encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "taaops-kms-key01"
  }
}

resource "aws_kms_alias" "taaops_kms_alias01" {
  name          = "alias/taaops-key01"
  target_key_id = aws_kms_key.taaops_kms_key01.key_id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "taaops_cw_log_group01" {
  name              = "/taaops/application"
  retention_in_days = 14

  tags = {
    Name = "taaops-log-group"
  }
}

################################################################################
# REGIONAL MODULES
################################################################################

# Regional IAM Module (Tokyo)
module "tokyo_regional_iam" {
  source = "../modules/regional-iam"

  region_name            = "tokyo"
  project_name           = var.project_name
  enable_database_access = true
  database_secret_arn    = aws_secretsmanager_secret.db_secret.arn
}

# Regional Monitoring Module (Tokyo)
module "tokyo_monitoring" {
  source = "../modules/regional-monitoring"

  region_name         = "tokyo"
  project_name        = var.project_name
  log_retention_days  = 14
  sns_email_endpoints = [] # Add email addresses if needed
  enable_alarms       = true
}

# Regional S3 Logging Module (Tokyo)
module "tokyo_s3_logging" {
  source = "../modules/regional-s3-logging"

  region_name        = "tokyo"
  project_name       = var.project_name
  enable_alb_logging = true
  log_retention_days = 90
  kms_key_id         = aws_kms_key.taaops_kms_key01.arn
}

# Translation Module (Tokyo) - English ⇆ Japanese Incident Reports
module "tokyo_translation" {
  source = "../modules/translation"

  region = var.aws_region
  common_tags = {
    ManagedBy = "Terraform"
    Region    = "Tokyo"
    Purpose   = "IncidentReportTranslation"
    Project   = var.project_name
  }

  # S3 bucket configuration
  input_bucket_name   = "${local.name_prefix}-translate-input"
  output_bucket_name  = "${local.name_prefix}-translate-output"
  reports_bucket_name = module.tokyo_s3_logging.application_logs_bucket_name
  reports_bucket_arn  = module.tokyo_s3_logging.application_logs_bucket_arn

  # Translation settings
  source_language    = "en" # Default to English
  target_language    = "ja" # Target Japanese
  lambda_timeout     = 300  # 5 minutes for document processing
  log_retention_days = 14
}

################################################################################
# LOAD BALANCER
################################################################################

# Application Load Balancer
resource "aws_lb" "tokyo_alb" {
  name               = "${local.name_prefix}-tokyo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.taaops_alb01_sg443.id]
  subnets = [
    aws_subnet.tokyo_subnet_public_a.id,
    aws_subnet.tokyo_subnet_public_b.id,
    aws_subnet.tokyo_subnet_public_c.id
  ]

  enable_deletion_protection = false

  access_logs {
    bucket  = module.tokyo_s3_logging.alb_logs_bucket_name
    enabled = true
  }

  tags = {
    Name = "${local.name_prefix}-tokyo-alb"
  }

  depends_on = [module.tokyo_s3_logging]
}

# Target Group
resource "aws_lb_target_group" "tokyo_tg80" {
  name     = "${local.name_prefix}-tokyo-tg80"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.shinjuku_vpc01.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${local.name_prefix}-tokyo-tg80"
  }
}

# ALB Listener
resource "aws_lb_listener" "tokyo_alb_listener" {
  load_balancer_arn = aws_lb.tokyo_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tokyo_tg80.arn
  }
}

################################################################################
# EC2 AUTO SCALING
################################################################################

# Launch Template
resource "aws_launch_template" "tokyo_app_template" {
  name_prefix   = "tokyo-app-"
  image_id      = var.ec2_ami_id
  instance_type = var.ec2_instance_type

  vpc_security_group_ids = [aws_security_group.tokyo_ec2_app_sg.id]

  iam_instance_profile {
    name = module.tokyo_regional_iam.ec2_instance_profile_name
  }

  user_data = filebase64("${path.module}/user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "tokyo-app-instance"
      Region  = "Tokyo"
      Purpose = "Application"
    }
  }

  depends_on = [module.tokyo_regional_iam]
}

# Auto Scaling Group
resource "aws_autoscaling_group" "tokyo_app_asg" {
  name = "tokyo-app-asg"
  vpc_zone_identifier = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]
  target_group_arns = [aws_lb_target_group.tokyo_tg80.arn]
  health_check_type = "ELB"
  min_size          = 2
  max_size          = 6
  desired_capacity  = 2

  launch_template {
    id      = aws_launch_template.tokyo_app_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "tokyo-app-instance"
    propagate_at_launch = true
  }
}
