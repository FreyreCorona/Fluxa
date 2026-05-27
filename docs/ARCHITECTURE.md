# Platform Architecture

Estado actual:
- 2 nodos AMD Micro en Oracle (edge-01 + worker-01)
- 1 nodo físico local (infra-01 — servicios legacy + CI/CD)
- 1 futuro nodo ARM A1 (worker-02, pendiente disponibilidad)
- edge stateless
- worker-01: control plane + DB + observabilidad + workloads
- infra-01: integrado con OCI services (Vault, Monitoring, Logging)
- k3s como runtime substrate
- Tailscale mesh networking
- GitHub-centric CI/CD
- Terraform + CloudInit
- OCI Vault, Monitoring, Logging, Email Delivery

Objetivo:
Construir un PaaS pequeño, modular y portable sobre Oracle Cloud Free Tier,
manteniendo separación clara entre edge, control plane y runtime.

---

# Filosofía de Diseño

La plataforma NO expone Kubernetes directamente al cliente.

Kubernetes/k3s es el runtime substrate actual.

El cliente solo necesita:
- Dockerfile válido
- GitHub repo
- k3s kubeconfig (vía GitHub Actions)

La plataforma abstrae:
- ingress (Traefik)
- TLS (automático)
- dominios
- observabilidad básica (VictoriaMetrics + OCI Monitoring)
- runtime (k3s)

---

# Topología (Always Free)

```text
                        Internet
                           |
                           v
                +------------------------+
                |      edge-01           |  ← stateless
                |  AMD Micro · 1 GB RAM  |  Oracle Always Free
                |  Traefik · fail2ban    |
                +------------------------+
                           |
                           | Tailscale
          +----------------+----------------+
          |                |                |
          v                v                v
+------------------+ +----------+ +------------------+
|   worker-01      | | infra-01 | | worker-02        |
| AMD Micro · 1 GB | | Físico   | | ARM A1 (futuro)  |
| k3s + PG + VM    | | Gitea    | | k3s agent        |
| Grafana + Kuma   | | Registry | | workloads ded.   |
| OracleCloudAgent | | Backups  | |                  |
+------------------+ +----------+ +------------------+
                          │ OCI Services (via API key)
                          ├── Vault → secrets
                          ├── Monitoring → métricas
                          ├── Logging → logs
                          └── Email → SMTP

```

---

# Capas

## Layer 1 — Edge

Nodo: `edge-01` (AMD Micro, 1 GB RAM)

Propósito: entrypoint público, stateless.

Servicios:
- Traefik (reverse proxy, TLS termination)
- fail2ban
- OracleCloudAgent (métricas OCI)

Sin bases de datos, sin control plane, sin workloads.

---

## Layer 2 — Control Plane + Runtime

Nodo: `worker-01` (AMD Micro, 1 GB RAM)

Propósito: control plane k3s, base de datos, observabilidad, y workloads temporales.

Servicios:
- k3s server (control plane + schedulea pods)
- PostgreSQL
- VictoriaMetrics + Grafana
- UptimeKuma
- OracleCloudAgent (métricas OCI)

Limitación: 1 GB RAM forzó a PostgreSQL y k3s server a cohabitar.
Ajustes: PostgreSQL shared_buffers=256MB, max_connections=20.

---

## Layer 3 — Infraestructura Interna

Nodo: `infra-01` (físico, casa)

Propósito: servicios legacy, CI/CD, backups.

Servicios:
- Gitea (deprecating → GitHub)
- Docker Registry (deprecating → GHCR)
- CI runners
- Backups
- OracleCloudAgent (métricas y logs a OCI)

Nota: no provisionado por Terraform. Integrado con OCI via API key.

---

## Layer 4 — Runtime Dedicado (futuro)

Nodo: `worker-02` (ARM A1 — futuro)

Propósito: ejecutar workloads clientes de forma aislada.

Servicios:
- k3s agent
- runtime agent
- metrics exporter

Al obtener este nodo, worker-01 deja de schedulear workloads.

---

# OCI Services Integration

## Vault

Almacena todos los secretos de la plataforma:
- PostgreSQL password
- Tailscale auth key
- k3s token
- Traefik dashboard credentials
- API keys de servicios

Acceso vía OCI SDK/CLI o montado en pods con OCI Secrets Store CSI Driver.

## Monitoring

Métricas de infraestructura out-of-the-box:
- CPU, RAM, disco, red por nodo
- OracleCloudAgent instalado por defecto
- Dashboards en OCI Console
- Alarms configurable via MQL

Usar para: estado de salud de nodos, alertas de disco/CPU.

## Logging

Logs centralizados de:
- syslog de cada nodo
- Traefik access logs
- k3s logs
- PostgreSQL logs

10 GB/mes gratuitos — suficiente para la escala actual.

## Email Delivery

SMTP relay para notificaciones:
- 3.000 emails/mes gratis
- Puerto 587 con STARTTLS
- Usar desde GitHub Actions o scripts de alerta

---

# Observabilidad (Dual)

| Qué monitorear       | Herramienta         | Razón                              |
|----------------------|---------------------|------------------------------------|
| Infra (CPU, RAM, disk)| OCI Monitoring     | Out-of-the-box, zero config        |
| k3s cluster metrics   | VictoriaMetrics    | Scrapeo nativo de exporters        |
| Traefik metrics       | VictoriaMetrics    | Prometheus format                  |
| Application metrics   | VictoriaMetrics    | Custom exporters                   |
| Uptime                | UptimeKuma         | HTTP checks externos               |
| Logs                  | OCI Logging        | Centralizado, sin stack ELK        |

---

# Networking

- Tailscale mesh entre todos los nodos
- edge-01: expone puertos 80/443 al público
- worker-01: solo Tailscale
- infra-01: solo Tailscale
- worker-02: solo Tailscale (futuro)
- Firewall OCI en VCN + iptables locales

---

# Provisioning

```text
# edge-01 y worker-01:
terraform apply
    ↓
Oracle crea instancias + cloud-init
    ↓
CloudInit ejecuta script de bootstrap
    ├── Tailscale join
    ├── Docker install
    ├── k3s install
    ├── Traefik (edge)
    ├── PostgreSQL (worker)
    ├── VictoriaMetrics + Grafana (worker)
    └── UptimeKuma (worker)
    ↓
Nodo listo — sin SSH posterior

# infra-01 (físico):
Configuración manual + OracleCloudAgent
Secrets desde OCI Vault via OCI CLI
```

---

# Deployment Flow

```text
cliente: git push
    ↓
GitHub Actions: build image → push GHCR
    ↓
GitHub Actions: kubectl apply (via kubeconfig almacenado en OCI Vault)
    ↓
k3s schedulea en worker-01
    ↓
Traefik detecta nuevo ingress → TLS automático
    ↓
application online
```

Sin Go API. k3s + Traefik + GitHub Actions resuelven el ciclo.

---

# Roadmap

## Fase 1 (ahora)
- edge-01 + worker-01 (AMD Micro)
- infra-01 físico + integración OCI services
- Terraform + CloudInit funcional
- PostgreSQL + k3s server en worker-01
- Traefik en edge-01
- OCI Vault, Monitoring, Logging
- GitHub Actions para deploys

## Fase 2 (con ARM A1)
- worker-02 dedicado con ARM A1
- Migrar workloads a worker-02
- worker-01 queda solo como control plane

## Fase 3
- Migrar infra-01 a Oracle
- Múltiples workers ARM
- Edge redundancy
- Autoscaling

---

# Principios

- Edge stateless
- Control plane separado del runtime
- Simplicidad operacional primero
- Sin herramientas externas (no Ansible, no Go API)
- Aprovechar servicios OCI gratuitos antes de self-hostear
- Observabilidad dual (OCI + VictoriaMetrics)
- Todo el provisioning en Terraform + CloudInit
- Evolución gradual, sin over-engineering
