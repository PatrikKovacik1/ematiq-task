resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "web-app"
      image = "nginx:latest"
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          "Name"        = "loki"
          "Host"        = "loki-internal.ematiq.com"
          "Port"        = "3100"
          "Labels"      = "{job=\"firelens\", env=\"prod\", service=\"nginx\"}"
          "Line_Format" = "key_value"
        }
      }
    },
    {
      name  = "log_router"
      image = "amazon/aws-for-fluent-bit:latest"
      firelensConfiguration = {
        type = "fluentbit"
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/fluent-bit-logs"
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "firelens"
        }
      }
    }
  ])
}