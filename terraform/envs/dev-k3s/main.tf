module "namespaces" {
  source = "../../modules/k8s-namespaces"

  namespaces = {
    "cba-dev" = {
      labels = {
        "app.kubernetes.io/part-of" = "cba-connect"
        "environment"               = "dev"
      }
    }
    "monitoring" = {
      labels = {
        "environment" = "dev"
      }
    }
  }
}
