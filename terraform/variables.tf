variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy"
  type        = string
  sensitive   = true
}

variable "user_ocid" {
  description = "OCID of the OCI user for API access"
  type        = string
  sensitive   = true
}

variable "fingerprint" {
  description = "Fingerprint of the OCI API key"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to the OCI API private key PEM file"
  type        = string
}

variable "region" {
  description = "OCI region"
  type        = string
  default     = "sa-saopaulo-1"
}

variable "compartment_ocid" {
  description = "Compartment OCID (defaults to root tenancy)"
  type        = string
  default     = ""
}

variable "vcn_cidr" {
  description = "CIDR block for the Fluxa VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_shape" {
  description = "OCI instance shape"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "instance_ocpus" {
  description = "Number of OCPUs per instance"
  type        = number
  default     = 1
}

variable "instance_memory_gb" {
  description = "Memory in GB per instance"
  type        = number
  default     = 1
}
