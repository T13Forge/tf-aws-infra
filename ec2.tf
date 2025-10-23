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

resource "aws_instance" "app" {
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
    db_password = var.db_password
  })

  tags = {
    Name = "${var.name_prefix}-ec2"
    Role = "webapp"
  }
}
