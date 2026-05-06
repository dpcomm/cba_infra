resource "kubernetes_namespace" "this" {
  for_each = var.namespaces

  metadata {
    name   = each.key
    labels = each.value.labels
  }
}
