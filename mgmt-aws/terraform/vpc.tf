data "aws_availability_zones" "available" {
  state = "available"
}

#------------------- VPC ------------------
resource "aws_vpc" "nkp" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name                                           = var.resource_prefix
    "kubernetes.io/cluster/${var.resource_prefix}" = "shared"
  }
}

#------------------- Subnets ------------------
resource "aws_subnet" "nkp_public" {
  vpc_id                  = aws_vpc.nkp.id
  cidr_block              = var.aws_public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.resource_prefix}-public-subnet"
  }
}

resource "aws_subnet" "nkp_private" {
  vpc_id                  = aws_vpc.nkp.id
  cidr_block              = var.aws_private_subnet_cidr
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.resource_prefix}-private-subnet"
  }
}

#------------------- Internet Gateway and Route Tables ------------------
resource "aws_internet_gateway" "nkp" {
  vpc_id = aws_vpc.nkp.id
  tags = {
    Name = var.resource_prefix
  }
}

resource "aws_route_table" "nkp_public_subnet_route" {
  vpc_id = aws_vpc.nkp.id
  tags = {
    Name = "${var.resource_prefix}-public-subnet-route"
  }
}

resource "aws_route" "nkp_internet_access" {
  route_table_id         = aws_route_table.nkp_public_subnet_route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.nkp.id
}

resource "aws_route_table_association" "nkp_internet_access" {
  subnet_id      = aws_subnet.nkp_public.id
  route_table_id = aws_route_table.nkp_public_subnet_route.id
}

#------------------- NAT Gateway and Route Tables ------------------
resource "aws_eip" "nat_eip" {}

resource "aws_nat_gateway" "nkp" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.nkp_public.id

  depends_on = [aws_internet_gateway.nkp]
}

resource "aws_route_table" "nkp_private_subnet_route" {
  vpc_id = aws_vpc.nkp.id
  tags = {
    Name = "${var.resource_prefix}-private-subnet-route"
  }
}

resource "aws_route" "nkp_nat_access" {
  route_table_id         = aws_route_table.nkp_private_subnet_route.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nkp.id
}

resource "aws_route_table_association" "nkp_nat_access" {
  subnet_id      = aws_subnet.nkp_private.id
  route_table_id = aws_route_table.nkp_private_subnet_route.id
}

#------------------- Security Group ------------------
resource "aws_security_group" "bastion" {
  name_prefix = var.resource_prefix
  description = "Security group for NKP bastion host"
  vpc_id      = aws_vpc.nkp.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow NKP internal communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.nkp.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#------------------- Outputs ------------------
output "vpc_id" {
  value = aws_vpc.nkp.id
}

output "subnet_ids" {
  value = {
    public_subnet_id  = "${aws_subnet.nkp_public.id}"
    private_subnet_id = "${aws_subnet.nkp_private.id}"
  }
}
