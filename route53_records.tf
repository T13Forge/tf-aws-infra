# Decide at plan time if we create DNS (e.g., public subnet envs)
variable "create_dns_record" {
  type        = bool
  description = "Whether to create the Route53 A record for the app."
  default     = true
}

data "aws_route53_zone" "env" {
  name         = var.route53_zone_name
  private_zone = false
}

# Safety check — only create the record if an IP is found
resource "aws_route53_record" "env_apex_a" {
  count = var.create_dns_record != "" ? 1 : 0

  zone_id = data.aws_route53_zone.env.zone_id
  name    = var.record_name
  type    = "A"
  ttl     = var.record_ttl
  records = [aws_instance.app.public_ip]

  allow_overwrite = true
}
