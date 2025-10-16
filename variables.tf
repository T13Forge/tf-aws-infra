variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
}

variable "profile" {
  description = "AWS CLI profile to use (e.g., dev, demo)"
  type        = string
}

variable "vpc_name" {
  description = "Name for the VPC (e.g., dev, demo)"
  type        = string
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
  default     = null
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

variable "enable_ipv6" {
  type    = bool
  default = true
}

variable "public_key_path" {
  description = "Path to your SSH public key (.pub)"
  type        = string
  default     = "~/.ssh/aws_key.pub"
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "app"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
