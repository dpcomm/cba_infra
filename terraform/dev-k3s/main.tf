resource "kubernetes_namespace" "cba_dev" {
  metadata {
    name = "cba-dev"
    labels = {
      "app.kubernetes.io/part-of" = "cba-connect"
      "environment"               = "dev"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "environment" = "dev"
    }
  }
}
