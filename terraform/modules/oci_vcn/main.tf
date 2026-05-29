terraform {
  required_providers {
    oci = {
        source = "oracle/oci"
        version = ">= 8.15"
    }
  }
}

resource "oci_core_virtual_network" "module_vcn" {
  compartment_id = var.compartment_id
  cidr_block = "10.0.0.0/16"    
  display_name = var.vcn_display_name
  dns_label = var.vcn_dns_label
}

resource "oci_core_subnet" "module_vcn_subnet" {
  compartment_id = var.compartment_id
  cidr_block = "10.0.20.0/24"
  display_name = var.subnet_display_name
  dns_label = var.subnet_dns_label
  vcn_id = oci_core_virtual_network.module_vcn.id
  route_table_id = oci_core_route_table.module_route_table.id
  security_list_ids = [oci_core_security_list.module_security_list.id]
  dhcp_options_id   = oci_core_virtual_network.module_vcn.default_dhcp_options_id
}

resource "oci_core_security_list" "module_security_list" {
  compartment_id = var.compartment_id
  vcn_id = oci_core_virtual_network.module_vcn.id
  display_name = var.sc_display_name

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.ssh_source_cidr

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "80"
      min = "80"
    }
  }
  ingress_security_rules {
    protocol = "1"
    source   = "10.0.0.0/16"
  }
  ingress_security_rules {
    protocol = "6" 
    source   = "10.0.0.0/16"
  }
}

resource "oci_core_internet_gateway" "module_internet_gateway" {
  compartment_id = var.compartment_id
  display_name   = var.IG_display_name
  vcn_id         = oci_core_virtual_network.module_vcn.id
}

resource "oci_core_route_table" "module_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.module_vcn.id
  display_name   = var.route_table_display_name

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.module_internet_gateway.id
  }
}
