# Explanation: Liberdade knows the way to Shinjuku—Tokyo CIDR routes go through the TGW corridor.
resource "aws_route" "liberdade_to_tokyo_route01" {
  provider               = aws.saopaulo
  route_table_id         = aws_route_table.sao_private_rt.id
  destination_cidr_block = var.tokyo_vpc_cidr # Tokyo VPC CIDR (students supply)
  transit_gateway_id     = aws_ec2_transit_gateway.liberdade_tgw01.id
}


# Explanation: Shinjuku returns traffic to Liberdade—because doctors need answers, not one-way tunnels.
resource "aws_route" "shinjuku_to_sp_route01" {
  route_table_id         = aws_route_table.tokyo_private_rt.id
  destination_cidr_block = var.saopaulo_vpc_cidr # Sao Paulo VPC CIDR (students supply)
  transit_gateway_id     = aws_ec2_transit_gateway.shinjuku_tgw01.id
}
