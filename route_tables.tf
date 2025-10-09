# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.csye6225.id

  tags = merge(var.tags, {
    Name = "rt-public-${var.vpc_name}"
  })
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.csye6225.id

  tags = merge(var.tags, {
    Name = "rt-private-${var.vpc_name}"
  })
}

# Public route: 0.0.0.0/0 → IGW
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.csye6225.id
}

# Associate public subnets with public RT
resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  route_table_id = aws_route_table.private.id
  subnet_id      = each.value.id
}
