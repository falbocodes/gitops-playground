resource "kind_cluster" "this" {
  name           = var.cluster_name
  node_image     = var.kind_node_image
  wait_for_ready = var.wait_for_ready

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  depends_on = [kind_cluster.this]

  values = [
    yamlencode({
      dex = {
        enabled = false
      }
      configs = {
        params = {
          "server.insecure" = "true"
        }
      }
      server = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]
}
