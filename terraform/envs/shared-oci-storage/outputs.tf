output "object_storage_namespace" {
  description = "OCI Object Storage namespace."
  value       = module.object_storage.namespace
}

output "bucket_names" {
  description = "Created private application buckets."
  value       = module.object_storage.bucket_names
}
