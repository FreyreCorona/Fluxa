terraform {
  required_providers {
    oci = {
        source = "oracle/oci"
        version = ">= 8.15"
    }
    tls = {
        source = "hashicorp/tls"
        version = "4.0"
    }
  }
}

data "oci_core_images" "module_images" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

data "oci_identity_availability_domain" "Fluxa_ad" {
  compartment_id = var.compartment_id
  ad_number = 1
}

resource "oci_core_instance" "module_instance" {
  availability_domain = data.oci_identity_availability_domain.Fluxa_ad.name
  compartment_id = var.compartment_id
  display_name = var.display_name
  shape = var.instance_shape
  
  create_vnic_details {
    assign_public_ip = true
    subnet_id = var.subnet_id
  }

  source_details {
    source_type = "image"
    source_id = data.oci_core_images.module_images.images[0].id
  }

  metadata = {
    ssh_authorized_keys = (var.ssh_public_key != "") ? var.ssh_public_key : tls_private_key.module_ssh_key.public_key_openssh
    user_data = base64encode(var.cloudInit_script)
  }
}

resource "tls_private_key" "module_ssh_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}
