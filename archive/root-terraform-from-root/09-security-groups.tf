# Security Groups for Multi-Region Architecture
# Database remains secure in Tokyo, accessible only from authenticated sources

########################## TOKYO REGION SECURITY GROUPS ##########################

# Tokyo Load Balancer Security Group
resource "aws_security_group" "tokyo_alb_sg" {
  name        = "tokyo-alb-sg"
  description = "Security group for Tokyo Load Balancer"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "tokyo-alb-sg"
    Region  = "Tokyo"
    Service = "LoadBalancer"
  }
}

# Tokyo EC2 Application Security Group
resource "aws_security_group" "tokyo_ec2_app_sg" {
  name        = "tokyo-ec2-app-sg"
  description = "Security group for Tokyo EC2 application instances"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  ingress {
    description     = "HTTP from load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.tokyo_alb_sg.id]
  }

  ingress {
    description = "SSH from admin"
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
    Name    = "tokyo-ec2-app-sg"
    Region  = "Tokyo"
    Service = "Application"
  }
}

# Tokyo RDS Database Security Group (SECURE - Tokyo only)
resource "aws_security_group" "taaops_rds_sg" {
  name        = "tokyo-rds-sg"
  description = "Security group for Database instances - Tokyo region only"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  ingress {
    description     = "MySQL from Tokyo app servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.tokyo_ec2_app_sg.id]
  }

  ingress {
    description     = "MySQL from São Paulo compute (via TGW)"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sao_ec2_app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "tokyo-rds-sg"
    Region   = "Tokyo"
    Service  = "Database"
    Security = "Restricted"
  }
}

# Tokyo Lambda Security Group
resource "aws_security_group" "tokyo_lambda_sg" {
  name        = "tokyo-lambda-sg"
  description = "Security group for Tokyo Lambda functions"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "tokyo-lambda-sg"
    Region  = "Tokyo"
    Service = "Lambda"
  }
}

# Tokyo VPC Endpoints Security Group
resource "aws_security_group" "tokyo_endpoints_sg" {
  name        = "tokyo-endpoints-sg"
  description = "Security group for Tokyo VPC endpoints"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  ingress {
    description = "HTTPS from Tokyo VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.tokyo_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "tokyo-endpoints-sg"
    Region  = "Tokyo"
    Service = "VPCEndpoints"
  }
}

########################## SAO PAULO REGION SECURITY GROUPS ##########################

# São Paulo Load Balancer Security Group
resource "aws_security_group" "sao_alb_sg" {
  provider    = aws.saopaulo
  name        = "sao-alb-sg"
  description = "Security group for São Paulo Load Balancer"
  vpc_id      = aws_vpc.liberdade_vpc01.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "sao-alb-sg"
    Region  = "SaoPaulo"
    Service = "LoadBalancer"
  }
}

# São Paulo EC2 Application Security Group
resource "aws_security_group" "sao_ec2_app_sg" {
  provider    = aws.saopaulo
  name        = "sao-ec2-app-sg"
  description = "Security group for São Paulo EC2 compute instances"
  vpc_id      = aws_vpc.liberdade_vpc01.id

  ingress {
    description     = "HTTP from load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.sao_alb_sg.id]
  }

  ingress {
    description = "SSH from admin"
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
    Name    = "sao-ec2-app-sg"
    Region  = "SaoPaulo"
    Service = "Compute"
    Note    = "DatabaseAccessViaTokyoTGW"
  }
}

# São Paulo Lambda Security Group
resource "aws_security_group" "sao_lambda_sg" {
  provider    = aws.saopaulo
  name        = "sao-lambda-sg"
  description = "Security group for São Paulo Lambda functions"
  vpc_id      = aws_vpc.liberdade_vpc01.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "sao-lambda-sg"
    Region  = "SaoPaulo"
    Service = "Lambda"
  }
}

# São Paulo VPC Endpoints Security Group
resource "aws_security_group" "sao_endpoints_sg" {
  provider    = aws.saopaulo
  name        = "sao-endpoints-sg"
  description = "Security group for Sao Paulo VPC endpoints"
  vpc_id      = aws_vpc.liberdade_vpc01.id

  ingress {
    description = "HTTPS from Sao Paulo VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.saopaulo_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "sao-endpoints-sg"
    Region  = "SaoPaulo"
    Service = "VPCEndpoints"
  }
}

########################## CROSS-REGION DATABASE ACCESS RULE ##########################

# Allow São Paulo VPC CIDR to access Tokyo database via Transit Gateway
resource "aws_security_group_rule" "taaops_rds_ingress_from_sao_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.taaops_rds_sg.id
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [var.saopaulo_vpc_cidr]

  description = "MySQL access from Sao Paulo VPC via Transit Gateway"
}