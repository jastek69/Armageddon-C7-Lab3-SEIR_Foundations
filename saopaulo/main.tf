# São Paulo Region - TGW Spoke Configuration
# This contains compute infrastructure that connects to Tokyo's database via Transit Gateway

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.24.0"
    }
  }
  required_version = ">= 1.3"
}

# PROVIDER CONFIGURATION
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Region    = "SaoPaulo"
      Purpose   = "ComputeSpoke"
      Project   = "LAB3-Armageddon"
    }
  }
}

# VARIABLES AND LOCALS

################################################################################
# MODULE CALLS - Regional services
################################################################################

# Regional IAM Module
module "regional_iam" {
  source = "../modules/regional-iam"

  region_name            = "saopaulo"
  project_name           = var.project_name
  enable_database_access = true
  database_secret_arn    = local.db_secret_arn
}

# Regional S3 Logging Module
module "s3_logging" {
  source = "../modules/regional-s3-logging"

  region_name        = "saopaulo"
  project_name       = var.project_name
  enable_alb_logging = true
  log_retention_days = 90
  kms_key_id         = null
}

# Regional Monitoring Module
module "monitoring" {
  source = "../modules/regional-monitoring"

  region_name         = "saopaulo"
  project_name        = var.project_name
  log_retention_days  = 14
  sns_email_endpoints = []
  enable_alarms       = true
}



# S3 - Backend Bucket (pre-existing, managed outside this stack)
# resource "aws_s3_bucket" "saopaulo_backend_logs" {
#   bucket        = "taaops-terraform-state-saopaulo"
#   force_destroy = true # Allow Terraform to delete the bucket even if it contains objects. - Only for DEV/TEST use!
# }


################################################################################
# VPC AND NETWORKING
################################################################################

# São Paulo VPC
resource "aws_vpc" "liberdade_vpc01" {
  cidr_block           = var.saopaulo_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-sao-vpc01"
  }
}

# São Paulo Public Subnets
resource "aws_subnet" "sao_subnet_public_a" {
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_public_cidrs[0]
  availability_zone       = var.sao_azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-sao-public-subnet-a"
    Type = "Public"
  }
}

resource "aws_subnet" "sao_subnet_public_b" {
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_public_cidrs[1]
  availability_zone       = var.sao_azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-sao-public-subnet-b"
    Type = "Public"
  }
}

resource "aws_subnet" "sao_subnet_public_c" {
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_public_cidrs[2]
  availability_zone       = var.sao_azs[2]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-sao-public-subnet-c"
    Type = "Public"
  }
}

# São Paulo Private Subnets
resource "aws_subnet" "sao_subnet_private_a" {
  vpc_id            = aws_vpc.liberdade_vpc01.id
  cidr_block        = var.sao_subnet_private_cidrs[0]
  availability_zone = var.sao_azs[0]

  tags = {
    Name = "${local.name_prefix}-sao-private-subnet-a"
    Type = "Private"
  }
}

resource "aws_subnet" "sao_subnet_private_b" {
  vpc_id            = aws_vpc.liberdade_vpc01.id
  cidr_block        = var.sao_subnet_private_cidrs[1]
  availability_zone = var.sao_azs[1]

  tags = {
    Name = "${local.name_prefix}-sao-private-subnet-b"
    Type = "Private"
  }
}

resource "aws_subnet" "sao_subnet_private_c" {
  vpc_id            = aws_vpc.liberdade_vpc01.id
  cidr_block        = var.sao_subnet_private_cidrs[2]
  availability_zone = var.sao_azs[2]

  tags = {
    Name = "${local.name_prefix}-sao-private-subnet-c"
    Type = "Private"
  }
}

# Transit Gateway Subnet (for TGW attachment)
resource "aws_subnet" "sao_tgw_subnet" {
  vpc_id            = aws_vpc.liberdade_vpc01.id
  cidr_block        = "10.234.100.0/28"
  availability_zone = var.sao_azs[0]

  tags = {
    Name = "${local.name_prefix}-sao-tgw-subnet"
    Type = "TransitGateway"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "sao_igw01" {
  vpc_id = aws_vpc.liberdade_vpc01.id

  tags = {
    Name = "${local.name_prefix}-sao-igw01"
  }
}

# EIP and NAT Gateway
resource "aws_eip" "sao_nat_eip" {
  domain = "vpc"
  tags = {
    Name = "sao-nat-eip"
  }
}

resource "aws_nat_gateway" "sao_regional_nat_gw" {
  allocation_id = aws_eip.sao_nat_eip.id
  subnet_id     = aws_subnet.sao_subnet_public_a.id
  tags = {
    Name = "sao-regional-nat-gw"
  }
  depends_on = [aws_internet_gateway.sao_igw01]
}

################################################################################
# ROUTING TABLES
################################################################################

# Public Route Table
resource "aws_route_table" "sao_public_rt" {
  vpc_id = aws_vpc.liberdade_vpc01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sao_igw01.id
  }

  route {
    cidr_block         = local.tokyo_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  }

  tags = {
    Name = "${local.name_prefix}-sao-public-rt"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.sao_vpc_attachment,
    aws_ec2_transit_gateway_peering_attachment_accepter.sao_accept_peering
  ]
}

# Private Route Table
resource "aws_route_table" "sao_private_rt" {
  vpc_id = aws_vpc.liberdade_vpc01.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.sao_regional_nat_gw.id
  }

  route {
    cidr_block         = local.tokyo_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  }

  tags = {
    Name = "${local.name_prefix}-sao-private-rt"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.sao_vpc_attachment,
    aws_ec2_transit_gateway_peering_attachment_accepter.sao_accept_peering
  ]
}

# Route Table Associations
resource "aws_route_table_association" "sao_public_rt_assoc_a" {
  subnet_id      = aws_subnet.sao_subnet_public_a.id
  route_table_id = aws_route_table.sao_public_rt.id
}

resource "aws_route_table_association" "sao_public_rt_assoc_b" {
  subnet_id      = aws_subnet.sao_subnet_public_b.id
  route_table_id = aws_route_table.sao_public_rt.id
}

resource "aws_route_table_association" "sao_public_rt_assoc_c" {
  subnet_id      = aws_subnet.sao_subnet_public_c.id
  route_table_id = aws_route_table.sao_public_rt.id
}

resource "aws_route_table_association" "sao_private_rt_assoc_a" {
  subnet_id      = aws_subnet.sao_subnet_private_a.id
  route_table_id = aws_route_table.sao_private_rt.id
}

resource "aws_route_table_association" "sao_private_rt_assoc_b" {
  subnet_id      = aws_subnet.sao_subnet_private_b.id
  route_table_id = aws_route_table.sao_private_rt.id
}

resource "aws_route_table_association" "sao_private_rt_assoc_c" {
  subnet_id      = aws_subnet.sao_subnet_private_c.id
  route_table_id = aws_route_table.sao_private_rt.id
}

################################################################################
# TRANSIT GATEWAY - SPOKE CONFIGURATION
################################################################################

# São Paulo Transit Gateway (Spoke)
resource "aws_ec2_transit_gateway" "liberdade_tgw01" {
  description                     = "Sao Paulo Transit Gateway - Compute Spoke"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name    = "liberdade-tgw01"
    Purpose = "ComputeSpoke"
  }
}

# VPC attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "sao_vpc_attachment" {
  subnet_ids         = [aws_subnet.sao_tgw_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  vpc_id             = aws_vpc.liberdade_vpc01.id

  tags = {
    Name = "sao-vpc-attachment"
  }
}

# Accept peering connection from Tokyo
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "sao_accept_peering" {
  transit_gateway_attachment_id = data.terraform_remote_state.tokyo.outputs.tokyo_sao_peering_id

  tags = merge(local.common_tags, {
    Name = "sao-accept-tokyo-peering"
    Side = "Accepter"
  })
}


################################################################################
# SECURITY GROUPS
################################################################################

# EC2 Security Group for São Paulo
resource "aws_security_group" "sao_ec2_app_sg" {
  name        = "sao_ec2_app_sg"
  description = "Security group for Sao Paulo EC2 application instances"
  vpc_id      = aws_vpc.liberdade_vpc01.id

  ingress {
    description = "HTTP for applications"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.saopaulo_vpc_cidr]
  }

  ingress {
    description = "HTTPS for applications"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.saopaulo_vpc_cidr]
  }

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
  }

  # Allow database access to Tokyo
  egress {
    description = "MySQL to Tokyo database"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.tokyo_vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sao-ec2-app-sg"
  }
}

################################################################################
# COMPUTE RESOURCES (EC2) - Using Regional IAM Module
################################################################################

# Launch Template for Auto Scaling
resource "aws_launch_template" "sao_app_template" {
  name_prefix   = "sao-app-"
  image_id      = var.ec2_ami_id
  instance_type = var.ec2_instance_type

  vpc_security_group_ids = [aws_security_group.sao_ec2_app_sg.id]

  iam_instance_profile {
    name = module.regional_iam.ec2_instance_profile_name
  }

  user_data = filebase64("${path.module}/user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "sao-app-instance"
    })
  }

  tags = merge(local.common_tags, {
    Name = "sao-app-template"
  })
}

# Auto Scaling Group
resource "aws_autoscaling_group" "sao_app_asg" {
  name                = "sao-app-asg"
  vpc_zone_identifier = [
    aws_subnet.sao_subnet_private_a.id,
    aws_subnet.sao_subnet_private_b.id,
    aws_subnet.sao_subnet_private_c.id
  ]
  target_group_arns   = [aws_lb_target_group.sao_app_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 1
  max_size            = 6
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.sao_app_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sao-app-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

################################################################################
# APPLICATION LOAD BALANCER
################################################################################

# ALB Security Group
resource "aws_security_group" "sao_alb_sg" {
  name_prefix = "sao-alb-"
  vpc_id      = aws_vpc.liberdade_vpc01.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "sao-alb-sg"
  })
}

# Target Group
resource "aws_lb_target_group" "sao_app_tg" {
  name     = "sao-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.liberdade_vpc01.id
  
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

  tags = merge(local.common_tags, {
    Name = "sao-app-tg"
  })
}

# Application Load Balancer
resource "aws_lb" "sao_app_lb" {
  name               = "sao-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sao_alb_sg.id]
  subnets            = [
    aws_subnet.sao_subnet_public_a.id,
    aws_subnet.sao_subnet_public_b.id,
    aws_subnet.sao_subnet_public_c.id
  ]

  access_logs {
    bucket  = module.s3_logging.alb_logs_bucket_name
    prefix  = "sao-alb"
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "sao-app-lb"
  })
}

# ALB Listener
resource "aws_lb_listener" "sao_app_listener" {
  load_balancer_arn = aws_lb.sao_app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sao_app_tg.arn
  }

  tags = merge(local.common_tags, {
    Name = "sao-app-listener"
  })
}