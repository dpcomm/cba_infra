module "namespaces" {
  source = "../../modules/k8s-namespaces"

  namespaces = {
    "cba-connect-dev" = {
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
