# Canonical's official Ubuntu 24.04 LTS (amd64). amd64 because the
# jobeinabox image is only published for amd64.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Stable public IP: the Moodle hostname (moodle.<ip>.sslip.io), the k3s
# API certificate SAN and your kubeconfig all depend on it.
resource "aws_eip" "server" {
  domain = "vpc"

  tags = { Name = "${var.project}-server" }
}

resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.server_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.server.id]
  iam_instance_profile        = aws_iam_instance_profile.server.name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/templates/server-userdata.sh.tftpl", {
    region      = var.aws_region
    eip         = aws_eip.server.public_ip
    token_param = aws_ssm_parameter.k3s_token.name
    bucket      = aws_s3_bucket.backups.bucket
    k3s_version = var.k3s_version
  })
  user_data_replace_on_change = true

  # IMDSv2 only, hop limit 1: the host can use its instance role, but pods
  # (one hop further away) cannot reach the metadata service.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # T3 defaults to "unlimited" CPU credits, which can quietly bill extra.
  # "standard" throttles instead of charging.
  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.server_volume_gb
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${var.project}-server" }

  lifecycle {
    # A newer Ubuntu AMI should not silently rebuild the cluster.
    ignore_changes = [ami]
  }
}

resource "aws_eip_association" "server" {
  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.server.id
}

resource "aws_instance" "jobe" {
  count = var.enable_jobe_node ? 1 : 0

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.jobe_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.jobe.id]
  iam_instance_profile        = aws_iam_instance_profile.jobe.name
  associate_public_ip_address = true # outbound only (image pulls, SSM); the SG allows no internet ingress

  user_data = templatefile("${path.module}/templates/jobe-userdata.sh.tftpl", {
    region      = var.aws_region
    token_param = aws_ssm_parameter.k3s_token.name
    server_ip   = aws_instance.server.private_ip
    k3s_version = var.k3s_version
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.jobe_volume_gb
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${var.project}-jobe" }

  lifecycle {
    ignore_changes = [ami]
  }
}
