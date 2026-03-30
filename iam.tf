# ECS

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-loki-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}

# EC2

resource "aws_iam_role" "ec2_logging_role" {
  name = "ec2-loki-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_logging_role" {
  name = "ec2-loki-logging-profile"
  role = aws_iam_role.ec2_logging_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
  role       = aws_iam_role.ec2_logging_role.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}

# Loki
resource "aws_iam_role" "loki_s3_role" {
  name = "loki-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:logging:loki"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "loki_s3_policy" {
  name        = "LokiS3StoragePolicy"
  description = "Allows Loki to manage logs in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:ListBucket"]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.loki.arn]
      },
      {
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.loki.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "loki_s3_attach" {
  role       = aws_iam_role.loki_s3_role.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}