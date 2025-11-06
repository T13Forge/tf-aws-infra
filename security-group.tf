#--------------------
# Load Balancer SG
#--------------------
resource "aws_security_group" "lb_sg" {
  name   = "${var.name_prefix}-lb-sg"
  vpc_id = aws_vpc.csye6225.id
}

locals {
  lb_ingress_ports = [80, 443]
}

resource "aws_vpc_security_group_ingress_rule" "lb_ingress_ipv4" {
  for_each          = toset([for p in local.lb_ingress_ports : tostring(p)])
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  ip_protocol       = "tcp"
  description       = "Allow TCP ${each.value} from anywhere (IPv4)"
}

resource "aws_vpc_security_group_egress_rule" "lb_all_out" {
  security_group_id = aws_security_group.lb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

#----------------------
# Web App SG
#----------------------
resource "aws_security_group" "app_sg" {
  name   = "${var.name_prefix}-app-sg"
  vpc_id = aws_vpc.csye6225.id

  tags = { Name = "${var.name_prefix}-app-sg" }
}

# Allow application traffic from ALB only
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app_sg.id
  referenced_security_group_id = aws_security_group.lb_sg.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  description                  = "Allow inbound traffic on app port from ALB Security Group"
}

# Allow SSH access from your local public IP (for admin access)
#    To find your IP, search "what is my IP" on Google and append /32 (e.g., 35.27.81.142/32)
resource "aws_vpc_security_group_ingress_rule" "app_ssh_admin" {
  count             = var.enable_ssh ? 1 : 0
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = var.my_ip_cidr # e.g., "35.27.81.142/32", /32 means only this ip wouldb be allowed
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "Allow SSH access only from your local public IP"
}

# Allow all outbound traffic (so EC2 can reach the Internet and AWS services)
resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

#----------------------
# DB Security Group
#----------------------
resource "aws_security_group" "db_sg" {
  name        = "${var.name_prefix}-db-sg"
  description = "Database Security Group: only allow access from EC2 app_sg"
  vpc_id      = aws_vpc.csye6225.id

  tags = { Name = "${var.name_prefix}-db-sg" }
}

# Allow inbound DB access from app_sg
resource "aws_vpc_security_group_ingress_rule" "db_ingress_app_sg" {
  security_group_id            = aws_security_group.db_sg.id # apply to what sg
  referenced_security_group_id = aws_security_group.app_sg.id
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  description                  = "Allow DB ${var.db_port} from app_sg only"
}

# Allow outbound (for updates / AWS services)
resource "aws_vpc_security_group_egress_rule" "db_all_out_ipv4" {
  security_group_id = aws_security_group.db_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

