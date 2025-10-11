# Internet Gateway
resource "aws_internet_gateway" "csye6225" {
  vpc_id = aws_vpc.csye6225.id

  tags = merge(var.tags, {
    Name = "igw-csye6225-${var.vpc_name}-${terraform.workspace}"
  })
}
