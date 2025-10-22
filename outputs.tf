output "current_workspace" {
  value = terraform.workspace
}

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

output "chosen_subnet_id" {
  value = local.chosen_subnet_id
}

output "chosen_az" {
  value = local.chosen_az
}

output "application_sg_id" {
  value = aws_security_group.app_sg.id
}

output "instance_id" {
  value = aws_instance.app.public_ip
}

output "rds_endpoint" {
  description = "RDS endpoint hostname"
  value = aws_db_instance.db.address
}

output "rds_port" {
  value = aws_db_instance.db.port
}
