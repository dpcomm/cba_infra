output "vcn_id" {
  description = "VCN ID."
  value       = oci_core_vcn.this.id
}

output "public_subnet_id" {
  description = "Public subnet ID."
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet ID."
  value       = oci_core_subnet.private.id
}

output "mysql_nsg_id" {
  description = "Network security group ID for MySQL access from the private subnet."
  value       = oci_core_network_security_group.mysql.id
}

output "reserved_public_ip_id" {
  description = "Reserved public IP OCID when enabled."
  value       = try(oci_core_public_ip.lb_reserved[0].id, null)
}

output "reserved_public_ip_address" {
  description = "Reserved public IP address when enabled."
  value       = try(oci_core_public_ip.lb_reserved[0].ip_address, null)
}
