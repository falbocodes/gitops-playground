output "kubeconfig" {
  description = "Kubeconfig content for the kind cluster"
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = helm_release.argocd.namespace
}
