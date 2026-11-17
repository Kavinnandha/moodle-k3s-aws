provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Source    = "github.com/Kavinnandha/moodle-k3s-aws"
    }
  }
}
