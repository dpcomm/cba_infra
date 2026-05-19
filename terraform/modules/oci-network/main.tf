resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = coalesce(var.vcn_display_name, "${var.name_prefix}-vcn")
  dns_label      = var.vcn_dns_label
  freeform_tags  = var.common_tags
}

data "oci_core_services" "all_region_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-igw"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = var.common_tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-nat"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = var.common_tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-sgw"
  vcn_id         = oci_core_vcn.this.id
  freeform_tags  = var.common_tags

  services {
    service_id = data.oci_core_services.all_region_services.services[0].id
  }
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-public-rt"
  freeform_tags  = var.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-private-rt"
  freeform_tags  = var.common_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  route_rules {
    destination       = data.oci_core_services.all_region_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-public-sl"
  freeform_tags  = var.common_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    description = "Allow OKE worker nodes to reach the Kubernetes API endpoint."
    protocol    = "6"
    source      = var.private_subnet_cidr

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    description = "Allow OKE worker nodes to reach the Kubernetes control plane."
    protocol    = "6"
    source      = var.private_subnet_cidr

    tcp_options {
      min = 12250
      max = 12250
    }
  }

  ingress_security_rules {
    description = "Allow OKE path discovery from worker nodes."
    protocol    = "1"
    source      = var.private_subnet_cidr

    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-private-sl"
  freeform_tags  = var.common_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr
  }

  ingress_security_rules {
    description = "Allow OKE worker node path discovery."
    protocol    = "1"
    source      = "0.0.0.0/0"

    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_network_security_group" "mysql" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-mysql-nsg"
  freeform_tags  = var.common_tags
}

resource "oci_core_network_security_group_security_rule" "mysql_from_private_subnet" {
  network_security_group_id = oci_core_network_security_group.mysql.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.private_subnet_cidr
  source_type               = "CIDR_BLOCK"
  description               = "Allow MySQL from private application subnet."

  tcp_options {
    destination_port_range {
      min = 3306
      max = 3306
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = coalesce(var.public_subnet_display_name, "${var.name_prefix}-public-subnet")
  dns_label                  = var.public_subnet_dns_label
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = var.common_tags
}

resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.private_subnet_cidr
  display_name               = coalesce(var.private_subnet_display_name, "${var.name_prefix}-private-subnet")
  dns_label                  = var.private_subnet_dns_label
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true
  freeform_tags              = var.common_tags
}

resource "oci_core_public_ip" "lb_reserved" {
  count = var.create_reserved_public_ip ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-lb-public-ip"
  lifetime       = "RESERVED"
  freeform_tags  = var.common_tags
}
