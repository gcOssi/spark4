#############################
# Caller identity (una sola)
#############################
data "aws_caller_identity" "current" {}

########################################
# Execution role para tareas ECS (Fargate)
########################################
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

########################################
# Task role (app) para contenedores ECS
########################################
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

########################################
# Rol OIDC para GitHub Actions
########################################
resource "aws_iam_role" "github_actions_oidc" {
  name = "${var.name_prefix}-github-oidc"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        # El token de GitHub debe estar destinado a STS
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        # Permite jobs desde tu repo:
        # - cualquier rama (refs/heads/*)
        # - PRs (refs/pull/*)
        # - tags (refs/tags/*)
        # - environment 'staging'
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.gh_owner}/${var.gh_repo}:ref:refs/heads/*",
            "repo:${var.gh_owner}/${var.gh_repo}:ref:refs/pull/*",
            "repo:${var.gh_owner}/${var.gh_repo}:ref:refs/tags/*",
            "repo:${var.gh_owner}/${var.gh_repo}:environment:staging"
          ]
        }
      }
    }]
  })
}

#########################################################
# Política de permisos para despliegue desde GitHub OIDC
#########################################################
# Minimiza iam:PassRole para solo los roles de ECS que usamos
data "aws_iam_policy_document" "github_permissions_doc" {
  statement {
    sid     = "ECRFull"
    effect  = "Allow"
    actions = ["ecr:*"]
    resources = ["*"]
  }

  statement {
    sid     = "ECSAndInfra"
    effect  = "Allow"
    actions = [
      "ecs:*",
      "elasticloadbalancing:*",
      "cloudwatch:*",
      "sns:*",
      "ssm:*",
      "logs:*",
      "cloudfront:*",
      "acm:*",
      "ec2:*",
      "route53:*",
      "s3:*"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "PassRolesToECSTasks"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_permissions" {
  name   = "${var.name_prefix}-github-deploy"
  role   = aws_iam_role.github_actions_oidc.id
  policy = data.aws_iam_policy_document.github_permissions_doc.json
}

#########################################################
# Acceso del rol OIDC al backend S3/DynamoDB de Terraform
#########################################################
# Requiere variables: tf_backend_bucket, tf_backend_ddb_table
resource "aws_iam_role_policy" "tf_backend_access" {
  name = "${var.name_prefix}-tfstate-access"
  role = aws_iam_role.github_actions_oidc.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "S3StateRW",
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ],
        Resource = [
          "arn:aws:s3:::${var.tf_backend_bucket}",
          "arn:aws:s3:::${var.tf_backend_bucket}/*"
        ]
      },
      {
        Sid    = "DDBLocksRW",
        Effect = "Allow",
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ],
        Resource = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.tf_backend_ddb_table}"
      }
    ]
  })
}
