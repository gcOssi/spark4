terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Usamos backend S3; el workflow pasa -backend-config
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_oidc.arn
}
