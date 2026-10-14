terraform {
  required_version = ">= 1.11, < 2.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    bucket       = "maplibre-ci-runners-tofu-state-373521797162"
    key          = "forgejo/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
provider "aws" {
  region              = "eu-central-1"
  allowed_account_ids = ["373521797162"]
  default_tags { tags = { Project = "maplibre-forgejo", ManagedBy = "OpenTofu" } }
}
data "aws_vpc" "default" {
  default = true
}
# The data volume and the instance must share an availability zone.
data "aws_subnet" "server" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "eu-central-1a"
  default_for_az    = true
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
  name = "maplibre-forgejo"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" }
  }] })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "server" {
  name = "maplibre-forgejo"
  role = aws_iam_role.server.name
}
resource "aws_security_group" "server" {
  name_prefix = "maplibre-forgejo-"
  description = "Public Git over HTTPS and SSH; administration over SSH or SSM"
  vpc_id      = data.aws_vpc.default.id
}
# SSH is public because Git uses it; the server only accepts keys.
resource "aws_vpc_security_group_ingress_rule" "public" {
  for_each          = { ssh = "tcp/22", http = "tcp/80", https = "tcp/443", http3 = "udp/443" }
  security_group_id = aws_security_group.server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = split("/", each.value)[0]
  from_port         = tonumber(split("/", each.value)[1])
  to_port           = tonumber(split("/", each.value)[1])
}
resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.server.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_key_pair" "admin" {
  key_name   = "maplibre-forgejo"
  public_key = file(pathexpand(var.ssh_public_key_file))
}
# Repositories, LFS objects and the database live here, independent of the instance.
resource "aws_ebs_volume" "data" {
  availability_zone = data.aws_subnet.server.availability_zone
  size              = 100
  type              = "gp3"
  encrypted         = true
  final_snapshot    = true
  tags              = { Name = "maplibre-forgejo-data" }
  lifecycle { prevent_destroy = true }
}
resource "aws_instance" "server" {
  ami                         = data.aws_ami.nixos.id
  instance_type               = "m7i.large"
  key_name                    = aws_key_pair.admin.key_name
  subnet_id                   = data.aws_subnet.server.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.server.id]
  iam_instance_profile        = aws_iam_instance_profile.server.name
  metadata_options { http_tokens = "required" }
  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  # The AMI only provides a base NixOS for `just forgejo::deploy`; newer AMIs must not
  # replace the server.
  lifecycle { ignore_changes = [ami] }
  tags       = { Name = "maplibre-forgejo" }
  depends_on = [aws_iam_role_policy_attachment.ssm, aws_vpc_security_group_egress_rule.outbound]
}
# NixOS mounts the volume by this device name.
resource "aws_volume_attachment" "data" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.data.id
  instance_id                    = aws_instance.server.id
  stop_instance_before_detaching = true
}
resource "aws_eip" "server" {
  domain = "vpc"
  tags   = { Name = "maplibre-forgejo" }
}
resource "aws_eip_association" "server" {
  allocation_id = aws_eip.server.id
  instance_id   = aws_instance.server.id
}
resource "aws_iam_role" "snapshots" {
  name = "maplibre-forgejo-snapshots"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "dlm.amazonaws.com" }
  }] })
}
resource "aws_iam_role_policy_attachment" "snapshots" {
  role       = aws_iam_role.snapshots.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}
# One volume holds both the repositories and Postgres, so each snapshot is consistent.
resource "aws_dlm_lifecycle_policy" "data" {
  description        = "Daily maplibre-forgejo data snapshots"
  execution_role_arn = aws_iam_role.snapshots.arn
  state              = "ENABLED"
  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = { Name = aws_ebs_volume.data.tags.Name }
    schedule {
      name      = "daily"
      copy_tags = true
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }
      retain_rule { count = 14 }
    }
  }
}
# LFS objects, attachments, packages, avatars, archives and Actions logs and artifacts.
resource "aws_s3_bucket" "storage" {
  bucket = "maplibre-forgejo-373521797162"
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_versioning" "storage" {
  bucket = aws_s3_bucket.storage.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "storage" {
  bucket                  = aws_s3_bucket.storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "storage" {
  bucket = aws_s3_bucket.storage.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "RequireTLS", Effect = "Deny", Principal = "*", Action = "s3:*"
      Resource  = [aws_s3_bucket.storage.arn, "${aws_s3_bucket.storage.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}
# Deleted or overwritten objects stay as long as the data volume's snapshots, so a
# restored database can find the files it refers to.
resource "aws_s3_bucket_lifecycle_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id
  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 14 }
    expiration { expired_object_delete_marker = true }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
  depends_on = [aws_s3_bucket_versioning.storage]
}
# Forgejo uses the instance role's credentials, so no access key exists.
resource "aws_iam_role_policy" "storage" {
  name = "forgejo-storage"
  role = aws_iam_role.server.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    {
      Effect = "Allow", Resource = aws_s3_bucket.storage.arn
      Action = ["s3:ListBucket", "s3:ListBucketMultipartUploads"]
    },
    {
      Effect = "Allow", Resource = "${aws_s3_bucket.storage.arn}/*"
      Action = [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
        "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts",
      ]
    },
  ] })
}
# Forgejo sends from the subdomain, so nothing changes for Google Workspace on maplibre.org.
resource "aws_sesv2_email_identity" "forgejo" {
  email_identity = "code.maplibre.org"
}
resource "aws_sesv2_email_identity_mail_from_attributes" "forgejo" {
  email_identity   = aws_sesv2_email_identity.forgejo.email_identity
  mail_from_domain = "bounce.code.maplibre.org"
}
resource "aws_iam_user" "smtp" {
  name = "maplibre-forgejo-smtp"
}
resource "aws_iam_user_policy" "smtp" {
  name = "send-as-noreply"
  user = aws_iam_user.smtp.name
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Action = "ses:SendRawEmail", Resource = "*"
    Condition = { StringEquals = { "ses:FromAddress" = "noreply@code.maplibre.org" } }
  }] })
}
# The derived SMTP password is stored in the encrypted state bucket.
resource "aws_iam_access_key" "smtp" {
  user = aws_iam_user.smtp.name
}
output "forgejo_host" { value = aws_eip.server.public_ip }
output "storage_bucket" { value = aws_s3_bucket.storage.bucket }
output "smtp_username" { value = aws_iam_access_key.smtp.id }
output "smtp_password" {
  value     = aws_iam_access_key.smtp.ses_smtp_password_v4
  sensitive = true
}
output "ses_dkim_tokens" { value = aws_sesv2_email_identity.forgejo.dkim_signing_attributes[0].tokens }
output "instance_id" { value = aws_instance.server.id }
