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

variable "ssh_source_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_shape" {
  type = string
  default = "VM.Standard.E2.1.Micro"
}

variable "tailscale_auth_key" {
  type = string
  sensitive = true
}