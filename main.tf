data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, 3)
}
