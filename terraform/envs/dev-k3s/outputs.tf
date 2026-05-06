output "namespaces" {
  description = "Managed namespaces in the dev k3s cluster."
  value       = module.namespaces.namespaces
}
