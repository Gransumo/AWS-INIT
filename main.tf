provider "aws" {
  region = "eu-west-3"
}

variable "ssh_key_path" {}
variable "availability_zone" {}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer_key"
  public_key = file(var.ssh_key_path)
}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "vpc-main"
  cidr                 = "10.0.0.0/16"
  azs                  = [var.availability_zone]
  private_subnets = [ "10.0.0.0/24", "10.0.1.0/24" ]
  public_subnets = [ "10.0.100.0/24", "10.0.101.0/24" ]
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  tags = {
    Terraform  = "true",
    Enviroment = "dev"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "SSH from VPC"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_ssh"
  }
}

data "aws_ami" "rhel_9" {
  most_recent = true
  owners      = ["309956199498"]
  filter {
    name   = "name"
    values = ["RHEL-9.0*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.rhel_9.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id = element(module.vpc.public_subnets,1)
  tags = {
    Name = "HelloWorld!"
  }
}

output "ip_instance" {
  value = aws_instance.web.private_ip
}

output "ssh" {
  value = "ssh -l ec2-user ${aws_instance.web.public_ip}"
}
