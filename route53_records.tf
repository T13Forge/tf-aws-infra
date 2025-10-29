data "aws_route53_zone" "env" {
  name         = var.route53_zone_name
  private_zone = false
}

# Safety check — only create the record if an IP is found
resource "aws_route53_record" "env_apex_a" {
  count = aws_instance.app.public_ip != "" ? 1 : 0

  zone_id = data.aws_route53_zone.env.zone_id
  name    = var.record_name
  type    = "A"
  ttl     = var.record_ttl
  records = aws_instance.app.public_ip

  allow_overwrite = true
}
