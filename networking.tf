resource "aws_route53_record" "loki_internal" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "loki-internal.ematiq.com"
  type    = "CNAME"
  ttl     = 300
  records = [data.kubernetes_service.loki_gateway.status[0].load_balancer[0].ingress[0].hostname]
}