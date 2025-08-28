# Store default basic auth (can be overridden in CI/CD with secrets)
resource "aws_ssm_parameter" "basic_user" {
  name  = "/${var.name_prefix}/basic_user"
  type  = "String"
  value = "staging"
}

resource "aws_ssm_parameter" "basic_pass" {
  name  = "/${var.name_prefix}/basic_pass"
  type  = "String"
  value = "staging"
}
