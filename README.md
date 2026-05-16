# Fluxa — Modular PaaS

3-node platform: **edge-01** (Oracle VPS), **control-01/infra-01** (physical home PC), **worker-01** (Oracle VPS).
All nodes connected via Tailscale mesh. Edge is **stateless** — no databases, no control plane.

---

## Architecture

```
                     Internet
                        |
                        v
                +----------------+
                |   edge-01      |  ← stateless, public-facing
                |  Traefik       |  Oracle VPS (free tier)
                |  fail2ban      |
                +----------------+
                        |
                        | Tailscale
                        v
          +-----------------------------+
          |     control-01 / infra-01   |  ← k3s server, DB, API
          |  k3s server, PostgreSQL     |  Physical PC at home
          |  Go API, VictoriaMetrics    |
          |  Grafana, UptimeKuma        |
          +-----------------------------+
                     |           |
                     |           +---- Observability
                     |
                     v
          +-----------------------------+
          |       worker-01             |  ← workloads only
          |  k3s agent, runtime agent   |  Oracle VPS #2
          |  metrics exporter           |
          +-----------------------------+
```

---

## Deployment Flow

```text
git push
    ↓
GitHub Actions
    ↓
build image → push GHCR
    ↓
deployment request → Go API
    ↓
Kubernetes Deployment update
    ↓
k3s scheduling → worker-01
    ↓
Traefik ingress update
    ↓
TLS automático
    ↓
application online
```

GitHub-centric: Git hosting, CI/CD, and container registry are externalized (GitHub, GHCR).

---

## Repo Structure

```
fluxa/
├── ansible/                  # Configuration management
│   ├── playbooks/site.yml    # Main playbook (tags: common,edge,control,worker)
│   ├── inventory.yml         # Node definitions
│   ├── group_vars/           # Per-group variables
│   │   └── all/
│   │       ├── vars.yml      # Plain vars (tailscale_auth_key ref)
│   │       └── vault.yml     # 🔒 Encrypted secrets
│   └── roles/
│       ├── common/           # Bootstrap all nodes
│       ├── k3s/              # k3s server/agent install
│       ├── traefik/          # Reverse proxy (edge)
│       ├── postgres/         # PostgreSQL 17 (control)
│       ├── go-api/           # 🚧 Go control API (control)
│       ├── runtime-agent/    # 🚧 Runtime agent (worker)
│       ├── gitea/            # 🚧 Deprecating — migrating to GitHub
│       ├── docker-registry/  # 🚧 Deprecating — migrating to GHCR
│       ├── victoriametrics/  # Metrics (control)
│       ├── uptime-kuma/      # Uptime monitor (control)
├── terraform/                # Oracle Cloud provisioning
│   ├── main.tf               # VCN, subnet, instances, security list
│   ├── variables.tf          # tenancy_ocid, region, shape...
│   ├── outputs.tf            # IPs, inventory YAML
│   └── terraform.tfvars      # Your OCI credentials 🔒
├── provision.sh              # terraform apply → inventory → ansible
└── README.md
```

---

## Provisioning Flow (full)

```bash
# 1. Create/recreate Oracle VPS
cd terraform && terraform apply      # or: terraform destroy && terraform apply
cd ..

# 2. Generate inventory & run Ansible
./provision.sh

# Or step by step:
ansible-playbook ansible/playbooks/site.yml
```

---

## Playbook Tags

```bash
# Only edge services (Traefik, fail2ban)
ansible-playbook site.yml --tags edge --limit edge-01

# Only control plane + infra services (k3s server, Postgres, observability)
ansible-playbook site.yml --tags control --limit infra-01

# Only worker (needs common + k3s agent)
ansible-playbook site.yml --tags common,worker --limit worker-01
```

---

## Service URLs

### Control-01 / Infra-01 (via Tailscale only — no public exposure)

| Service         | URL                                        |
|-----------------|--------------------------------------------|
| VictoriaMetrics | http://100.69.246.61:8428                  |
| Prometheus      | http://100.69.246.61:9090                  |
| Grafana         | http://100.69.246.61:3000                  |
| Uptime Kuma     | http://100.69.246.61:3001                  |
| k3s API         | https://100.127.57.43:6443                 |
| PostgreSQL      | 100.69.246.61:5432                         |

### Edge-01 (public)

| Service       | URL                                          |
|---------------|----------------------------------------------|
| Traefik HTTP  | http://147.15.42.234:80                      |
| Traefik HTTPS | https://147.15.42.234:443                    |
| Traefik Dash  | http://147.15.42.234:8080                    |

> Edge is stateless — no PostgreSQL, no k3s server, no application data.

---

## Terraform — Additional Free-Tier Resources

Add to `terraform/main.tf` to provision extra OCI resources:

```hcl
# ARM Ampere instances (up to 4, 24GB RAM total)
resource "oci_core_instance" "arm_01" {
  shape = "VM.Standard.A1.Flex"
  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }
  # ... same pattern as edge_01
}

# Block volume (200GB free)
resource "oci_core_volume" "data" {
  size_in_gbs = 50
}

# Object Storage bucket (10GB free)
resource "oci_objectstorage_bucket" "backups" {
  name        = "fluxa-backups"
  compartment_id = var.tenancy_ocid
}
```

---

## Node Inventory

| Node      | Provider       | OS        | Role                          |
|-----------|----------------|-----------|-------------------------------|
| edge-01   | Oracle VPS     | Ubuntu 24 | Ingress (stateless)           |
| worker-01 | Oracle VPS     | Ubuntu 24 | Runtime (k3s agent)           |
| infra-01  | Physical (home)| Ubuntu 24 | Control plane + infra services|
| devbox    | —              | Fedora    | Ansible/terraform control     |

---

## Common Commands

```bash
# Ping all nodes
ansible all -m ping

# Re-run vault (add new secret)
ansible-vault edit ansible/group_vars/all/vault.yml

# Check k3s cluster (from infra-01)
sudo k3s kubectl get nodes

# Full destroy & recreate
cd terraform && terraform destroy -auto-approve && terraform apply -auto-approve && cd ..
./provision.sh
```
