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

output "reserved_public_ip_id" {
  description = "Reserved public IP OCID when enabled."
  value       = try(oci_core_public_ip.lb_reserved[0].id, null)
}

output "reserved_public_ip_address" {
  description = "Reserved public IP address when enabled."
  value       = try(oci_core_public_ip.lb_reserved[0].ip_address, null)
}
