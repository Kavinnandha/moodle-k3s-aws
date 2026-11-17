# The k3s cluster join token lives in SSM Parameter Store (SecureString, AWS
# managed key, free tier) instead of being pasted into user-data, where anyone
# with ec2:DescribeInstanceAttribute could read it.
#
# Note: the value is still in the Terraform state file. That file is
# gitignored and local. Treat it as a secret.

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

resource "aws_ssm_parameter" "k3s_token" {
  name        = "/${var.project}/k3s-token"
  description = "k3s cluster join token"
  type        = "SecureString"
  value       = random_password.k3s_token.result
}
