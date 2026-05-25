variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "gitops-playground"
}

variable "kind_node_image" {
  description = "kind node image — controls the Kubernetes version (see https://github.com/kubernetes-sigs/kind/releases)"
  type        = string
  default     = "kindest/node:v1.32.2"
}

variable "wait_for_ready" {
  description = "Block until the cluster control plane is ready before proceeding"
  type        = bool
  default     = true
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "9.5.15"
}
