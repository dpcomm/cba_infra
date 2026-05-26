resource "kubernetes_namespace" "this" {
  for_each = var.namespaces

  lifecycle {
    prevent_destroy = true
  }

  metadata {
    name   = each.key
    labels = each.value.labels
  }
}
