variable "region" {
  description = "OCI region for OKE resources."
  type        = string
  default     = "ap-chuncheon-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "OCI region은 'ap-chuncheon-1' 같은 형식이어야 합니다."
  }
}

variable "compartment_ocid" {
  description = "Target OCI compartment OCID."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.(compartment|tenancy)\\.", var.compartment_ocid))
    error_message = "compartment_ocid는 'ocid1.compartment.' 또는 'ocid1.tenancy.'로 시작해야 합니다."
  }
}

variable "cluster_name" {
  description = "OKE cluster name."
  type        = string
  default     = "cba-connect-oke"

  validation {
    condition     = length(var.cluster_name) >= 3 && length(var.cluster_name) <= 63
    error_message = "cluster_name은 3~63자 사이여야 합니다."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for OKE cluster."
  type        = string
  default     = "v1.35.2"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version은 'v1.31.1' 같은 시맨틱 버전 형식이어야 합니다."
  }
}

variable "vcn_cidr" {
  description = "VCN CIDR for the prod OKE network."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.vcn_cidr, 0))
    error_message = "vcn_cidr는 유효한 CIDR 블록이어야 합니다 (예: 10.20.0.0/16)."
  }
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR for ingress and public endpoints."
  type        = string
  default     = "10.20.10.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "public_subnet_cidr는 유효한 CIDR 블록이어야 합니다."
  }
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR for worker nodes."
  type        = string
  default     = "10.20.20.0/24"

  validation {
    condition     = can(cidrhost(var.private_subnet_cidr, 0))
    error_message = "private_subnet_cidr는 유효한 CIDR 블록이어야 합니다."
  }
}

variable "availability_domain" {
  description = "Availability domain used by the OKE node pool."
  type        = string
}

variable "node_image_id" {
  description = "Worker node image OCID."
  type        = string

  validation {
    condition     = can(regex("^ocid1\\.image\\.", var.node_image_id))
    error_message = "node_image_id는 'ocid1.image.'으로 시작해야 합니다."
  }
}

variable "node_ssh_public_key" {
  description = "SSH public key content for worker nodes."
  type        = string
  sensitive   = true
}

variable "node_pool_size" {
  description = "Worker node count."
  type        = number
  default     = 2

  validation {
    condition     = var.node_pool_size >= 1 && var.node_pool_size <= 10
    error_message = "node_pool_size는 1~10 사이여야 합니다."
  }
}

variable "node_shape" {
  description = "OCI shape for worker nodes."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "node_shape_ocpus" {
  description = "OCPUs for worker nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.node_shape_ocpus >= 1 && var.node_shape_ocpus <= 80
    error_message = "node_shape_ocpus는 1~80 사이여야 합니다."
  }
}

variable "node_shape_memory_gbs" {
  description = "Memory size in GB for worker nodes."
  type        = number
  default     = 12

  validation {
    condition     = var.node_shape_memory_gbs >= 1 && var.node_shape_memory_gbs <= 512
    error_message = "node_shape_memory_gbs는 1~512 사이여야 합니다."
  }
}

variable "pods_cidr" {
  description = "Pod CIDR for OKE."
  type        = string
  default     = "10.244.0.0/16"

  validation {
    condition     = can(cidrhost(var.pods_cidr, 0))
    error_message = "pods_cidr는 유효한 CIDR 블록이어야 합니다."
  }
}

variable "services_cidr" {
  description = "Service CIDR for OKE."
  type        = string
  default     = "10.96.0.0/16"

  validation {
    condition     = can(cidrhost(var.services_cidr, 0))
    error_message = "services_cidr는 유효한 CIDR 블록이어야 합니다."
  }
}

variable "create_reserved_public_ip" {
  description = "Whether to reserve a public IP for the ingress load balancer."
  type        = bool
  default     = true
}

# ── Common Tags ──
# 모든 OCI 리소스에 일관되게 부여되는 태그입니다.
# 비용 추적, 리소스 관리, 환경 식별에 활용됩니다.
variable "common_tags" {
  description = "Freeform tags applied to all OCI resources for cost tracking and resource management."
  type        = map(string)
  default = {
    "project"     = "cba-connect"
    "environment" = "prod"
    "managed-by"  = "terraform"
  }
}
