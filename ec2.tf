locals {
  az_to_public_subnet_id = {
    for az, s in aws_subnet.public :
    az => s.id
  }
}

# ------------------
# Lunch Templates
# ------------------
resource "aws_launch_template" "app" {
  name          = var.template_name
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.app_ec2_profile.name
  }

  network_interfaces {
    security_groups = [aws_security_group.app_sg.id]

    # Now I put it on public subnet to have internet
    # so that EC2 can install updates before I create NAT Gateway.
    associate_public_ip_address = true
  }

  # Encrypt the root EBS volume with KMS key
  block_device_mappings {
    device_name = "/dev/xvda" # Root volume device name (varies by AMI)

    ebs {
      volume_size = 20 # or var.root_volume_size if you have one
      volume_type = "gp3"
      encrypted   = true

      # Use the customer-managed KMS key dedicated for EC2 EBS encryption.
      kms_key_id = aws_kms_alias.ec2_key_alias.arn
    }
  }

  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    app_user     = var.app_user
    app_group    = var.app_group
    app_dir      = var.app_dir
    service_name = var.service_name

    db_host     = aws_db_instance.db.address
    db_port     = aws_db_instance.db.port
    db_name     = var.db_name
    db_username = var.db_username
    db_password = random_password.rds.result

    aws_region    = var.region
    s3_bucket     = aws_s3_bucket.images.bucket
    sns_topic_arn = aws_sns_topic.user_signup.arn
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name_prefix}-app" }
  }
}

# ------------------
# Auto Scaling Group
# ------------------
resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.name_prefix}-asg"
  min_size            = 1
  max_size            = 2
  desired_capacity    = 2
  vpc_zone_identifier = values(local.az_to_public_subnet_id)
  health_check_type   = "ELB"

  # Time (in seconds) to wait after a new instance launches
  # before starting health checks — allows the app to fully start up.
  # Increased to 300 seconds (5 minutes) to allow:
  # - EC2 instance to fully boot
  # - User data script to complete
  # - Application service to start and connect to database
  # - Application to be ready to accept HTTP requests
  health_check_grace_period = 300

  default_cooldown = 60

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-webapp"
    propagate_at_launch = true
  }
}
