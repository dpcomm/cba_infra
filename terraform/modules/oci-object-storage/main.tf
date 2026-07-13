data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "this" {
  for_each = var.buckets

  compartment_id        = var.compartment_ocid
  namespace             = data.oci_objectstorage_namespace.this.namespace
  name                  = each.key
  access_type           = "NoPublicAccess"
  storage_tier          = "Standard"
  versioning            = each.value.versioning
  auto_tiering          = "Disabled"
  object_events_enabled = false
  freeform_tags = merge(var.common_tags, {
    environment = each.value.environment
  })
}
