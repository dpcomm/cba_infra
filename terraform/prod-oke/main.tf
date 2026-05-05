# Skeleton only: expand this with VCN/Subnet/NSG/OKE resources later.
# Keep sensitive values out of Terraform files/state (use OCI auth mechanisms).

resource "kubernetes_namespace" "cba_prod" {
  metadata {
    name = "cba-prod"
    labels = {
      "app.kubernetes.io/part-of" = "cba-connect"
      "environment"               = "prod"
    }
  }
}
