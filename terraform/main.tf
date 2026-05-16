terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "oci" {
  region = var.region
}

locals {
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid
  ad             = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.edge_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ── Networking ──────────────────────────────────────────────

resource "oci_core_vcn" "fluxa" {
  compartment_id = local.compartment_id
  display_name   = "fluxa-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "fluxa"
}

resource "oci_core_internet_gateway" "fluxa" {
  compartment_id = local.compartment_id
  display_name   = "fluxa-igw"
  vcn_id         = oci_core_vcn.fluxa.id
}

resource "oci_core_route_table" "public" {
  compartment_id = local.compartment_id
  display_name   = "fluxa-rt-public"
  vcn_id         = oci_core_vcn.fluxa.id
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.fluxa.id
  }
}

# ── Security List ───────────────────────────────────────────

resource "oci_core_security_list" "fluxa" {
  compartment_id = local.compartment_id
  display_name   = "fluxa-sl"
  vcn_id         = oci_core_vcn.fluxa.id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH desde cualquier lado
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      max = 22
      min = 22
    }
  }

  # HTTP/HTTPS público (edge-01)
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      max = 80
      min = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      max = 443
      min = 443
    }
  }

  # ICMP interno VCN
  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr
  }
}

resource "oci_core_subnet" "fluxa" {
  compartment_id    = local.compartment_id
  display_name      = "fluxa-subnet"
  vcn_id            = oci_core_vcn.fluxa.id
  cidr_block        = var.vcn_cidr
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.fluxa.id]
  dns_label         = "fluxa"
}

# ── SSH key pair ────────────────────────────────────────────

resource "tls_private_key" "fluxa" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "ssh_private" {
  content         = tls_private_key.fluxa.private_key_openssh
  filename        = pathexpand("~/.ssh/fluxa_ed25519")
  file_permission = "0600"
}

resource "local_sensitive_file" "ssh_public" {
  content         = tls_private_key.fluxa.public_key_openssh
  filename        = pathexpand("~/.ssh/fluxa_ed25519.pub")
  file_permission = "0644"
}

# ── edge-01 ──────────────────────────────────────────────

resource "oci_core_instance" "edge_01" {
  compartment_id      = local.compartment_id
  availability_domain = local.ad
  display_name        = "edge-01"
  shape               = var.edge_shape

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.fluxa.id
    display_name     = "edge-01-vnic"
    assign_public_ip = true
    hostname_label   = "edge-01"
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.fluxa.public_key_openssh
    user_data           = base64encode(templatefile("${path.module}/cloud-init/edge-01.sh.tpl", {
      tailscale_key  = var.tailscale_key
      acme_email     = var.acme_email
      domain         = var.domain
      traefik_users  = var.traefik_users
    }))
  }

  preserve_boot_volume = false
}

# ── control-01 ─────────────────────────────────────────────

resource "oci_core_instance" "control_01" {
  compartment_id      = local.compartment_id
  availability_domain = local.ad
  display_name        = "control-01"
  shape               = var.control_shape

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.fluxa.id
    display_name     = "control-01-vnic"
    assign_public_ip = false
    hostname_label   = "control-01"
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.fluxa.public_key_openssh
    user_data           = base64encode(templatefile("${path.module}/cloud-init/control-01.sh.tpl", {
      tailscale_key     = var.tailscale_key
      pg_password       = var.pg_password
      k3s_token         = var.k3s_token
      grafana_password  = var.grafana_password
    }))
  }

  preserve_boot_volume = false
}

# ── worker-01 (placeholder para ARM A1 futuro) ──────────────
