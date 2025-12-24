# VictoriaMetrics (single) Helm Chart - ephemeral storage, single replica
resource "helm_release" "victoriametrics" {
  name       = "victoriametrics"
  repository = "https://victoriametrics.github.io/helm-charts"
  chart      = "victoria-metrics-single"
  namespace  = kubernetes_namespace.grafana.metadata[0].name

  values = [
    yamlencode({
      server = {
        replicaCount = 1

        persistentVolume = {
          enabled = false
        }

        service = {
          servicePort = var.victoriametrics_port
          targetPort  = 8428
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.grafana
  ]
}

