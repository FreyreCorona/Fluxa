# Node Roles

Todos los nodos:
- pertenecen a la misma red Tailscale
- utilizan bootstrap reproducible
- poseen firewall configurado
- usan observabilidad básica

---

# EDGE NODE

Rol:
- edge
- control plane

Host:
- Oracle VPS #1

Servicios:
- k3s server
- Traefik
- PostgreSQL
- Go API
- scheduler

Exposición pública:
- sí

Puertos públicos:
- 80
- 443

Puertos privados:
- PostgreSQL
- k3s internal

---

# WORKER NODE

Rol:
- runtime

Host:
- Oracle VPS #2

Servicios:
- k3s agent
- runtime agent
- metrics exporter

Exposición pública:
- no

Comunicación:
- únicamente Tailscale

Responsabilidad:
- ejecutar workloads clientes

---

# INTERNAL INFRA NODE

Rol:
- infra

Host:
- Atom Ubuntu Server

Servicios:
- Gitea
- CI runners
- Docker registry
- VictoriaMetrics
- backups

Exposición pública:
- no

Comunicación:
- únicamente Tailscale

Responsabilidad:
- tooling interno
- CI/CD
- observabilidad