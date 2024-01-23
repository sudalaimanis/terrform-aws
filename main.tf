terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-south-1"
  access_key="AKIAS42B------------"
  secret_key="skeio99d------------"
}
# create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "my_vpc"
  }
}

# Create public subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a" # Specify the desired availability zone
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b" # Specify the desired availability zone
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_2"
  }
}

# Create private subnet
resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1a" # Specify the desired availability zone

  tags = {
    Name = "private_subnet_1"
  }
}
resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-south-1b" # Specify the desired availability zone

  tags = {
    Name = "private_subnet_2"
  }
}

/*resource "aws_db_subnet_group" "mydb_subnet_group" {
  name = "mydb_subnet_group"
  subnet_ids = [ aws_subnet.private_subnet_2.id ]
} */

# Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_igw"
  }
}

# Attach Internet Gateway to public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}
#create elastic ip
# create EIP
resource "aws_eip" "my_nat_gateway" {
 
  tags = {
    Name = "my_nat_gateway"
  }
}

# Create NAT Gateway in the public subnet
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_nat_gateway.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "my_nat_gateway"
  }
}

# Create a route table for private subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private_route_table"
  }
}

# Create a route to NAT Gateway for private subnet
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
}

# Associate private route table with private subnet
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}
# Create security group for app server
resource "aws_security_group" "app_sg" {
  name = "app_sg"
  vpc_id = aws_vpc.my_vpc.id


  tags = {
    Name = "app_sg"
  }
}
# security group rule for ingress
resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
# security group rule for egress
resource "aws_vpc_security_group_egress_rule" "ipv4" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
# Create security group for backend server
resource "aws_security_group" "backend_sg" {
  name = "backend_sg"
  vpc_id = aws_vpc.my_vpc.id


  tags = {
    Name = "backend_sg"
  }
}
# security group rule for ingress
resource "aws_vpc_security_group_ingress_rule" "backend_https" {
  security_group_id = aws_security_group.backend_sg.id
  cidr_ipv4 = aws_subnet.public_subnet_1.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "backend_http" {
  security_group_id = aws_security_group.backend_sg.id
  cidr_ipv4 = aws_subnet.public_subnet_1.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "backend_ssh" {
  security_group_id = aws_security_group.backend_sg.id
  cidr_ipv4 = aws_subnet.public_subnet_1.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
# security group rule for egress
resource "aws_vpc_security_group_egress_rule" "backend_sg" {
  security_group_id = aws_security_group.backend_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Create security group for RDS
resource "aws_security_group" "rds_sg" {
  name = "rds_sg"
  vpc_id = aws_vpc.my_vpc.id


  tags = {
    Name = "rds_sg"
  }
}
# security group rule for ingress
resource "aws_vpc_security_group_ingress_rule" "rds_sg" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4 = aws_subnet.private_subnet_1.cidr_block
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}
# security group rule for egress
resource "aws_vpc_security_group_egress_rule" "rds_sg" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# You can add other resources as needed, like security groups, instances, etc.
resource "aws_instance" "app_server" {
  ami           = "ami-03f4878755434977f"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "App_server"
  }
}

resource "aws_instance" "backend_server" {
  ami           = "ami-03f4878755434977f"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [ aws_security_group.backend_sg.id ]
  
  tags = {
    Name = "Backend_server"
  }
 
}
# Create AWS MYSQL RDS
resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "manipassword"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  
}
# Create Route 53 
resource "aws_route53_zone" "primary" {
  name = "sudalaimani.co.in"
}
