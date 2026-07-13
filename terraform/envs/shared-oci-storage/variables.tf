variable "region" {
  description = "OCI region for Object Storage buckets."
  type        = string
  default     = "ap-chuncheon-1"
}

variable "compartment_ocid" {
  description = "OCI compartment OCID that owns the application buckets."
  type        = string
}

variable "common_tags" {
  description = "Freeform tags applied to all shared storage resources."
  type        = map(string)
  default = {
    project    = "cba-connect"
    managed-by = "terraform"
  }
}
