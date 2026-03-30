data "aws_caller_identity" "current" {}

data "kubernetes_service" "loki_gateway" {
  metadata {
    name      = "loki-gateway"
    namespace = "logging"
  }
  depends_on = [helm_release.loki]
}

data "aws_route53_zone" "internal" {
  name         = "ematiq.com."
  private_zone = true
}