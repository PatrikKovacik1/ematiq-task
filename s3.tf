resource "aws_s3_bucket" "loki" {
  bucket = "loki-storage-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_lifecycle_configuration" "loki" {
  bucket = aws_s3_bucket.loki.id

  rule {
    id     = "expire_logs_after_30_days"
    status = "Enabled"
    expiration {
      days = 30
    }
  }
}