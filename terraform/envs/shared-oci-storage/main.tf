module "object_storage" {
  source = "../../modules/oci-object-storage"

  compartment_ocid = var.compartment_ocid
  common_tags      = var.common_tags
  buckets = {
    "cba-connect-dev" = {
      environment = "dev"
      versioning  = "Enabled"
    }
    "cba-connect-prod" = {
      environment = "prod"
      versioning  = "Enabled"
    }
  }
}
