resource "aws_db_parameter_group" "postgres" {
  name        = "${var.name_prefix}-pg-param"
  family      = var.db_engine_family
  description = "Custom parameter group for PostgreSQL ${var.db_engine_version}"

  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }
}

resource "aws_db_subnet_group" "db_private" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id] # multiple subnet (at least 2)
  tags = {
    Name = "${var.name_prefix}-db-subnet-group"
  }
}

# Generate a secure random pwd for RDS
resource "random_password" "rds" {
  length           = 16
  special          = true
  override_special = "!#$%&'()*+,-.:;<=>?[]^_{|}~"
}

resource "aws_secretsmanager_secret" "rds" {
  name        = "${var.name_prefix}-rds-master-strong-password"
  description = "Master password for the ${var.name_prefix} RDS instance"

  # Use a customer-managed KMS key (CMK) to encrypt the secret.
  kms_key_id = aws_kms_alias.secrets_key_alias.arn

  # Set the recovery window to 0 days so the secret is deleted immediately
  # when destroyed by Terraform, instead of waiting for the default 30-day recovery period.
  recovery_window_in_days = 0
}

# Store the generated pwd in AWS Secrets Manager
resource "aws_secretsmanager_secret_version" "rds" {
  secret_id     = aws_secretsmanager_secret.rds.id
  secret_string = random_password.rds.result
}

# RDS Instance
resource "aws_db_instance" "db" {
  identifier        = "${var.name_prefix}-rds"
  engine            = "postgres"
  engine_version    = var.db_engine_version    # e.g., "16.3"
  instance_class    = var.db_instance_class    # e.g., "db.t3.micro"
  allocated_storage = var.db_allocated_storage # e.g., 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.rds.result # <-- use generated pwd

  port                = var.db_port # 5432
  multi_az            = false
  publicly_accessible = false

  # Enable encryption at rest for the database storage
  storage_encrypted = true

  # Use the customer-managed KMS key dedicated for RDS encryption
  kms_key_id = aws_kms_key.rds_key.arn

  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_private.name
  parameter_group_name   = aws_db_parameter_group.postgres.name

  skip_final_snapshot = true

  tags = {
    Name = "${var.name_prefix}-rds-postgres"
  }

  depends_on = [
    aws_db_subnet_group.db_private,
    aws_db_parameter_group.postgres,
    aws_security_group.db_sg
  ]
}
