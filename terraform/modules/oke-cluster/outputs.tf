output "cluster_id" {
  description = "OKE cluster ID."
  value       = oci_containerengine_cluster.this.id
}

output "node_pool_id" {
  description = "OKE node pool ID."
  value       = oci_containerengine_node_pool.this.id
}
