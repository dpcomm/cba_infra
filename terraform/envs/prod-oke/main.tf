module "network" {
  source = "../../modules/oci-network"

  compartment_ocid            = var.compartment_ocid
  name_prefix                 = "cba-connect"
  vcn_display_name            = "cba-connect-vcn"
  public_subnet_display_name  = "cba-connect-subnet"
  private_subnet_display_name = "cba-connect-private-subnet"
  vcn_cidr                    = var.vcn_cidr
  public_subnet_cidr          = var.public_subnet_cidr
  private_subnet_cidr         = var.private_subnet_cidr
  create_reserved_public_ip   = var.create_reserved_public_ip
  common_tags                 = var.common_tags
}

module "oke_cluster" {
  source = "../../modules/oke-cluster"

  compartment_ocid      = var.compartment_ocid
  cluster_name          = var.cluster_name
  environment           = "prod"
  kubernetes_version    = var.kubernetes_version
  vcn_id                = module.network.vcn_id
  public_subnet_id      = module.network.public_subnet_id
  private_subnet_id     = module.network.private_subnet_id
  pods_cidr             = var.pods_cidr
  services_cidr         = var.services_cidr
  availability_domain   = var.availability_domain
  node_pool_size        = var.node_pool_size
  node_shape            = var.node_shape
  node_shape_ocpus      = var.node_shape_ocpus
  node_shape_memory_gbs = var.node_shape_memory_gbs
  node_image_id         = var.node_image_id
  node_ssh_public_key   = var.node_ssh_public_key
  common_tags           = var.common_tags
}
