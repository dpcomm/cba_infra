variable "compartment_ocid" {
  description = "OCI compartment OCID."
  type        = string
}

variable "cluster_name" {
  description = "OKE cluster name."
  type        = string
}

variable "environment" {
  description = "Environment label for worker nodes."
  type        = string
  default     = "prod"
}

variable "kubernetes_version" {
  description = "Kubernetes version for OKE resources."
  type        = string
}

variable "vcn_id" {
  description = "VCN ID for the OKE cluster."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID used by the control plane endpoint and load balancers."
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID used by worker nodes."
  type        = string
}

variable "pods_cidr" {
  description = "Pod CIDR for the cluster."
  type        = string
  default     = "10.244.0.0/16"
}

variable "services_cidr" {
  description = "Service CIDR for the cluster."
  type        = string
  default     = "10.96.0.0/16"
}

variable "availability_domain" {
  description = "Availability domain for the node pool placement."
  type        = string
}

variable "node_pool_size" {
  description = "Desired node count in the worker node pool."
  type        = number
  default     = 2
}

variable "node_shape" {
  description = "OCI shape for worker nodes."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "node_shape_ocpus" {
  description = "Number of OCPUs for flex worker nodes."
  type        = number
  default     = 2
}

variable "node_shape_memory_gbs" {
  description = "Memory size in GB for flex worker nodes."
  type        = number
  default     = 12
}

variable "node_image_id" {
  description = "OCI image OCID used by worker nodes."
  type        = string
}

variable "node_ssh_public_key" {
  description = "SSH public key content for worker nodes."
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Freeform tags applied to all OCI resources."
  type        = map(string)
  default     = {}
}
