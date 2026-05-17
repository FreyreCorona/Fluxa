# Fluxa — Modular PaaS

PaaS modular sobre Oracle Cloud Always Free + nodo físico local.  
**2 nodos Oracle** (edge-01 + worker-01) + **infra-01** (físico, casa) + **futuro ARM A1**.  
Provisionado con Terraform + CloudInit (edge y worker). Infra-01 integrado vía OCI services.

---

## Stack

```
                        Internet
                           |
                           v
                +-------------------------+
                |  edge-01                | ← stateless
                |  AMD Micro · 1 GB       | Oracle Always Free
                |  Traefik · fail2ban     |
                |  OracleCloudAgent       |
                +-----------+------------+
                            | Tailscale
          +-----------------+------------------+
          |                                    |
          v                                    v
+-------------------------+       +--------------------------+
|  worker-01              |       |  infra-01                |
|  AMD Micro · 1 GB       |       |  Physical PC · 24 GB    |
|  k3s server + PG        |       |  Gitea · Registry (depr) |
|  VictoriaMetrics + Graf |       |  CI runners · Backups    |
|  UptimeKuma             |       |  OracleCloudAgent        |
|  OracleCloudAgent       |       +-----------+--------------+
+-----------+------------+                   |
            |                                |
            v                                v
    +------------------+          OCI Services:
    |  worker-02       |          ├── Vault → secrets
    |  ARM A1 (futuro) |          ├── Monitoring → métricas
    |  k3s agent       |          ├── Logging → logs
    +------------------+          └── Email → SMTP
```

---

## Nodos

| Nodo      | Proveedor       | Shape / RAM        | Rol                                |
|-----------|-----------------|--------------------|------------------------------------|
| edge-01   | Oracle VPS      | E2.1.Micro · 1 GB  | Ingress stateless                  |
| worker-01 | Oracle VPS      | E2.1.Micro · 1 GB  | Control plane + DB + workloads     |
| infra-01  | Physical (home) | 4C/24G (Atom)      | Servicios internos + CI/CD         |
| worker-02 | Oracle (futuro) | A1.Flex · 12 GB    | Workers dedicados (ARM A1)         |

---

## Deployment Flow

```text
git push
    ↓
GitHub Actions → build image → push GHCR
    ↓
kubectl apply (via kubeconfig en OCI Vault)
    ↓
k3s scheduling → worker-01 (o worker-02 ARM futuro)
    ↓
Traefik ingress update → TLS automático
    ↓
application online
```

Sin Go API. k3s + Traefik resuelven el deployment flow.

---

## Provisioning

```bash
./provision.sh
  # terraform apply (edge-01 + worker-01)
  # cloud-init los bootstrapea automáticamente
```

Infra-01 es físico y se configura manualmente o con scripts legacy.

---

## OCI Services Integrados

| Servicio         | Uso                                      | Accede desde                |
|------------------|------------------------------------------|-----------------------------|
| Vault            | Secrets (PostgreSQL, Tailscale, k3s)     | edge, worker, infra         |
| Monitoring       | Métricas de CPU/RAM/disco                | edge, worker, infra         |
| Logging          | Logs centralizados (syslog, Traefik, k3s)| edge, worker, infra         |
| Email Delivery   | SMTP notificaciones (3.000/mes)          | GitHub Actions, scripts     |
| Object Storage   | Backups PostgreSQL + configs             | worker-01 (cron)            |

Todos los nodos (incluyendo infra-01) ejecutan OracleCloudAgent para enviar métricas y logs a OCI.

---

## Observabilidad

Dual:

- **OCI Monitoring** → métricas de infra (CPU, RAM, disco, red) de todos los nodos
- **VictoriaMetrics + Grafana** → métricas de k3s, Traefik, aplicaciones (solo worker-01)

---

## Roadmap

| Fase | Qué                                   |
|------|---------------------------------------|
| 1    | Edge + worker estables con CloudInit  |
| 2    | Conseguir ARM A1 → worker-02 dedicado |
| 3    | Migrar infra-01 a Oracle              |
| 4    | Escalar workers + edge redundancy     |
