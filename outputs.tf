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

output "application_sg_id" {
  value = aws_security_group.app_sg.id
}

output "rds_endpoint" {
  description = "RDS endpoint hostname"
  value       = aws_db_instance.db.address
}

output "rds_port" {
  value = aws_db_instance.db.port
}

# ----- External entry points -----
output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

# fqdn stands for "Fully Qualified Domain Name"
output "app_url" {
  description = "Your app URL via Route 53 (HTTP)"
  value       = "http://${aws_route53_record.app_apex.fqdn}"
}

# ----- Load Balancing & Targeting -----
output "target_group_arn" {
  description = "ARN of the Target Group used by the ALB"
  value       = aws_lb_target_group.app_tg.arn
}

output "health_check_path" {
  description = "Health check path used by the Target Group"
  value       = var.health_check_path
}

# ----- Autoscaling state -----
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app_asg.name
}

output "asg_capacity" {
  description = "ASG capacity targets (min / desired / max)"
  value = {
    min     = aws_autoscaling_group.app_asg.min_size
    desired = aws_autoscaling_group.app_asg.desired_capacity
    max     = aws_autoscaling_group.app_asg.max_size
  }
}

# ----- Launch template (blueprint) -----
output "launch_template_id" {
  description = "ID of the Launch Template used by ASG"
  value       = aws_launch_template.app.id
}

output "launch_template_versions" {
  description = "Default and latest Launch Template versions"
  value = {
    default = aws_launch_template.app.default_version
    latest  = aws_launch_template.app.latest_version
  }
}

# ----- Security boundaries -----
output "security_group_ids" {
  description = "Security Groups used by ALB and App"
  value = {
    alb_sg = aws_security_group.lb_sg.id
    app_sg = aws_security_group.app_sg.id
    db_sg  = aws_security_group.db_sg.id
  }
}

# ----- DNS / Hosted Zone context -----
output "hosted_zone_id" {
  description = "Hosted zone ID used for the app apex record"
  value       = data.aws_route53_zone.env.zone_id
}

# ----- Scaling signals (useful for verification) -----
output "cloudwatch_alarms" {
  description = "CloudWatch alarms that drive scale in/out"
  value = {
    cpu_high = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
    cpu_low  = aws_cloudwatch_metric_alarm.cpu_low.alarm_name
  }
}
