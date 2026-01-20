output "ecr_repository_url" {
  description = "ECR Repository URL"
  value       = aws_ecr_repository.nba_backend.repository_url
}

output "ec2_public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.backend.public_ip
}
