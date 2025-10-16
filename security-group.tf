resource "aws_security_group" "app_sg" {
  name        = "${var.name_prefix}-sg"
  description = "Web App SG: 22,80,443,app open to world"
  vpc_id      = aws_vpc.csye6225.id

  tags = { Name = "${var.name_prefix}-sg" }
}

locals {
  app_ingress_ports = ["22", 80, 443, var.app_port]
}

resource "aws_vpc_security_group_ingress_rule" "ipv4" {
  for_each          = toset([for p in local.app_ingress_ports : tostring(p)])
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  ip_protocol       = "tcp"
  description       = "Allow TCP ${each.value} from anywhere (IPv4)"
}

resource "aws_vpc_security_group_ingress_rule" "ipv6" {
  for_each          = var.enable_ipv6 ? toset([for p in local.app_ingress_ports : tostring(p)]) : toset([])
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv6         = "::/0"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  ip_protocol       = "tcp"
  description       = "Allow TCP ${each.value} from anywhere (IPv6)"
}

# Egress (allow all traffic)
resource "aws_vpc_security_group_egress_rule" "all_out_ipv4" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_vpc_security_group_egress_rule" "all_out_ipv6" {
  count             = var.enable_ipv6 ? 1 : 0
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}
