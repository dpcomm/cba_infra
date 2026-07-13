output "namespace" {
  description = "OCI Object Storage namespace containing the buckets."
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "bucket_names" {
  description = "Application bucket names keyed by environment."
  value       = keys(oci_objectstorage_bucket.this)
}
