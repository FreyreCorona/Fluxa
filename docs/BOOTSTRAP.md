# Bootstrap System

Objetivo:
Provisionar nodos reproduciblemente
según su rol.

---

# Filosofía

Cada nodo:
- comparte una base común
- instala componentes según rol
- minimiza configuración manual

---

# Base Layer

Todos los nodos instalan:
- tailscale
- firewall
- fail2ban
- docker tools
- observabilidad básica
- usuarios
- SSH hardening

---

# Roles

## edge

Instala:
- k3s server
- Traefik
- PostgreSQL
- control API

---

## worker

Instala:
- k3s agent
- runtime agent
- metrics exporter

---

## infra

Instala:
- Gitea
- CI runners
- registry
- monitoring stack

---

# Bootstrap Flow

```text
Provision VPS
    ↓
Run bootstrap.sh
    ↓
Join Tailscale
    ↓
Configure firewall
    ↓
Install role packages
    ↓
Register node
    ↓
Ready
```

---

# Objetivos del Bootstrap

- reproducibilidad
- rapidez
- menor drift
- recuperación rápida
- onboarding simple
- infraestructura declarativa gradual

---

# Futuro

Migración futura posible hacia:
- Ansible
- Terraform
- OpenTofu
- cloud-init
- GitOps infra