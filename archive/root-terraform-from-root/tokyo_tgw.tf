# AWS Transit Gateway Inter-Region Peering Configuration
# This implements secure connectivity between Tokyo (Data Authority) and São Paulo (Compute Region)
# Database remains securely in Tokyo, while compute resources can be distributed

########################## TOKYO TRANSIT GATEWAY ##########################

# Tokyo Transit Gateway - Main hub where secure data resides
resource "aws_ec2_transit_gateway" "shinjuku_tgw01" {
  description                     = "Tokyo Transit Gateway - Data Authority Hub"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name    = "shinjuku-tgw01"
    Region  = "Tokyo"
    Purpose = "Data Authority Hub"
  }
}

# Tokyo VPC attachment to Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "tokyo_vpc_attachment" {
  subnet_ids         = [aws_subnet.tokyo_tgw_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  vpc_id             = aws_vpc.shinjuku_vpc01.id

  tags = {
    Name = "tokyo-vpc-attachment"
  }
}

########################## SAO PAULO TRANSIT GATEWAY ##########################

# São Paulo Transit Gateway - Spoke for distributed compute
resource "aws_ec2_transit_gateway" "liberdade_tgw01" {
  provider                        = aws.saopaulo
  description                     = "São Paulo Transit Gateway - Compute Spoke"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name    = "liberdade-tgw01"
    Region  = "SaoPaulo"
    Purpose = "Compute Spoke"
  }
}

# São Paulo VPC attachment to Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "sao_vpc_attachment" {
  provider           = aws.saopaulo
  subnet_ids         = [aws_subnet.sao_tgw_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  vpc_id             = aws_vpc.liberdade_vpc01.id

  tags = {
    Name = "sao-vpc-attachment"
  }
}

########################## INTER-REGION PEERING ##########################

# Tokyo to São Paulo peering connection (Tokyo initiates)
resource "aws_ec2_transit_gateway_peering_attachment" "tokyo_to_sao_peering" {
  transit_gateway_id      = aws_ec2_transit_gateway.shinjuku_tgw01.id
  peer_transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  peer_region             = "sa-east-1"

  tags = {
    Name = "tokyo-to-sao-peering"
    Side = "Requester"
  }
}

# São Paulo accepts the peering connection
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "sao_accept_peering" {
  provider                      = aws.saopaulo
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.tokyo_to_sao_peering.id

  tags = {
    Name = "sao-accept-peering"
    Side = "Accepter"
  }
}

########################## ROUTING CONFIGURATION ##########################

# Tokyo route table for São Paulo traffic
resource "aws_route" "tokyo_to_sao_route" {
  route_table_id                = aws_ec2_transit_gateway.shinjuku_tgw01.association_default_route_table_id
  destination_cidr_block        = var.saopaulo_vpc_cidr
  transit_gateway_id            = aws_ec2_transit_gateway.shinjuku_tgw01.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.sao_accept_peering]
}

# São Paulo route table for Tokyo traffic  
resource "aws_route" "sao_to_tokyo_route" {
  provider                      = aws.saopaulo
  route_table_id                = aws_ec2_transit_gateway.liberdade_tgw01.association_default_route_table_id
  destination_cidr_block        = var.tokyo_vpc_cidr
  transit_gateway_id            = aws_ec2_transit_gateway.liberdade_tgw01.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.sao_accept_peering]
}