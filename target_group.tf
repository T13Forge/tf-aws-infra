resource "aws_lb_target_group" "app_tg" {
  name        = "${var.name_prefix}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.csye6225.id
  target_type = "instance"

  # TG will periodically send requests to this API endpoint to verify
  # whether each EC2 instance is healthy. Only healthy instances will
  # continue receiving traffic from the ALB.
  health_check {
    path                = var.health_check_path # e.g. "/healthz"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }
}
