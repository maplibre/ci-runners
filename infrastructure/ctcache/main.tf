terraform {
  required_version = ">= 1.11, < 2.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    bucket       = "maplibre-ci-runners-tofu-state-373521797162"
    key          = "ctcache/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["373521797162"]
  default_tags { tags = { Project = "maplibre-ctcache", ManagedBy = "OpenTofu" } }
}
data "aws_ami" "nixos" {
  owners      = ["427812963091"]
  most_recent = true
  filter {
    name   = "name"
    values = ["nixos/26.05*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}
resource "aws_iam_role" "server" {
  name = "maplibre-ctcache"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" }
  }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "server" {
  name = "maplibre-ctcache"
  role = aws_iam_role.server.name
}
resource "aws_security_group" "server" {
  name_prefix = "maplibre-ctcache-"
  description = "Public ctcache HTTP; administration through SSM"
  vpc_id      = "vpc-09e20d39fca575e8d"
}
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 5000
  to_port           = 5000
}
resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_instance" "server" {
  ami                         = data.aws_ami.nixos.id
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.admin.key_name
  subnet_id                   = "subnet-01e2d8344710ddfe3"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.server.id]
  iam_instance_profile        = aws_iam_instance_profile.server.name
  metadata_options { http_tokens = "required" }
  root_block_device {
    volume_size           = 100
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  user_data_base64 = base64gzip(templatefile("${path.module}/user-data.sh.tftpl", {
    files = { for name in ["flake.nix", "flake.lock", "package.nix", "configuration.nix"] :
    name => base64encode(file("${path.module}/../../ctcache/nix/${name}")) }
  }))
  user_data_replace_on_change = true
  tags                        = { Name = "maplibre-ctcache-server" }
  depends_on                  = [aws_iam_role_policy_attachment.ssm, aws_vpc_security_group_egress_rule.outbound]
}
resource "aws_eip" "server" {
  domain = "vpc"
  tags   = { Name = "maplibre-ctcache" }
}
resource "aws_eip_association" "server" {
  allocation_id = aws_eip.server.id
  instance_id   = aws_instance.server.id
}
output "ctcache_host" { value = aws_eip.server.public_ip }
output "instance_id" { value = aws_instance.server.id }

resource "aws_key_pair" "admin" {
  key_name   = "maplibre-ctcache"
  public_key = file(pathexpand(var.ssh_public_key_file))
}
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.server.id
  cidr_ipv4         = var.ssh_allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}
