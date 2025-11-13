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

# ------------------------
# EC2 publish to SNS Topic
# ------------------------

# policy for EC2 can publish msg to subscribed SND Topic
resource "aws_iam_role_policy" "app_publish_sns" {
  name = "app-publish-sns"
  role = aws_iam_role.app_ec2_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["sns:Publish"],
      Resource = aws_sns_topic.user_signup.arn
    }]
  })
}

# -------------------
# Email Lambda Role
# -------------------

# Assume role
resource "aws_iam_role" "lambda_email_role" {
  name = "lambda-email-sender-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Get current AWS account identity (used to build ARNs)
data "aws_caller_identity" "me" {}

# Logs
# Basic logging permissions for the Lambda function.
# Allows the function to create log groups/streams and send log events to CloudWatch Logs.
resource "aws_iam_role_policy" "lambda_logs" {
  name = "lambda-basic-logs"
  role = aws_iam_role.lambda_email_role.id

  # Lambda will automatically create a log group in CloudWatch e.g. /aws/lambda/<function-name>
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.me.account_id}:log-group:/aws/lambda/*"
    }]
  })
}

# Secrets
# Allow the Lambda function to read the Mailgun API key
# stored in AWS Secrets Manager.
resource "aws_iam_role_policy" "lambda_secrets_read" {
  name = "lambda-secrets-read"
  role = aws_iam_role.lambda_email_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = aws_secretsmanager_secret.mailgun.arn
    }]
  })
}

# KMS decrypt (for that secret's CMK)
resource "aws_iam_role_policy" "lambda_kms_decrypt" {
  name = "lambda-kms-decrypt"
  role = aws_iam_role.lambda_email_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["kms:Decrypt"],
      Resource = aws_kms_alias.secrets_key_alias.arn
    }]
  })
}

# SES send
resource "aws_iam_role_policy" "lambda_ses_send" {
  name = "lambda-ses-send"
  role = aws_iam_role.lambda_email_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["ses:SendEmail", "ses:SendRawEmail"],
      Resource = "*"
    }]
  })
}

# Allow lambda to r/w items in the DynamoDB table
# to perform deduplication
resource "aws_iam_role_policy" "lambda_dedup_policy" {
  name = "lambda-dedup-policy"
  role = aws_iam_role.lambda_email_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem"],
        Resource = aws_dynamodb_table.sent_emails.arn
      }
    ]
  })
}
