variable "kubeconfig_path" {
  description = "Path to the kubeconfig used for the dev k3s cluster."
  type        = string
  default     = "~/.kube/config"
}
