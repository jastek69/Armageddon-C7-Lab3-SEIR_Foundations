resource "aws_vpc" "shinjuku_vpc01" { # VPC ID: aws_vpc.TOKYO_VPC.id  
  cidr_block           = var.tokyo_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc01"
  }
}


resource "aws_vpc" "liberdade_vpc01" { # VPC ID: aws_vpc.TOKYO_VPC.id  
  provider             = aws.saopaulo
  cidr_block           = var.saopaulo_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc01"
  }
}
