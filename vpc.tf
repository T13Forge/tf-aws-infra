resource "aws_vpc" "csye6225" {
  region = var.region
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "csye6225-${var.vpc_name}"
  })

}
