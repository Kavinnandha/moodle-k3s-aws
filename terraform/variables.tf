variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Name prefix used for every resource."
  type        = string
  default     = "moodle-k3s"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project))
    error_message = "project must be 3-21 chars of lowercase letters, digits and dashes (it is used in the S3 bucket name)."
  }
}

variable "admin_cidr" {
  description = "Your public IP as a /32 (e.g. 203.0.113.10/32). The only source allowed to reach the Kubernetes API on 6443."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a valid IPv4 CIDR and must not be 0.0.0.0/0."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "server_instance_type" {
  description = "k3s server node: control plane + Moodle + MySQL + monitoring. Needs about 4 GB RAM."
  type        = string
  default     = "t3.medium"
}

variable "enable_jobe_node" {
  description = "Create a second, tainted node that runs only Jobe (untrusted student code). If false, Jobe falls back to the server node."
  type        = bool
  default     = true
}

variable "jobe_instance_type" {
  description = "Instance type for the dedicated Jobe sandbox node. jobeinabox is amd64-only, so stay on x86 (t3)."
  type        = string
  default     = "t3.small"
}

variable "server_volume_gb" {
  description = "Root EBS volume size for the server node (holds container images and local-path PVs)."
  type        = number
  default     = 20
}

variable "jobe_volume_gb" {
  description = "Root EBS volume size for the Jobe node (the jobeinabox image is large: compilers for many languages)."
  type        = number
  default     = 15
}

variable "k3s_version" {
  description = "Pinned k3s release so every rebuild gets the same Kubernetes version."
  type        = string
  default     = "v1.37.2+k3s1"
}

variable "backup_retention_days" {
  description = "Days to keep backup objects in S3 before the lifecycle rule expires them."
  type        = number
  default     = 14
}

variable "budget_alert_email" {
  description = "If set, create an AWS Budget that emails this address at 50% actual / 100% forecasted spend."
  type        = string
  default     = null
}

variable "budget_limit_usd" {
  description = "Monthly budget limit in USD for the alert above (account-wide)."
  type        = number
  default     = 10
}

variable "backup_bucket_force_destroy" {
  description = "Let `terraform destroy` delete the backup bucket even if it still holds backups. Fine for a lab; set false for anything real."
  type        = bool
  default     = true
}
