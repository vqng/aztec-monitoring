# Aztec GitHub Actions Exporter Helm Chart (local)
resource "helm_release" "aztec_gh_exporter" {
  name       = "aztec-gh-exporter"
  chart      = "${path.module}/charts/aztec-gh-exporter"
  namespace  = kubernetes_namespace.grafana.metadata[0].name

  values = [
    yamlencode({
      replicaCount = 1

      image = {
        repository = "hvquang/aztec-gh-exporter"
        pullPolicy = "IfNotPresent"
      }

      env = {
        VM_URL       = "http://victoriametrics-victoria-metrics-single-server:${var.victoriametrics_port}"
        GITHUB_TOKEN = var.github_token
      }

      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.grafana,
    helm_release.victoriametrics
  ]
}

