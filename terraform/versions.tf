terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State is kept locally on purpose: this is a single-person lab that is
  # created and destroyed in one sitting. For a team, move it to an S3 backend
  # with native S3 state locking (use_lockfile = true), for example:
  #
  # backend "s3" {
  #   bucket       = "my-tf-state-bucket"
  #   key          = "moodle-k3s-aws/terraform.tfstate"
  #   region       = "ap-south-1"
  #   use_lockfile = true
  # }
}
