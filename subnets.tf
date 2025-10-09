# Public subnets
resource "aws_subnet" "public" {
  for_each = {
    for idx, az in local.selected_azs :
    az => cidrsubnet(var.vpc_cidr, 8, idx)
  }

  vpc_id                  = aws_vpc.csye6225.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "subnet-public-${var.vpc_name}-${each.key}",
    Tier = "public"
  })
}

# Private subnets
resource "aws_subnet" "private" {
  for_each = {
    for idx, az in local.selected_azs :
    az => cidrsubnet(var.vpc_cidr, 8, idx + 100)
  }

  vpc_id            = aws_vpc.csye6225.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "subnet-private-${var.vpc_name}-${each.key}",
    Tier = "private"
  })
}
