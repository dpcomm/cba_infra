output "vcn_id" {
  description = "Prod OKE VCN ID."
  value       = module.network.vcn_id
}

output "public_subnet_id" {
  description = "Public subnet ID used by ingress and the public API endpoint."
  value       = module.network.public_subnet_id
}

output "private_subnet_id" {
  description = "Private subnet ID used by worker nodes."
  value       = module.network.private_subnet_id
}

output "reserved_public_ip_address" {
  description = "Reserved public IP address for OCI load balancer cutover."
  value       = module.network.reserved_public_ip_address
}

output "cluster_id" {
  description = "OKE cluster ID."
  value       = module.oke_cluster.cluster_id
}

output "node_pool_id" {
  description = "OKE node pool ID."
  value       = module.oke_cluster.node_pool_id
}
