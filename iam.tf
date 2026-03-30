# ECS

resource "aws_iam_role" "ecs_loki" {
  name = "ecs-loki"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_s3" {
  role       = aws_iam_role.ecs_loki.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}

resource "aws_iam_role" "ecs_execution_loki" {
  name = "ecs-execution-loki"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_loki" {
  role       = aws_iam_role.ecs_execution_loki.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# EC2

resource "aws_iam_role" "ec2_loki" {
  name = "ec2-loki"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_loki" {
  name = "ec2-loki-logging-profile"
  role = aws_iam_role.ec2_loki.name
}

resource "aws_iam_role_policy_attachment" "ec2_s3" {
  role       = aws_iam_role.ec2_loki.name
  policy_arn = aws_iam_policy.loki_s3_policy.arn
}

# Loki
resource "aws_iam_role" "loki_s3" {
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

resource "aws_iam_policy" "loki_s3" {
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

resource "aws_iam_role_policy_attachment" "loki_s3" {
  role       = aws_iam_role.loki_s3.name
  policy_arn = aws_iam_policy.loki_s3.arn
}