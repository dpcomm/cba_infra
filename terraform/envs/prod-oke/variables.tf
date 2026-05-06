variable "region" {
  description = "OCI region for OKE resources."
  type        = string
  default     = "ap-chuncheon-1"
}

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string
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

variable "vcn_cidr" {
  description = "VCN CIDR for the prod OKE network."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR for ingress and public endpoints."
  type        = string
  default     = "10.20.10.0/24"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR for worker nodes."
  type        = string
  default     = "10.20.20.0/24"
}

variable "availability_domain" {
  description = "Availability domain used by the OKE node pool."
  type        = string
}

variable "node_image_id" {
  description = "Worker node image OCID."
  type        = string
}

variable "node_ssh_public_key" {
  description = "SSH public key content for worker nodes."
  type        = string
}

variable "node_pool_size" {
  description = "Worker node count."
  type        = number
  default     = 3
}

variable "node_shape" {
  description = "OCI shape for worker nodes."
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "node_shape_ocpus" {
  description = "OCPUs for worker nodes."
  type        = number
  default     = 2
}

variable "node_shape_memory_gbs" {
  description = "Memory size in GB for worker nodes."
  type        = number
  default     = 16
}

variable "pods_cidr" {
  description = "Pod CIDR for OKE."
  type        = string
  default     = "10.244.0.0/16"
}

variable "services_cidr" {
  description = "Service CIDR for OKE."
  type        = string
  default     = "10.96.0.0/16"
}

variable "create_reserved_public_ip" {
  description = "Whether to reserve a public IP for the ingress load balancer."
  type        = bool
  default     = true
}
