output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "ecr_repo_frontend" {
  value = aws_ecr_repository.frontend.name
}

output "ecr_repo_backend" {
  value = aws_ecr_repository.backend.name
}
