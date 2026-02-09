# Route Tables Configuration for Multi-Region Setup with Transit Gateway

########################## TOKYO REGION ROUTING ##########################

# Tokyo Public Route Table
resource "aws_route_table" "tokyo_public_rt" {
  vpc_id = aws_vpc.shinjuku_vpc01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tokyo_igw01.id
  }

  # Route to São Paulo via Transit Gateway
  route {
    cidr_block         = var.saopaulo_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  }

  tags = {
    Name   = "${local.name_prefix}-tokyo-public-rt"
    Region = "Tokyo"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tokyo_vpc_attachment,
    aws_ec2_transit_gateway_peering_attachment_accepter.sao_accept_peering
  ]
}

# Tokyo Private Route Table  
resource "aws_route_table" "tokyo_private_rt" {
  vpc_id = aws_vpc.shinjuku_vpc01.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.tokyo_regional_nat_gw.id
  }

  # Route to São Paulo via Transit Gateway
  route {
    cidr_block         = var.saopaulo_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  }

  tags = {
    Name   = "${local.name_prefix}-tokyo-private-rt"
    Region = "Tokyo"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.tokyo_vpc_attachment,
    aws_ec2_transit_gateway_peering_attachment_accepter.sao_accept_peering
  ]
}

# Tokyo Public Subnet Associations
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

# Tokyo Private Subnet Associations
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

########################## SAO PAULO REGION ROUTING ##########################

# São Paulo Public Route Table
resource "aws_route_table" "sao_public_rt" {
  provider = aws.saopaulo
  vpc_id   = aws_vpc.liberdade_vpc01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sao_igw01.id
  }

  # Route to Tokyo via Transit Gateway
  route {
    cidr_block         = var.tokyo_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  }

  tags = {
    Name   = "${local.name_prefix}-sao-public-rt"
    Region = "SaoPaulo"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.sao_vpc_attachment,
    aws_ec2_transit_gateway_peering_attachment_accepter.sao_accept_peering
  ]
}

# São Paulo Private Route Table
resource "aws_route_table" "sao_private_rt" {
  provider = aws.saopaulo
  vpc_id   = aws_vpc.liberdade_vpc01.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.sao_regional_nat_gw.id
  }

  # Route to Tokyo via Transit Gateway
  route {
    cidr_block         = var.tokyo_vpc_cidr
    transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  }

  tags = {
    Name   = "${local.name_prefix}-sao-private-rt"
    Region = "SaoPaulo"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.sao_vpc_attachment,
    aws_ec2_transit_gateway_peering_attachment_accepter.sao_accept_peering
  ]
}

# São Paulo Public Subnet Associations
resource "aws_route_table_association" "sao_public_rt_assoc_a" {
  provider       = aws.saopaulo
  subnet_id      = aws_subnet.sao_subnet_public_a.id
  route_table_id = aws_route_table.sao_public_rt.id
}

resource "aws_route_table_association" "sao_public_rt_assoc_b" {
  provider       = aws.saopaulo
  subnet_id      = aws_subnet.sao_subnet_public_b.id
  route_table_id = aws_route_table.sao_public_rt.id
}

resource "aws_route_table_association" "sao_public_rt_assoc_c" {
  provider       = aws.saopaulo
  subnet_id      = aws_subnet.sao_subnet_public_c.id
  route_table_id = aws_route_table.sao_public_rt.id
}

# São Paulo Private Subnet Associations
resource "aws_route_table_association" "sao_private_rt_assoc_a" {
  provider       = aws.saopaulo
  subnet_id      = aws_subnet.sao_subnet_private_a.id
  route_table_id = aws_route_table.sao_private_rt.id
}

resource "aws_route_table_association" "sao_private_rt_assoc_b" {
  provider       = aws.saopaulo
  subnet_id      = aws_subnet.sao_subnet_private_b.id
  route_table_id = aws_route_table.sao_private_rt.id
}

resource "aws_route_table_association" "sao_private_rt_assoc_c" {
  provider       = aws.saopaulo
  subnet_id      = aws_subnet.sao_subnet_private_c.id
  route_table_id = aws_route_table.sao_private_rt.id
}