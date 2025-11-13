variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
}

# variable "profile" {
#   description = "AWS CLI profile to use (e.g., dev, demo)"
#   type        = string
# }

variable "vpc_name" {
  description = "Name for the VPC (e.g., dev, demo)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Your custom AMI ID for the instance"
  type        = string
}

variable "subnet_tier" {
  description = "Which tier to place EC2 in: public or private"
  type        = string
  default     = "public"
  validation {
    condition     = contains(["public", "private"], var.subnet_tier)
    error_message = "subnet_tier must be 'public' or 'private'."
  }
}

variable "target_az" {
  description = "AZ for the EC2 (e.g., us-east-1a). If null, pick the first AZ you created."
  type        = string
  default     = "us-east-1a"
}

variable "create_ec2_instance" {
  description = "Create an EC2 instance directly not part of ASG"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "Existing EC2 key pair name (for SSH); leave empty to skip"
  type        = string
  default     = ""
}

variable "app_port" {
  description = "Port your application listens on"
  type        = number
  default     = 8081
}

variable "public_key_path" {
  description = "Path to your SSH public key (.pub)"
  type        = string
  default     = "~/.ssh/aws_key.pub"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "csye6225"
}

variable "db_port" {
  description = "Database port number"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Initial database name to create inside RDS"
  type        = string
  default     = "csye6225_db"
}

variable "db_username" {
  description = "Master DB username"
  type        = string
  default     = "csye6225_user"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro" # or "db.t4g.micro" (ARM/Graviton)
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

# Control PG version & family
variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "db_engine_family" {
  description = "Parameter group family for PostgreSQL"
  type        = string
  default     = "postgres16"
}

variable "app_user" {
  type    = string
  default = "csyeapp"
}

variable "app_group" {
  type    = string
  default = "csye6225"
}

variable "app_dir" {
  type    = string
  default = "/opt/csye6225"
}

variable "service_name" {
  type    = string
  default = "csye6225_webapp"
}

variable "s3_prefix" {
  description = "Restrict access to a specific folder (prefix) inside the bucket. Leave empty (\"\") to allow access to the entire bucket."
  type        = string
  default     = ""
}

variable "route53_zone_name" {
  description = "Public hosted zone name for this environment (e.g., dev.domain.tld or demo.domain.tld)"
  type        = string
}

variable "enable_ssh" {
  description = "Enable SSH (port 22) access for admin management"
  type        = bool
  default     = true
}

variable "my_ip_cidr" {
  description = "Public IPv4 CIDR allowed to SSH into EC2 (e.g., 35.27.81.142/32)"
  type        = string
  default     = "0.0.0.0/0"
}

# Path used by the ALB Target Group to perform health checks on EC2 instances.
# Make sure your application responds with HTTP 200 on this endpoint.
variable "health_check_path" {
  description = "HTTP path for ALB Target Group health checks (e.g. /healthz)"
  type        = string
  default     = "/healthz"
}

variable "template_name" {
  description = "name for EC2 template used by ASG"
  type        = string
  default     = "csye6225_asg"
}

# Verified sender email address used by SES
variable "verifiedSenderEmail" {
  description = "The SES verified email address used as the 'From' field for outgoing messages"
  type        = string
}

# Base URL for the email verification link
variable "verificationEndPoint" {
  description = "The base URL for the /validateEmail endpoint used in verification emails"
  type        = string
}

variable "account_id" {
  description = "SNS resource location"
  type = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
