# Internet Gateway and NAT Gateway Configuration for Multi-Region Setup

########################## TOKYO REGION GATEWAYS ##########################

# Tokyo Internet Gateway
resource "aws_internet_gateway" "tokyo_igw01" {
  vpc_id = aws_vpc.shinjuku_vpc01.id

  tags = {
    Name   = "${local.name_prefix}-tokyo-igw01"
    Region = "Tokyo"
  }
}

# Tokyo EIP for NAT Gateway
resource "aws_eip" "tokyo_nat_eip" {
  domain = "vpc"
  tags = {
    Name   = "tokyo-nat-eip"
    Region = "Tokyo"
  }
}

# Tokyo NAT Gateway (in first public subnet)
resource "aws_nat_gateway" "tokyo_regional_nat_gw" {
  allocation_id = aws_eip.tokyo_nat_eip.id
  subnet_id     = aws_subnet.tokyo_subnet_public_a.id
  tags = {
    Name   = "tokyo-regional-nat-gw"
    Region = "Tokyo"
  }
  depends_on = [aws_internet_gateway.tokyo_igw01]
}

########################## SAO PAULO REGION GATEWAYS ##########################

# São Paulo Internet Gateway
resource "aws_internet_gateway" "sao_igw01" {
  provider = aws.saopaulo
  vpc_id   = aws_vpc.liberdade_vpc01.id

  tags = {
    Name   = "${local.name_prefix}-sao-igw01"
    Region = "SaoPaulo"
  }
}

# São Paulo EIP for NAT Gateway  
resource "aws_eip" "sao_nat_eip" {
  provider = aws.saopaulo
  domain   = "vpc"
  tags = {
    Name   = "sao-nat-eip"
    Region = "SaoPaulo"
  }
}

# São Paulo NAT Gateway (in first public subnet)
resource "aws_nat_gateway" "sao_regional_nat_gw" {
  provider      = aws.saopaulo
  allocation_id = aws_eip.sao_nat_eip.id
  subnet_id     = aws_subnet.sao_subnet_public_a.id
  tags = {
    Name   = "sao-regional-nat-gw"
    Region = "SaoPaulo"
  }
  depends_on = [aws_internet_gateway.sao_igw01]
}