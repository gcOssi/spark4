# Execution role for ECS tasks
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name_prefix}-ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role (app)
resource "aws_iam_role" "ecs_task" {
  name = "${var.name_prefix}-ecsTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# OIDC role for GitHub Actions (replace your org/repo/branch as needed)
resource "aws_iam_role" "github_actions_oidc" {
  name = "${var.name_prefix}-github-oidc"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com" },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub": [
          "repo:${var.gh_owner}/${var.gh_repo}:environment:staging",
          "repo:${var.gh_owner}/${var.gh_repo}:ref:refs/heads/main"
        ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_permissions" {
  name = "${var.name_prefix}-github-deploy"
  role = aws_iam_role.github_actions_oidc.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = [
        "ecr:*"
      ], Resource = "*" },
      { Effect = "Allow", Action = [
        "ecs:*", "iam:PassRole", "elasticloadbalancing:*", "cloudwatch:*", "sns:*", "ssm:*", "logs:*", "cloudfront:*", "acm:*", "ec2:*", "route53:*", "s3:*"
      ], Resource = "*" }
    ]
  })
}