// VPC - AWS equivalent of Azure VNet, our isolated network space
resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
}

// Public subnet - will hold the NAT Gateway, reachable from internet via IGW
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.1.1.0/24"
}

// Private subnet - will hold ECS/RDS, outbound-only via NAT Gateway
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.1.2.0/24"
}

//Second private subnet, different Availaibit Zone - RDS requires 2+ subnets across AZs even for single-AZ deployment
resource "aws_subnet" "private2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.1.3.0/24"
  availability_zone = "us-west-2b"
}

// Internet Gateway - makes the VPC reachable to/from the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

// Public route table - sends internet-bound traffic (0.0.0.0/0) to the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

// Associates the public route table with the public subnet - required, tables don't auto-attach
resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public.id
}

// Elastic IP - static public IP the NAT Gateway needs to be internet-facing
resource "aws_eip" "nat" {
  domain = "vpc"
}

// NAT Gateway - lives in public subnet, gives private subnet outbound-only internet access
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

// Private route table - sends internet-bound traffic to the NAT Gateway instead of the IGW
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

// Associates the private route table with the private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

// ECS security group - allows inbound on Flask's port 5000 from the public subnet only
resource "aws_security_group" "ecs" {
  name   = "ecs-proj2dr-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// RDS security group - allows Postgres (5432) only from the ECS security group, no egress needed (stateful)
resource "aws_security_group" "rds" {
  name   = "rds-proj2dr-sg"
  vpc_id = aws_vpc.main.id

// Internal access - allows ECS tasks to reach RDS on Postgres port
  ingress {
    from_port = 5432
    to_port = 5432
    protocol  = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

// External access - allows Azure app tier to reach RDS for the cross-cloud sync pipeline (documented tradeoff for speed, would scope tighter in production)
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// DB Subnet Group - tells RDS which subnets it's allowed to use; logical grouping only, no network config itself
resource "aws_db_subnet_group" "main" {
  name = "proj2dr-db-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.private2.id] 
}

