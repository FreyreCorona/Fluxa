# Node Roles

Todos los nodos:
- pertenecen a la misma red Tailscale
- ejecutan OracleCloudAgent para métricas y logs OCI
- utilizan OCI Vault para secretos
- priorizan aislamiento entre planos de responsabilidad

---

# EDGE NODE — `edge-01`

Shape: `VM.Standard.E2.1.Micro` (1/8 OCPU, 1 GB RAM)
Provider: Oracle Always Free
Provisioning: Terraform + CloudInit

Rol: ingress stateless

Servicios:
- Traefik (reverse proxy, TLS, dashboards)
- fail2ban
- OracleCloudAgent

Networking:
- público: 80, 443
- privado: ninguno
- Tailscale para llegar a worker-01 e infra-01

Notas:
- sin bases de datos, sin k3s, sin workloads
- reemplazable sin perder estado

CloudInit: `terraform/cloud-init/edge-01.sh.tpl`

---

# WORKER NODE — `worker-01`

Shape: `VM.Standard.E2.1.Micro` (1/8 OCPU, 1 GB RAM)
Provider: Oracle Always Free
Provisioning: Terraform + CloudInit

Rol: control plane + base de datos + observabilidad + workloads temporales

Servicios:
- k3s server (control plane, también schedulea pods)
- PostgreSQL 17 (tuneado: shared_buffers=256MB, max_connections=20)
- VictoriaMetrics + Grafana
- UptimeKuma
- OracleCloudAgent

Networking:
- sin IP pública
- Tailscale
- PostgreSQL y k3s API solo via Tailscale

Notas:
- 1 GB RAM es ajustado. PostgreSQL con configuración mínima.
- k3s sin `--disable-agent`: este nodo también corre workloads.
- Al obtener worker-02 (ARM A1), los workloads se migran y worker-01 queda solo como control.

CloudInit: `terraform/cloud-init/worker-01.sh.tpl`

---

# INFRA NODE — `infra-01`

Shape: Físico (Atom, 4C/24G)
Provider: Physical (home)
Provisioning: Manual + scripts legacy

Rol: servicios internos legacy + CI/CD + backups

Servicios actuales:
- Gitea (puerto 3000) — deprecating, migrando a GitHub
- Docker Registry (puerto 5000) — deprecating, migrando a GHCR
- CI runners
- Backups
- OracleCloudAgent

Integración OCI:
- OracleCloudAgent instalado para enviar métricas a OCI Monitoring
- Logs enviados a OCI Logging via cloud agent
- Secrets leídos desde OCI Vault (OCI CLI + API key)
- OCI Email Delivery como SMTP relay para notificaciones

Networking:
- solo Tailscale (sin exponer puertos)
- se conecta a OCI services via internet (autenticado con API key)

Futuro:
- migrar servicios restantes a Oracle
- reemplazar con instancia Oracle (ARM A1 o AMD)

---

# WORKER-02 (futuro) — `worker-02`

Shape: `VM.Standard.A1.Flex` (ARM, 12 GB RAM)
Provider: Oracle Always Free (pendiente disponibilidad)
Provisioning: Terraform + CloudInit

Rol: runtime de workloads dedicado

Servicios:
- k3s agent
- runtime agent
- OracleCloudAgent

Networking:
- sin IP pública
- solo Tailscale

Notas:
- Al activarlo, worker-01 deja de schedulear workloads
- k3s taint en worker-01 para evitar scheduling de pods

---

# Tabla Resumen

| Nodo      | Proveedor       | Shape             | RAM  | Público | Rol principal                      |
|-----------|-----------------|--------------------|------|---------|------------------------------------|
| edge-01   | Oracle          | E2.1.Micro         | 1 GB | Sí      | Traefik + fail2ban                 |
| worker-01 | Oracle          | E2.1.Micro         | 1 GB | No      | k3s + PG + metrics + workloads     |
| infra-01  | Physical (home) | —                  | 24 GB| No      | Servicios legacy + CI/CD + backups |
| worker-02 | Oracle (futuro) | A1.Flex (ARM)      | 12 GB| No      | Workloads dedicados                |
