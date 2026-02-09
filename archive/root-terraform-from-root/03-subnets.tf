########################## TOKYO REGION SUBNETS ##########################

# Tokyo Public Subnets
resource "aws_subnet" "tokyo_subnet_public_a" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_public_cidrs[0]
  availability_zone       = var.tokyo_azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name   = "${local.name_prefix}-tokyo-public-subnet-a"
    Region = "Tokyo"
    Type   = "Public"
  }
}

resource "aws_subnet" "tokyo_subnet_public_b" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_public_cidrs[1]
  availability_zone       = var.tokyo_azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name   = "${local.name_prefix}-tokyo-public-subnet-b"
    Region = "Tokyo"
    Type   = "Public"
  }
}

resource "aws_subnet" "tokyo_subnet_public_c" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_public_cidrs[2]
  availability_zone       = var.tokyo_azs[2]
  map_public_ip_on_launch = true

  tags = {
    Name   = "${local.name_prefix}-tokyo-public-subnet-c"
    Region = "Tokyo"
    Type   = "Public"
  }
}

# Tokyo Private Subnets
resource "aws_subnet" "tokyo_subnet_private_a" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_private_cidrs[0]
  availability_zone       = var.tokyo_azs[0]
  map_public_ip_on_launch = false

  tags = {
    Name   = "${local.name_prefix}-tokyo-private-subnet-a"
    Region = "Tokyo"
    Type   = "Private"
  }
}

resource "aws_subnet" "tokyo_subnet_private_b" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_private_cidrs[1]
  availability_zone       = var.tokyo_azs[1]
  map_public_ip_on_launch = false

  tags = {
    Name   = "${local.name_prefix}-tokyo-private-subnet-b"
    Region = "Tokyo"
    Type   = "Private"
  }
}

resource "aws_subnet" "tokyo_subnet_private_c" {
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.tokyo_subnet_private_cidrs[2]
  availability_zone       = var.tokyo_azs[2]
  map_public_ip_on_launch = false

  tags = {
    Name   = "${local.name_prefix}-tokyo-private-subnet-c"
    Region = "Tokyo"
    Type   = "Private"
  }
}

########################## SAO PAULO REGION SUBNETS ##########################

# Sao Paulo Public Subnets
resource "aws_subnet" "sao_subnet_public_a" {
  provider                = aws.saopaulo
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_public_cidrs[0]
  availability_zone       = var.sao_azs[0]
  map_public_ip_on_launch = true

  tags = {
    Name   = "${local.name_prefix}-sao-public-subnet-a"
    Region = "SaoPaulo"
    Type   = "Public"
  }
}

resource "aws_subnet" "sao_subnet_public_b" {
  provider                = aws.saopaulo
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_public_cidrs[1]
  availability_zone       = var.sao_azs[1]
  map_public_ip_on_launch = true

  tags = {
    Name   = "${local.name_prefix}-sao-public-subnet-b"
    Region = "SaoPaulo"
    Type   = "Public"
  }
}

resource "aws_subnet" "sao_subnet_public_c" {
  provider                = aws.saopaulo
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_public_cidrs[2]
  availability_zone       = var.sao_azs[2]
  map_public_ip_on_launch = true

  tags = {
    Name   = "${local.name_prefix}-sao-public-subnet-c"
    Region = "SaoPaulo"
    Type   = "Public"
  }
}

# Sao Paulo Private Subnets
resource "aws_subnet" "sao_subnet_private_a" {
  provider                = aws.saopaulo
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_private_cidrs[0]
  availability_zone       = var.sao_azs[0]
  map_public_ip_on_launch = false

  tags = {
    Name   = "${local.name_prefix}-sao-private-subnet-a"
    Region = "SaoPaulo"
    Type   = "Private"
  }
}

resource "aws_subnet" "sao_subnet_private_b" {
  provider                = aws.saopaulo
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_private_cidrs[1]
  availability_zone       = var.sao_azs[1]
  map_public_ip_on_launch = false

  tags = {
    Name   = "${local.name_prefix}-sao-private-subnet-b"
    Region = "SaoPaulo"
    Type   = "Private"
  }
}

resource "aws_subnet" "sao_subnet_private_c" {
  provider                = aws.saopaulo
  vpc_id                  = aws_vpc.liberdade_vpc01.id
  cidr_block              = var.sao_subnet_private_cidrs[2]
  availability_zone       = var.sao_azs[2]
  map_public_ip_on_launch = false

  tags = {
    Name   = "${local.name_prefix}-sao-private-subnet-c"
    Region = "SaoPaulo"
    Type   = "Private"
  }
}

# Transit Gateway Subnets (smaller CIDR for TGW attachments)
resource "aws_subnet" "tokyo_tgw_subnet" {
  vpc_id            = aws_vpc.shinjuku_vpc01.id
  cidr_block        = "10.233.100.0/28" # Small CIDR for TGW
  availability_zone = var.tokyo_azs[0]

  tags = {
    Name = "${local.name_prefix}-tokyo-tgw-subnet"
    Type = "TransitGateway"
  }
}

resource "aws_subnet" "sao_tgw_subnet" {
  provider          = aws.saopaulo
  vpc_id            = aws_vpc.liberdade_vpc01.id
  cidr_block        = "10.234.100.0/28" # Small CIDR for TGW
  availability_zone = var.sao_azs[0]

  tags = {
    Name = "${local.name_prefix}-sao-tgw-subnet"
    Type = "TransitGateway"
  }
}