# VPC Endpoints for SSM and CloudWatch Logs (private subnets)

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

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.shinjuku_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]

  security_group_ids = [aws_security_group.tokyo_endpoints_sg.id]

  tags = {
    Name = "tokyo-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.shinjuku_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]

  security_group_ids = [aws_security_group.tokyo_endpoints_sg.id]

  tags = {
    Name = "tokyo-ec2messages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.shinjuku_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]

  security_group_ids = [aws_security_group.tokyo_endpoints_sg.id]

  tags = {
    Name = "tokyo-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "tokyo_logs" {
  vpc_id              = aws_vpc.shinjuku_vpc01.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.tokyo_subnet_private_a.id,
    aws_subnet.tokyo_subnet_private_b.id,
    aws_subnet.tokyo_subnet_private_c.id
  ]

  security_group_ids = [aws_security_group.tokyo_endpoints_sg.id]

  tags = {
    Name = "tokyo-logs-endpoint"
  }
}
