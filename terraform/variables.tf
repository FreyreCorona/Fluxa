# ── OCI Auth ────────────────────────────────────────────────

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

# ── Networking ─────────────────────────────────────────────

variable "vcn_cidr" {
  description = "CIDR block for the Fluxa VCN"
  type        = string
  default     = "10.0.0.0/16"
}

# ── Instance Shapes ────────────────────────────────────────

variable "edge_shape" {
  description = "OCI instance shape for edge-01"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "control_shape" {
  description = "OCI instance shape for control-01"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

variable "worker_shape" {
  description = "OCI instance shape for worker-01 (ARM A1 when available)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

# ── Secrets (pasados a cloud-init) ─────────────────────────

variable "tailscale_key" {
  description = "Tailscale pre-auth key"
  type        = string
  sensitive   = true
}

variable "k3s_token" {
  description = "k3s cluster token"
  type        = string
  sensitive   = true
}

variable "pg_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "grafana_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "acme_email" {
  description = "Email for Let's Encrypt certificate registration"
  type        = string
  default     = "admin@fluxa.cloud"
}

variable "domain" {
  description = "Root domain for the platform"
  type        = string
  default     = "fluxa.cloud"
}

variable "traefik_users" {
  description = "Basic auth users for Traefik dashboard (htpasswd format)"
  type        = string
  sensitive   = true
  default     = ""
}
