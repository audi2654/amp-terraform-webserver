# terraform {
#   required_providers {
#     aws = {
#       source = "hashicorp/aws"
#       version = "5.64.0"
#     }
#   }
# }

# provider "aws" {
#   region     = "us-east-1"
#   access_key = "xxxxxxx"
#   secret_key = "xxxxxxx"
# }

provider "aws" {
  # Need to have AWS CLI installed & properly configured either with access keys or with Identity Center
  # shared_config_files = ["C:/Users/xxxxx/.aws/config"]
  # shared_credentials_files = ["C:/Users/xxxxx/.aws/credentials"]

  # Alternatively for persistent use, create & set Environment Variables AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_CONFIG_FILE
  # via System Properties for Windows
  # export & set in files ~/.bashrc or ~/.profile for Linux

  profile = "aditya-tf" # Profile name set in path AWS_CONFIG_FILE or in file at "C:/Users/xxxxx/.aws/config"
}

# Create a bucket
# resource "aws_s3_bucket" "tf-example" {
#   bucket = "tf-bucket-tele-1" # Replace with your actual bucket name
#   tags = {
#     Name        = "telemetry",
#     Environment = "production"
#   }
# }

# # List the details of a bucket
# data "aws_s3_bucket" "tf-example" {
#   bucket = "tf-bucket-tele-1" # Replace with your actual bucket name
# }

#--------------------------------------------------------------------------------------------------

# 1. Create a VPC
resource "aws_vpc" "tf-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name        = "telemetry"
    Environment = "production"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "tf-igw" {
  vpc_id = aws_vpc.tf-vpc.id
  tags = {
    Name        = "telemetry"
    Environment = "production"
  }
}

# 3. Create a Route Table for VPC to route all traffic from Subnet to target IGW
resource "aws_route_table" "tf-route-table" {
  vpc_id = aws_vpc.tf-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.tf-igw.id
  }

  tags = {
    Name        = "telemetry"
    Environment = "production"
  }
}

# 4. Create a Subnet for web server to reside
resource "aws_subnet" "tf-subnet-1" {
  vpc_id                  = aws_vpc.tf-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "telemetry"
    Environment = "production"
  }
}

# 5. Associate Subnet with Route Table
resource "aws_route_table_association" "tf-rt-subnet" {
  subnet_id      = aws_subnet.tf-subnet-1.id
  route_table_id = aws_route_table.tf-route-table.id
}

# 

# 6. Create a Security Group that allows your server to connect via port 22, 80, 443
# resource "aws_security_group" "tf-allow-tls" {
#   name        = "tf-allow-tls"
#   description = "Allow TLS Web Server inbound traffic and all outbound traffic"
#   vpc_id      = aws_vpc.tf-vpc.id

#   tags = {
#     Name = "tf-allow_tls"
#   }
# }

# # Allow inbound web traffic on port 443 from anywhere
# resource "aws_vpc_security_group_ingress_rule" "tf-allow-ingress-tls-ipv4-443" {
#   security_group_id = aws_security_group.tf-allow-tls.id
#   description       = "HTTPS traffic from anywhere into VPC"
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 443
#   ip_protocol       = "tcp"
#   to_port           = 443
# }

# # Allow inbound web traffic on port 80 from anywhere
# resource "aws_vpc_security_group_ingress_rule" "tf-allow-ingress-tls-ipv4-80" {
#   security_group_id = aws_security_group.tf-allow-tls.id
#   description       = "HTTP traffic from anywhere into VPC"
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 80
#   ip_protocol       = "tcp"
#   to_port           = 80
# }

# # Allow inbound web traffic on port 22 from anywhere
# resource "aws_vpc_security_group_ingress_rule" "tf-allow-ingress-tls-ipv4-22" {
#   security_group_id = aws_security_group.tf-allow-tls.id
#   description       = "SSH traffic from anywhere into VPC to log into server"
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 22
#   ip_protocol       = "tcp"
#   to_port           = 22
# }

# # Allow all outbound traffic from server via all ports to any destination
# resource "aws_vpc_security_group_egress_rule" "tf-allow-egress-tls-ipv4" {
#   security_group_id = aws_security_group.tf-allow-tls.id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "-1" # semantically equivalent to all ports
# }

#

resource "aws_security_group" "tf-allow-tls" {
  name        = "tf-allow-tls"
  description = "Allow TLS Web Server inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.tf-vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# 7. Create a Network Interface (ENI)
# resource "aws_network_interface" "tf-eni" {
#   subnet_id       = aws_subnet.tf-subnet-1.id
#   private_ips     = ["10.0.1.50"]
#   security_groups = [aws_security_group.tf-allow-tls.id]
# }

# 8. Create a EC2 & install apache2
resource "aws_instance" "tf-web-server" {
  ami               = "ami-06b21ccaeff8cd686"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "tf-ec2-key"

  # network_interface {
  #   network_interface_id = aws_network_interface.tf-eni.id
  #   device_index         = 0
  # }

  user_data = <<-EOF
              #!/bin/bash
              set -e  # Exit immediately if a command exits with a non-zero status
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              echo 'your first web server using terraform' | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name        = "telemetry"
    Environment = "production"
  }
}

output "instance_ip" {
  value = aws_instance.tf-web-server.public_ip
}
