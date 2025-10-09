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

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
