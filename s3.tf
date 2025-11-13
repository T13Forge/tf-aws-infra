resource "aws_s3_bucket" "images" {
  bucket        = "${var.name_prefix}-${random_uuid.s3_suffix.result}"
  force_destroy = true

  tags = {
    Name = "${var.name_prefix}-s3"
  }
}

resource "random_uuid" "s3_suffix" {}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      # Use AWS KMS for server-side encryption instead of S3-managed AES256
      sse_algorithm = "aws:kms"

      # Encrypt objects with our customer-managed KMS key dedicated for S3.
      kms_master_key_id = aws_kms_alias.s3_key_alias.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "transition-standard-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}
