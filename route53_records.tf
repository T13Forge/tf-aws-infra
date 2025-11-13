data "aws_route53_zone" "env" {
  name         = var.domain_name
  private_zone = false
}

# Create an A Record (Alias) in Route 53 to map your domain to the ALB.
# This allows external traffic to be routed to the ALB automatically. 
resource "aws_route53_record" "app_apex" {
  zone_id = data.aws_route53_zone.env.zone_id
  name    = data.aws_route53_zone.env.name # e.g. "dev.isaactai.me"
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}
