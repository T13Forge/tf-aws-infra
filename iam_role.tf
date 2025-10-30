resource "aws_iam_role" "app_ec2_role" {
  name = "${var.name_prefix}-ec2-role"

  # Trust Policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }, # Who can assume this role. The 'Service' here represents the EC2 service itself.
      Action    = "sts:AssumeRole"
    }]
  })
}
# Instance Profile is a container for the IAM Role.
# EC2 cannot directly attach an IAM Role — it must attach an Instance Profile instead.
# The profile allows EC2 to assume the role and get temporary credentials automatically.
resource "aws_iam_instance_profile" "app_ec2_profile" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.app_ec2_role.name
}

# ----------------------
# Setup Least Privilage
# ----------------------
locals {
  # Retrieve the name and ARN of the S3 bucket created in Terraform.
  bucket_name = aws_s3_bucket.images.bucket
  bucket_arn  = "arn:aws:s3:::${local.bucket_name}"

  # Define the object-level ARN (optionally scoped to a prefix).
  objects_arn = "arn:aws:s3:::${local.bucket_name}/${var.s3_prefix}*"
}

# Generate a least-privilege S3 access policy for the EC2 IAM Role.
data "aws_iam_policy_document" "s3_app_least" {

  # 1) Allow listing objects within the bucket.
  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.bucket_arn]

    # If a prefix is specified, restrict the listing to that prefix only.
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [var.s3_prefix == "" ? "*" : "${var.s3_prefix}*"]
    }
  }

  # 2) Allow reading, uploading, and deleting objects.
  statement {
    sid       = "ObjectRW"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [local.objects_arn]
  }

  # 3) Optional: Allow multipart upload operations for large files.
  statement {
    sid    = "Multipart"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:ListBucketMultipartUploads"
    ]
    resources = [local.bucket_arn, local.objects_arn]
  }
}

# Create the custom least-privilege S3 policy.
resource "aws_iam_policy" "s3_app_policy" {
  name   = "${var.name_prefix}-s3-app-policy"
  policy = data.aws_iam_policy_document.s3_app_least.json
}

# This tells the IAM role what it is allowed to do.
# In this case, Attach the custom least-privilege S3 policy to the EC2 role.
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = aws_iam_policy.s3_app_policy.arn
}

# -----------
# CloudWatch
# -----------

# Grants CloudWatch Agent permissions to create log groups/streams and put log events,
# and to send custom metrics (PutMetricData).
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Enables SSM connectivity (optional but highly recommended to manage the instance/agent
# without SSH and to fetch agent binaries or run commands).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
