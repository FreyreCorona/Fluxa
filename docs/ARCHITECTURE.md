# Platform Architecture

Estado actual:
- 2 nodos AMD Micro (Oracle Always Free)
- 1 futuro nodo ARM A1 (pendiente disponibilidad)
- edge stateless
- control + DB en mismo nodo (1 GB RAM — ajustado)
- k3s como runtime substrate
- Tailscale mesh networking
- GitHub-centric CI/CD
- Terraform + CloudInit (sin Ansible)
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
               |     edge-01            |  ← stateless
               |  AMD Micro · 1 GB RAM  |  Oracle Always Free
               |  Traefik · fail2ban    |
               +------------------------+
                           |
                           | Tailscale
                           v
               +------------------------+
               |    control-01          |  ← control + DB + observabilidad
               |  AMD Micro · 1 GB RAM  |  Oracle Always Free
               |  k3s server, PostgreSQL|
               |  VictoriaMetrics       |
               |  Grafana, UptimeKuma   |
               +------------------------+
                           |
          +----------------+----------------+
          |                                  |
          v                                  v
   +------------------+             +------------------+
   |   worker-01      |             |  Future workers   |
   |  ARM A1 (futuro) |             |  (más ARM A1)     |
   |  12 GB RAM       |             |                   |
   |  k3s agent       |             |                   |
   +------------------+             +------------------+
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

## Layer 2 — Control Plane

Nodo: `control-01` (AMD Micro, 1 GB RAM)

Propósito: administración del cluster, DB, observabilidad.

Servicios:
- k3s server
- PostgreSQL
- VictoriaMetrics + Grafana
- UptimeKuma
- OracleCloudAgent (métricas OCI)

Limitación: 1 GB RAM forzó a PostgreSQL y k3s server a cohabitar.
Ajustes: PostgreSQL shared_buffers reducido, k3s sin telemetría.
Migrar a ARM A1 cuando esté disponible.

---

## Layer 3 — Runtime

Nodo: `worker-01` (ARM A1 — futuro)

Propósito: ejecutar workloads clientes.

Servicios:
- k3s agent
- runtime agent
- metrics exporter

Hasta obtener ARM A1, los workloads corren en control-01 como nodo k3s adicional.

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
- control-01: solo Tailscale
- worker-01: solo Tailscale
- Firewall OCI en VCN + iptables locales

---

# Provisioning

```text
terraform apply
    ↓
Oracle crea instancias + cloud-init
    ↓
CloudInit ejecuta script de bootstrap
    ├── Tailscale join
    ├── Docker install
    ├── k3s install (server o agent)
    ├── Traefik (solo edge)
    ├── PostgreSQL (solo control)
    ├── VictoriaMetrics + Grafana (solo control)
    └── UptimeKuma (solo control)
    ↓
Nodo listo — sin SSH posterior
```

Sin Ansible. Sin dependencia de máquina local.

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
- 2 AMD Micro: edge-01 + control-01
- Terraform + CloudInit funcional
- PostgreSQL + k3s server en control-01
- Traefik en edge-01
- OCI Vault para secrets
- OCI Monitoring + VictoriaMetrics
- GitHub Actions para deploys

## Fase 2 (con ARM A1)
- worker-01 dedicado con ARM A1
- Migrar workloads a worker-01
- Más RAM para PostgreSQL y k3s
- Separar control e infra si es necesario

## Fase 3 (con clientes)
- Múltiples workers ARM
- Edge redundancy
- Autoscaling
- Multi-tenancy

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
