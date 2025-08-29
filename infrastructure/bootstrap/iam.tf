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
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.gh_owner}/${var.gh_repo}:environment:staging",
            "repo:${var.gh_owner}/${var.gh_repo}:ref:refs/heads/main"
          ]
        }
      }
    }]
  })

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "github_permissions_doc" {
  statement {
    sid       = "ECRFull"
    effect    = "Allow"
    actions   = ["ecr:*"]
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

  # Si tus servicios ECS usan roles de tarea, añade aquí arn(s) permitidos en iam:PassRole.
  # En bootstrap aún no existen, así que este mínimo permite PassRole a ECS Tasks en general.
  statement {
    sid       = "PassRoleToECSTasks"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
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

  lifecycle {
    prevent_destroy = true
  }
}

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

  lifecycle {
    prevent_destroy = true
  }
}
