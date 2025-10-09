output "vpc_id" {
  value = aws_vpc.csye6225.id
}

output "public_subnets" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnets" {
  value = [for s in aws_subnet.private : s.id]
}

output "igw_id" {
  value = aws_internet_gateway.csye6225.id
}

output "route_tables" {
  value = {
    public  = aws_route_table.public.id
    private = aws_route_table.private.id
  }
}
