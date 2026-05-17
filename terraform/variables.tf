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

variable "worker_shape" {
  description = "OCI instance shape for worker-01 (E2.1.Micro for now, A1.Flex when available)"
  type        = string
  default     = "VM.Standard.E2.1.Micro"
}

# ── OCI Vault Secret OCIDs ──────────────────────────────────

variable "ocid_tailscale_secret" {
  description = "OCID of the Tailscale auth key secret in OCI Vault"
  type        = string
}

variable "ocid_postgres_secret" {
  description = "OCID of the PostgreSQL password secret in OCI Vault"
  type        = string
}

variable "ocid_k3s_secret" {
  description = "OCID of the k3s token secret in OCI Vault"
  type        = string
}

variable "ocid_grafana_secret" {
  description = "OCID of the Grafana admin password secret in OCI Vault"
  type        = string
}

# ── Config ─────────────────────────────────────────────────

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
