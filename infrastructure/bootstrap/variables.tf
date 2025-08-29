variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "name_prefix" {
  type        = string
  description = "Resource prefix"
  default     = "staging"
}

variable "gh_owner" {
  type        = string
  description = "GitHub org/owner usado en el OIDC condition"
}

variable "gh_repo" {
  type        = string
  description = "GitHub repo usado en el OIDC condition"
}

variable "alarm_email" {
  type        = string
  description = "Email to subscribe to SNS alerts"
  default     = "gcabrera@binarios.cl"
}

variable "tf_backend_bucket" {
  type        = string
  description = "S3 bucket for Terraform remote state"
}

variable "tf_backend_ddb_table" {
  type        = string
  description = "DynamoDB table for Terraform state locking"
}

