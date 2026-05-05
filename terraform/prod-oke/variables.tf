variable "region" {
  description = "OCI region for OKE resources."
  type        = string
  default     = "ap-chuncheon-1"
}

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
  default     = "ocid1.compartment.oc1..replace-me"
}

variable "kubeconfig_path" {
  description = "Path to OKE kubeconfig for kubernetes/helm providers."
  type        = string
  default     = "~/.kube/config"
}

variable "cluster_name" {
  description = "OKE cluster name."
  type        = string
  default     = "cba-prod-oke"
}

variable "kubernetes_version" {
  description = "Kubernetes version for OKE cluster."
  type        = string
  default     = "v1.31.1"
}
