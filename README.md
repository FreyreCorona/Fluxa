# Fluxa — Modular PaaS

3-node platform: **edge-01** (Oracle VPS), **worker-01** (Oracle VPS), **infra-01** (physical home PC).
All nodes connected via Tailscale mesh.

---

## Architecture

```
                  Internet
                     │
              ┌──────┴──────┐
              │   edge-01   │  Oracle VPS (free tier)
              │  k3s server │  IP: 147.15.42.234
              │  Traefik    │  Tailscale: 100.127.57.43
              │  Postgres   │
              └──────┬──────┘
                     │ Tailscale
         ┌───────────┼───────────┐
         │           │           │
  ┌──────┴──────┐    │    ┌─────┴─────┐
  │  worker-01  │    │    │  infra-01 │  Physical PC at home
  │ k3s agent   │    │    │  Gitea    │  Tailscale: 100.69.246.61
  │ Runtime-agt │    │    │  Registry │
  └─────────────┘    │    │  VM/Prom  │
                     │    │  Uptime   │
                     │    │  Vaultwrdn│
                     │    └───────────┘
              ┌──────┴──────┐
              │   devbox    │  This machine
              │   Ansible   │  Tailscale: 100.102.73.3
              │   Terraform │
              └─────────────┘
```

---

## Repo Structure

```
fluxa/
├── ansible/                  # Configuration management
│   ├── playbooks/site.yml    # Main playbook (tags: common,edge,worker,infra)
│   ├── inventory.yml         # Node definitions
│   ├── group_vars/           # Per-group variables
│   │   └── all/
│   │       ├── vars.yml      # Plain vars (tailscale_auth_key ref)
│   │       └── vault.yml     # 🔒 Encrypted secrets
│   └── roles/
│       ├── common/           # Bootstrap all nodes
│       ├── k3s/              # k3s server/agent install
│       ├── traefik/          # Reverse proxy (edge)
│       ├── postgres/         # PostgreSQL 17 (edge)
│       ├── go-api/           # 🚧 Placeholder
│       ├── runtime-agent/    # 🚧 Placeholder
│       ├── gitea/            # Git server (infra) — port 3000
│       ├── docker-registry/  # Container registry (infra) — port 5000
│       ├── victoriametrics/  # Metrics + Prometheus (infra) — ports 8428,9090
│       ├── uptime-kuma/      # Uptime monitor (infra) — port 3001
│       └── vaultwarden/      # Password vault (infra) — port 8888
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

Skip already-bootstrapped nodes:

```bash
# Only edge services (skip common)
ansible-playbook site.yml --tags edge --limit edge-01

# Only infra services (skip common)
ansible-playbook site.yml --tags infra --limit infra-01

# Only worker (needs common + k3s)
ansible-playbook site.yml --tags common,worker --limit worker-01
```

---

## Service URLs

### Infra-01 (via Tailscale)

| Service         | URL                                        |
|-----------------|--------------------------------------------|
| Gitea           | http://100.69.246.61:3000                  |
| Docker Registry | http://100.69.246.61:5000/v2/              |
| VictoriaMetrics | http://100.69.246.61:8428                  |
| Prometheus      | http://100.69.246.61:9090                  |
| Uptime Kuma     | http://100.69.246.61:3001                  |
| Vaultwarden     | http://100.69.246.61:8888                  |
| Gitea SSH       | git@100.69.246.61:2222                     |

### Edge-01 (public / Tailscale)

⚠️ Edge-01 currently has a networking issue (k3s iptables blocking TLS). See [Networking Fix](#edge-01-networking-fix).

| Service       | URL (when working)                          |
|---------------|---------------------------------------------|
| Traefik       | http://147.15.42.234:80 / :443              |
| Traefik Dash  | http://147.15.42.234:8080                   |
| Postgres      | 147.15.42.234:5432                          |
| k3s API       | https://100.127.57.43:6443                  |

---

## Vaultwarden (Password Vault)

### First Access
1. Open http://100.69.246.61:8888/admin
2. Enter admin token (retrieve from ansible-vault):
   ```bash
   ansible-vault view ansible/group_vars/all/vault.yml
   # Look for vaultwarden_admin_token
   ```
3. Create admin user → enable signups → create your account → disable signups

### Storing Secrets
Recommended structure:

```
📂 Fluxa Infrastructure
 ┣ 📁 Edge
 ┃ ┣ 📄 Tailscale Auth Key
 ┃ ┣ 📄 Postgres Password
 ┃ ┗ 📄 k3s Token
 ┣ 📁 Oracle Cloud
 ┃ ┣ 📄 Tenancy OCID
 ┃ ┣ 📄 User OCID
 ┃ ┗ 📄 API Key Fingerprint
 ┗ 📁 Infra
   ┣ 📄 Vaultwarden Admin Token
   ┗ 📄 SSH Keys
```

### Ansible Integration (future)
Install `bw` CLI and use it in Ansible:

```bash
# Login once
bw login --apikey           # needs API key from Vaultwarden
bw unlock                   # saves session token

# In Ansible (shell lookup):
ansible_vaultwarden_token: "{{ lookup('pipe', 'bw get password vaultwarden-admin-token') }}"
```

### Current Secrets (still in ansible-vault)

```bash
ansible-vault view ansible/group_vars/all/vault.yml
# - tailscale_auth_key
# - postgres_password
# - k3s_token
# - vaultwarden_admin_token
```

To migrate to Vaultwarden: copy each value from ansible-vault → create item in Vaultwarden → update Ansible to use `bw` CLI lookup.

---

## Edge-01 Networking Fix

**Symptom**: `apt-get update` and `docker pull` hang with TLS timeouts after k3s server install.

**Root cause**: k3s modifies iptables/nftables which interferes with outbound TLS connections on Oracle Cloud (likely MTU or bridge-nf-call-iptables).

**Fix** (when edge-01 is reachable):

```bash
# Option A: Disable bridge-nf-call-iptables
echo 0 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables

# Option B: Add iptables rule to accept established outbound
sudo iptables -I OUTPUT 1 -m state --state ESTABLISHED,RELATED -j ACCEPT

# Option C: Reinstall k3s with non-iptables proxy
# (in ansible/roles/k3s/tasks/main.yml add to install command:)
# --kube-proxy-arg "proxy-mode=userspace"
```

**Quickest recovery**: `terraform destroy && terraform apply` recreates both VPS from scratch.

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

| Node      | Provider       | OS        | Role              | Public IP     | Tailscale IP   |
|-----------|----------------|-----------|-------------------|---------------|----------------|
| edge-01   | Oracle VPS     | Ubuntu 24 | k3s server + LB   | 147.15.42.234 | 100.127.57.43  |
| worker-01 | Oracle VPS     | Ubuntu 24 | k3s agent + jobs  | 152.67.41.176 | 100.106.188.96 |
| infra-01  | Physical (home)| Ubuntu 24 | Services (self)   | —             | 100.69.246.61  |
| devbox    | —              | Fedora    | Ansible control   | —             | 100.102.73.3   |

---

## Common Commands

```bash
# Ping all nodes
ansible all -m ping

# Re-run vault (add new secret)
ansible-vault edit ansible/group_vars/all/vault.yml

# Deploy only Vaultwarden
ansible-playbook site.yml --tags infra --limit infra-01

# Check k3s cluster (from edge-01)
sudo k3s kubectl get nodes

# Full destroy & recreate
cd terraform && terraform destroy -auto-approve && terraform apply -auto-approve && cd ..
./provision.sh
```
