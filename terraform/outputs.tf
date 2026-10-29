
output "instance_id" {
  description = "ID of the CloudOps EC2 instance"
  value       = aws_instance.cloudops.id
}

output "public_ip" {
  description = "Public IPv4 address of the CloudOps EC2 instance"
  value       = aws_instance.cloudops.public_ip
}

output "application_url" {
  description = "HTTP URL for the CloudOps application"
  value       = "http://${aws_instance.cloudops.public_ip}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch application log group name"
  value       = aws_cloudwatch_log_group.application.name
}
