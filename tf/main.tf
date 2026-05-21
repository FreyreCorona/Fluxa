terraform {
    required_version = ">= 1.15.3"
    required_providers {
      oci = {
        source = "oracle/oci"
        version = ">= 8.14"
      }
      tls ={
        source = "hashicorp/tls"
        version = ">= 4.0"
      }
    }
}

provider "oci" {
    user_ocid = var.user_ocid
    tenancy_ocid = var.tenancy_ocid
    region = var.region
    fingerprint = var.fingerprint
    private_key_path = var.private_key_path
}

/* Network */
resource "oci_core_virtual_network" "fluxa_vcn" {
  compartment_id = var.compartment_id
  cidr_block = "10.0.0.0/16"
  display_name = "Fluxa_vcn"
  dns_label = "fluxaVcn"
}

resource "oci_core_subnet" "fluxa_vcn_subnet" {
  compartment_id = var.compartment_id
  cidr_block = "10.0.20.0/24"
  display_name = "Fluxa_subnet"
  dns_label = "fluxaSubnet"
  vcn_id = oci_core_virtual_network.fluxa_vcn.id
  route_table_id = oci_core_route_table.fluxa_route_table.id
  security_list_ids = [oci_core_security_list.fluxa_security_list.id]
  dhcp_options_id   = oci_core_virtual_network.fluxa_vcn.default_dhcp_options_id
}

resource "oci_core_security_list" "fluxa_security_list" {
  compartment_id = var.compartment_id
  vcn_id = oci_core_virtual_network.fluxa_vcn.id
  display_name = "FluxaSecurityList"

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

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
}

resource "oci_core_internet_gateway" "fluxa_internet_gateway" {
  compartment_id = var.compartment_id
  display_name   = "FluxaIG"
  vcn_id         = oci_core_virtual_network.fluxa_vcn.id
}

resource "oci_core_route_table" "fluxa_route_table" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.fluxa_vcn.id
  display_name   = "FluxaRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.fluxa_internet_gateway.id
  }
}

/* Instances */

# See https://docs.oracle.com/iaas/images/

data "oci_core_images" "Fluxa_images" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "worker-01" {
  availability_domain = data.oci_identity_availability_domain.Fluxa_ad.name
  compartment_id = var.compartment_id
  display_name = "worker-01"
  shape = var.instance_shape
  

  create_vnic_details {
    assign_public_ip = true
    subnet_id = oci_core_subnet.fluxa_vcn_subnet.id
  }

  source_details {
    source_type = "image"
    source_id = data.oci_core_images.Fluxa_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = (var.ssh_public_key != "") ? var.ssh_public_key : tls_private_key.Fluxa_ssh_key.public_key_openssh
  }
}

resource "oci_core_instance" "edge-01" {
  availability_domain = data.oci_identity_availability_domain.Fluxa_ad.name
  compartment_id = var.compartment_id
  display_name = "edge-01"
  shape = var.instance_shape

  create_vnic_details {
    assign_public_ip = true
    subnet_id = oci_core_subnet.fluxa_vcn_subnet.id
  }

  source_details {
    source_type = "image"
    source_id = data.oci_core_images.Fluxa_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = (var.ssh_public_key != "") ? var.ssh_public_key : tls_private_key.Fluxa_ssh_key.public_key_openssh
  }
}

resource "tls_private_key" "Fluxa_ssh_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

output "generated_private_key_pem" {
  value     = (var.ssh_public_key != "") ? var.ssh_public_key : tls_private_key.Fluxa_ssh_key.private_key_pem
  sensitive = true
}