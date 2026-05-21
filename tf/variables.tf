variable "ssh_public_key" {
  type = string
}

variable "private_key_path" {
  type = string
}

variable "fingerprint" {
  type = string
}

variable "user_ocid" {
  type = string
}

variable "tenancy_ocid" {
   type = string
}

variable "compartment_id" {
  type = string
}

variable "region" {
    type = string
}

variable "instance_shape" {
  type = string
  default = "VM.Standard.E2.1.Micro"
}

data "oci_identity_availability_domain" "Fluxa_ad" {
  compartment_id = var.compartment_id
  ad_number = 1
}