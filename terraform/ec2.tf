# 1. Specify the Terraform Provider and AWS Profile
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# 2. Fetch the latest Ubuntu 22.04 LTS AMI automatically
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

# 3. Reference or create your SSH Key Pair
# Option A: If you want Terraform to upload a key you already have locally:
resource "aws_key_pair" "deployer" {
  key_name   = "ec2-deploy-key"
  public_key = file("~/.ssh/id_rsa.pub") # Path to your local public key
}

# 4. Updated Security Group (HTTP port 80 AND SSH port 22 open)
resource "aws_security_group" "web_and_ssh" {
  name        = "allow_http_and_ssh"
  description = "Allow inbound HTTP and SSH traffic"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- ADDED SSH RULE ---
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For production, restrict this to your IP (e.g., "your_ip/32")
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_and_ssh_sg"
  }
}

# 5. Create the EC2 Instance with the Key Pair attached
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  
  # --- LINKED KEY PAIR HERE ---
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.web_and_ssh.id]

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "ec2_instance"
  }
}

# 6. Outputs
output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.web_server.id
}

output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}