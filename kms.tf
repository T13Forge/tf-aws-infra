# EBS
resource "aws_kms_key" "ec2_key" {
  description             = "Customer managed KMS key for EC2 EBS volume encryption"
  enable_key_rotation     = true # AWS rotates the key automatically
  rotation_period_in_days = 90

  tags = {
    Name = "${var.name_prefix}-kms-ec2"
  }
}

resource "aws_kms_alias" "ec2_key_alias" {
  name          = "alias/${var.name_prefix}-ec2-kms"
  target_key_id = aws_kms_key.ec2_key.key_id
}

# RDS
resource "aws_kms_key" "rds_key" {
  description             = "Customer managed KMS key for RDS instance encryption"
  enable_key_rotation     = true # AWS rotates the key automatically
  rotation_period_in_days = 90

  tags = {
    Name = "${var.name_prefix}-kms-rds"
  }
}

# KMS alias provide a stable and permanent identifier for the key
# The KMS key itself will rotate over time (new key versions are created during rotation),
# which means the key ARN changes. By using an alias, AWS automatically points the alias
# to the newest key version, ensuring that all encrypted resources continue to work without
resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/${var.name_prefix}-rds-kms"
  target_key_id = aws_kms_key.rds_key.key_id
}

# S3 bucket
resource "aws_kms_key" "s3_key" {
  description             = "Customer managed KMS key for S3 object encryption"
  enable_key_rotation     = true # AWS rotates the key automatically
  rotation_period_in_days = 90

  tags = {
    Name = "${var.name_prefix}-kms-s3"
  }
}

resource "aws_kms_alias" "s3_key_alias" {
  name          = "alias/${var.name_prefix}-s3-kms"
  target_key_id = aws_kms_key.s3_key.key_id
}

resource "aws_kms_key" "secrets_key" {
  description         = "Customer managed KMS key for Secrets Manager (DB + email secrets)"
  enable_key_rotation = true

  tags = {
    Name = "${var.name_prefix}-kms-secrets"
  }
}

resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/${var.name_prefix}-secrets-kms"
  target_key_id = aws_kms_key.secrets_key.key_id
}
