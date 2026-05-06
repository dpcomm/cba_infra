variable "compartment_ocid" {
  description = "OCI compartment OCID."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for OCI network resource names."
  type        = string
  default     = "cba-prod"
}

variable "vcn_cidr" {
  description = "VCN CIDR block."
  type        = string
}

variable "vcn_dns_label" {
  description = "VCN DNS label."
  type        = string
  default     = "cbavcn"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block."
  type        = string
}

variable "public_subnet_dns_label" {
  description = "Public subnet DNS label."
  type        = string
  default     = "publicsubnet"
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block."
  type        = string
}

variable "private_subnet_dns_label" {
  description = "Private subnet DNS label."
  type        = string
  default     = "privatesubnet"
}

variable "create_reserved_public_ip" {
  description = "Whether to reserve a public IP for the ingress load balancer cutover."
  type        = bool
  default     = true
}
