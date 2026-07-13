variable "compartment_ocid" {
  description = "OCI compartment OCID that owns the buckets."
  type        = string
}

variable "buckets" {
  description = "Private application buckets keyed by bucket name."
  type = map(object({
    environment = string
    versioning  = string
  }))
}

variable "common_tags" {
  description = "Freeform tags applied to every bucket."
  type        = map(string)
  default     = {}
}
