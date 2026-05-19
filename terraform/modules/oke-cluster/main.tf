resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = var.cluster_name
  vcn_id             = var.vcn_id
  freeform_tags      = var.common_tags

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = var.public_subnet_id
  }

  options {
    service_lb_subnet_ids = [var.public_subnet_id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    kubernetes_network_config {
      pods_cidr     = var.pods_cidr
      services_cidr = var.services_cidr
    }
  }
}

resource "oci_containerengine_node_pool" "this" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = "${var.cluster_name}-nodepool"
  node_shape         = var.node_shape
  freeform_tags      = var.common_tags

  initial_node_labels {
    key   = "environment"
    value = var.environment
  }

  node_config_details {
    placement_configs {
      availability_domain     = var.availability_domain
      capacity_reservation_id = var.capacity_reservation_id
      fault_domains           = var.fault_domains
      subnet_id               = var.private_subnet_id
    }

    size = var.node_pool_size
  }

  node_shape_config {
    memory_in_gbs = var.node_shape_memory_gbs
    ocpus         = var.node_shape_ocpus
  }

  node_source_details {
    image_id    = var.node_image_id
    source_type = "IMAGE"
  }

  ssh_public_key = var.node_ssh_public_key
}
