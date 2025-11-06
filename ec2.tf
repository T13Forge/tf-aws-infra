locals {
  az_to_public_subnet_id = {
    for az, s in aws_subnet.public :
    az => s.id
  }

  az_to_private_subnet_id = {
    for az, s in aws_subnet.private :
    az => s.id
  }

  default_az = sort(keys(local.az_to_public_subnet_id))[0]
  chosen_az  = coalesce(var.target_az, local.default_az)

  chosen_subnet_id = (var.subnet_tier == "public"
    ? lookup(local.az_to_public_subnet_id, local.chosen_az, null)
    : lookup(local.az_to_private_subnet_id, local.chosen_az, null)
  )
}

# Only if you want to create an isolated EC2 not part of ASG to use this
resource "aws_instance" "app" {
  count                  = var.create_ec2_instance ? 1 : 0
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.chosen_subnet_id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.app_ec2_profile.name

  # assign ssh key
  key_name = var.key_name != "" ? var.key_name : null

  # Do NOT protect from accidental termination
  disable_api_termination = false

  # Root volume requirements
  root_block_device {
    volume_type           = "gp2"
    volume_size           = 25
    delete_on_termination = true
  }

  # ensure a public IP if your subnet doesn't auto-assign
  associate_public_ip_address = var.subnet_tier == "public" ? true : false

  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    app_user     = var.app_user
    app_group    = var.app_group
    app_dir      = var.app_dir
    service_name = var.service_name

    db_host     = aws_db_instance.db.address
    db_port     = aws_db_instance.db.port
    db_name     = var.db_name
    db_username = var.db_username
    db_password = random_password.rds.result

    aws_region = var.region
    s3_bucket  = aws_s3_bucket.images.bucket
  })

  tags = {
    Name = "${var.name_prefix}-ec2"
    Role = "webapp"
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

    aws_region = var.region
    s3_bucket  = aws_s3_bucket.images.bucket
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
  min_size            = 3
  max_size            = 5
  desired_capacity    = 3
  vpc_zone_identifier = values(local.az_to_public_subnet_id)
  health_check_type   = "ELB"

  # Time (in seconds) to wait after a new instance launches
  # before starting health checks — allows the app to fully start up.
  health_check_grace_period = 60

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
