# Kubernetes namespace for Grafana
resource "kubernetes_namespace" "grafana" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      name = var.monitoring_namespace
    }
  }

  depends_on = [module.eks]
}

# ConfigMap for Grafana dashboards
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.grafana.metadata[0].name
  }

  data = {
    "aztec-workflow-dashboard.json" = file("${path.module}/grafana/provisioning/dashboards/aztec-workflow-dashboard.json")
    "dashboard-provider.yml"        = file("${path.module}/grafana/provisioning/dashboards/dashboard-provider.yml")
  }

  depends_on = [kubernetes_namespace.grafana]
}

# Grafana Helm Chart
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "7.3.7"
  namespace  = kubernetes_namespace.grafana.metadata[0].name
  timeout    = 600  # Increase timeout to 10 minutes for PVC provisioning

  values = [
    yamlencode({
      replicas = var.grafana_replicas

      adminUser     = var.grafana_admin_user
      adminPassword = var.grafana_admin_password

      service = {
        type = "LoadBalancer"
        port = 80
        targetPort = 3000
      }

      serviceAccount = {
        create = true
      }

      persistence = {
        enabled = false  # Enable persistence to preserve dashboards and configs
        # size    = "10Gi"
        # storageClassName = "gp2"  # Use gp2 storage class (EBS volumes)
      }

      # Configure datasources
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "VictoriaMetrics"
              type      = "prometheus"
              access    = "proxy"
              url       = "http://victoriametrics-victoria-metrics-single-server:${var.victoriametrics_port}"
              isDefault = true
              editable  = true
              jsonData = {
                httpMethod = "POST"
                queryLanguage = "promql"
              }
            }
          ]
        }
      }

      # Resource limits
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }

      # Security context
      securityContext = {
        runAsUser  = 472
        runAsGroup = 472
        fsGroup    = 472
      }

      # Mount dashboards from ConfigMap
      extraVolumes = [
        {
          name = "grafana-dashboards"
          configMap = {
            name = kubernetes_config_map.grafana_dashboards.metadata[0].name
          }
        }
      ]

      extraVolumeMounts = [
        {
          name      = "grafana-dashboards"
          mountPath = "/etc/grafana/provisioning/dashboards"
          readOnly  = true
        }
      ]
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.grafana,
    helm_release.victoriametrics,
    kubernetes_config_map.grafana_dashboards
  ]
}

# Data source to get Grafana service for load balancer URL
data "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.grafana.metadata[0].name
  }

  depends_on = [helm_release.grafana]
}

