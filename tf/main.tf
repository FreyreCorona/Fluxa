terraform {
    required_version = ">= 1.15.3"
    required_providers {
      oci = {
        source = "oracle/oci"
        version = ">= 8.14"
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

/* Instances*/

module "fluxa_instance_01" {
  source = "./modules/oci_micro_instance"
  compartment_id = var.compartment_id
  subnet_id = oci_core_subnet.fluxa_vcn_subnet.id
  display_name = "worker-01"
  ssh_public_key = var.ssh_public_key
}

output "worker_public_ip" {
  value = module.fluxa_instance_01.public_ip
}

module "fluxa_instance_02" {
  source = "./modules/oci_micro_instance"
  compartment_id = var.compartment_id
  subnet_id = oci_core_subnet.fluxa_vcn_subnet.id
  display_name = "edge-01"
  ssh_public_key = var.ssh_public_key
}

output "edge_public_ip" {
  value = module.fluxa_instance_02.public_ip
}

output "generated_private_key" {
  value     = module.fluxa_instance_01.generated_private_key_pem
  sensitive = true
}