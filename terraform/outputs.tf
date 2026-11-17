output "server_public_ip" {
  description = "Elastic IP of the k3s server node."
  value       = aws_eip.server.public_ip
}

output "moodle_host" {
  description = "Default Moodle hostname (sslip.io resolves it to the EIP). Pass this to scripts/deploy.sh."
  value       = "moodle.${aws_eip.server.public_ip}.sslip.io"
}

output "server_instance_id" {
  description = "Use with: aws ssm start-session --target <id>"
  value       = aws_instance.server.id
}

output "jobe_instance_id" {
  description = "Instance ID of the Jobe sandbox node (null when enable_jobe_node = false)."
  value       = try(aws_instance.jobe[0].id, null)
}

output "backup_bucket" {
  description = "S3 bucket that receives the daily backups."
  value       = aws_s3_bucket.backups.bucket
}

output "fetch_kubeconfig" {
  description = "Command that copies the k3s kubeconfig to ./kubeconfig."
  value       = "../scripts/fetch-kubeconfig.sh ${aws_instance.server.id} ${aws_eip.server.public_ip} ${var.aws_region}"
}
