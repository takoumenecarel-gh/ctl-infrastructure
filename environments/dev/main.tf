resource "aws_vpc" "dev_vpc" {
  cidr_block = "0.0.0.0/16"
  tags = {
    Name        = "dev-vpc"
    Environment = "dev"
  }
}