resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-ecs-cluster"
}

# Log groups
resource "aws_cloudwatch_log_group" "fe" {
  name              = "/ecs/${var.name_prefix}-frontend"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "be" {
  name              = "/ecs/${var.name_prefix}-backend"
  retention_in_days = 14
}

# Frontend TaskDefinition with nginx sidecar for Basic Auth
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.name_prefix}-fe"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      "name" : "frontend",
      "image" : "${aws_ecr_repository.frontend.repository_url}:latest",
      "essential" : true,
      "portMappings" : [{ "containerPort" : 3000, "hostPort" : 3000, "protocol" : "tcp" }],
      "environment" : [{ "name" : "PORT", "value" : "3000" }],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "${aws_cloudwatch_log_group.fe.name}",
          "awslogs-region" : "${var.region}",
          "awslogs-stream-prefix" : "frontend"
        }
      }
    },
    {
      "name" : "auth-proxy",
      "image" : "${aws_ecr_repository.frontend.repository_url}-nginx:latest",
      "essential" : true,
      "portMappings" : [{ "containerPort" : 80, "hostPort" : 80, "protocol" : "tcp" }],
      "environment" : [
        { "name" : "BASIC_AUTH_USER", "valueFrom" : "${aws_ssm_parameter.basic_user.arn}" },
        { "name" : "BASIC_AUTH_PASS", "valueFrom" : "${aws_ssm_parameter.basic_pass.arn}" }
      ],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "${aws_cloudwatch_log_group.fe.name}",
          "awslogs-region" : "${var.region}",
          "awslogs-stream-prefix" : "nginx"
        }
      },
      "dependsOn" : [{ "containerName" : "frontend", "condition" : "START" }],
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

# Backend TaskDefinition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.name_prefix}-be"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      "name" : "backend",
      "image" : "${aws_ecr_repository.backend.repository_url}:latest",
      "essential" : true,
      "portMappings" : [{ "containerPort" : 4000, "hostPort" : 4000, "protocol" : "tcp" }],
      "logConfiguration" : {
        "logDriver" : "awslogs",
        "options" : {
          "awslogs-group" : "${aws_cloudwatch_log_group.be.name}",
          "awslogs-region" : "${var.region}",
          "awslogs-stream-prefix" : "backend"
        }
      }
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}
