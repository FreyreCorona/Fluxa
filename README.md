# Fluxa — Modular PaaS

PaaS modular sobre Oracle Cloud Always Free.  
**2 nodos AMD Micro** (edge + control) + **futuro ARM A1** (worker).  
Todo provisionado con Terraform + CloudInit — sin Ansible.

---

## Stack

```
┌──────────────────────────────────────────────────────────────┐
│                        Internet                              │
│                            │                                 │
│                            v                                 │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  edge-01  (AMD Micro, 1 GB)  ← stateless             │    │
│  │  Traefik · fail2ban · OracleCloudAgent               │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │ Tailscale                          │
│                         v                                    │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  control-01  (AMD Micro, 1 GB)                       │    │
│  │  k3s server · PostgreSQL · VictoriaMetrics            │    │
│  │  Grafana · UptimeKuma                                │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                    │
│                         v                                    │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  worker-01  (ARM A1 — futuro)                        │    │
│  │  k3s agent · workloads                               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  OCI Services integrados:                                    │
│  ├── Vault → secrets (PostgreSQL, Tailscale, API keys)       │
│  ├── Monitoring → métricas de infra (CPU, RAM, disco)       │
│  ├── Logging → logs centralizados                           │
│  └── Email Delivery → SMTP (3.000/mes)                      │
└──────────────────────────────────────────────────────────────┘
```

---

## Deployment Flow

```text
git push
    ↓
GitHub Actions → build image → push GHCR
    ↓
kubectl apply (manual o GitHub Actions con kubeconfig)
    ↓
k3s scheduling → worker-01
    ↓
Traefik ingress update → TLS automático
    ↓
application online
```

Sin Go API. k3s + Traefik resuelven el deployment flow.

---

## Nodos

| Nodo      | Shape             | RAM  | Rol                          | Tipo      |
|-----------|-------------------|------|------------------------------|-----------|
| edge-01   | VM.Standard.E2.1.Micro | 1 GB | Ingress stateless      | Oracle    |
| control-01| VM.Standard.E2.1.Micro | 1 GB | Control plane + DB     | Oracle    |
| worker-01 | VM.Standard.A1.Flex*   | 12 GB| Runtime workloads      | Oracle    |

\* ARM A1 pendiente de disponibilidad. Mientras tanto, worker corre en el mismo control-01 como nodo k3s.

---

## Provisioning

```bash
cd terraform
terraform apply   # crea VPS + cloud-init嵌入
```

Sin Ansible. CloudInit instala todo al primer boot:
- Docker / k3s
- Traefik
- PostgreSQL
- VictoriaMetrics + Grafana
- Tailscale
- OracleCloudAgent (métricas OCI)

---

## Servicios OCI Integrados

| Servicio          | Uso                                      | Límite Always Free        |
|-------------------|------------------------------------------|---------------------------|
| Vault             | Secrets (DB, Tailscale, API)             | 20 HSM keys, 150 secrets  |
| Monitoring        | Métricas de infraestructura              | 500M ingest/mes           |
| Logging           | Logs centralizados (syslog, Traefik, k3s)| 10 GB/mes                 |
| Email Delivery    | SMTP notificaciones                      | 3.000 emails/mes          |
| Object Storage    | Backups PostgreSQL + configs             | 20 GB                     |
| Block Volume      | Boot volumes + datos                     | 200 GB total              |

---

## Observabilidad

Dual:

- **OCI Monitoring** → métricas de nodo (CPU, RAM, disco, red). Dashboard en OCI Console.
- **VictoriaMetrics + Grafana** → métricas de k3s, Traefik, aplicaciones. Scrapeo interno via Tailscale.

---

## Roadmap

| Fase | Qué                                   |
|------|---------------------------------------|
| 1    | Estabilizar 2 AMD Micro + CloudInit   |
| 2    | Conseguir ARM A1 → worker dedicado    |
| 3    | Primer cliente en producción          |
| 4    | Escalar workers + edge redundancy     |
