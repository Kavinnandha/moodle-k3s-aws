# Two instance roles, each with only what its node needs.
#
#   server role: read the k3s join token, put/get/list under s3://bucket/backups/
#                (no delete), SSM Session Manager
#   jobe role:   read the k3s join token, SSM Session Manager. No S3 at all.
#
# Pods cannot use either role: IMDSv2 is required with a hop limit of 1 (see
# compute.tf), so a container, which is one network hop further away, never
# gets a token from the metadata service. Untrusted code running in Jobe
# therefore cannot pick up AWS credentials.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ssm_core" {
  name = "AmazonSSMManagedInstanceCore"
}

# --- server -----------------------------------------------------------------

resource "aws_iam_role" "server" {
  name               = "${var.project}-server"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "server" {
  statement {
    sid       = "ReadK3sToken"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.k3s_token.arn]
  }

  statement {
    sid       = "WriteAndReadBackups"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.backups.arn}/backups/*"]
  }

  statement {
    sid       = "ListBackupsPrefix"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backups.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["backups/*"]
    }
  }
}

resource "aws_iam_role_policy" "server" {
  name   = "least-privilege"
  role   = aws_iam_role.server.id
  policy = data.aws_iam_policy_document.server.json
}

resource "aws_iam_role_policy_attachment" "server_ssm" {
  role       = aws_iam_role.server.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_iam_instance_profile" "server" {
  name = "${var.project}-server"
  role = aws_iam_role.server.name
}

# --- jobe -------------------------------------------------------------------

resource "aws_iam_role" "jobe" {
  name               = "${var.project}-jobe"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "jobe" {
  statement {
    sid       = "ReadK3sToken"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.k3s_token.arn]
  }
}

resource "aws_iam_role_policy" "jobe" {
  name   = "least-privilege"
  role   = aws_iam_role.jobe.id
  policy = data.aws_iam_policy_document.jobe.json
}

resource "aws_iam_role_policy_attachment" "jobe_ssm" {
  role       = aws_iam_role.jobe.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_iam_instance_profile" "jobe" {
  name = "${var.project}-jobe"
  role = aws_iam_role.jobe.name
}
