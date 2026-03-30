resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

# Loki
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = "logging"
  version    = "6.6.0"

  values = [
    templatefile("${path.module}/loki.yaml", {
      loki_role_arn = aws_iam_role.loki_s3_role.arn
      account_id    = data.aws_caller_identity.current.account_id
    })
  ]

  depends_on = [aws_iam_role_policy_attachment.loki_s3_attach]
}

resource "kubernetes_service_account" "loki" {
  metadata {
    name      = "loki"
    namespace = "logging"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.loki_s3_role.arn
    }
  }
}

# Grafana

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.logging.metadata[0].name
  version    = "8.0.0"

  values = [
    file("${path.module}/grafana.yaml")
  ]
}

# Fluent Bit

resource "helm_release" "fluent_bit" {
  name             = "fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  namespace        = kubernetes_namespace.logging.metadata[0].name

  values = [
    file("${path.module}/fluentbit.yaml")
  ]
}