#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "╔═══════════════════════════════════════════════════╗"
echo "║         Fluxa — Full Provisioning                 ║"
echo "╚═══════════════════════════════════════════════════╝"

# ── Step 1: Provision Oracle VPS ──────────────────────
echo ""
echo "==> Step 1/4: Provisioning Oracle VPS with Terraform..."

cd terraform
terraform init -upgrade >/dev/null
terraform apply -auto-approve
cd ..

# ── Step 2: Read new IPs ──────────────────────────────
echo ""
echo "==> Step 2/4: Reading new IPs from Terraform output..."

EDGE_PUB=$(terraform -chdir=terraform output -raw edge_01_public_ip)
EDGE_PRIV=$(terraform -chdir=terraform output -raw edge_01_private_ip)
WORKER_PUB=$(terraform -chdir=terraform output -raw worker_01_public_ip)
WORKER_PRIV=$(terraform -chdir=terraform output -raw worker_01_private_ip)

echo "  edge-01:  $EDGE_PUB (public)  /  $EDGE_PRIV (private)"
echo "  worker-01: $WORKER_PUB (public)  /  $WORKER_PRIV (private)"

# ── Step 3: Generate inventory ────────────────────────
echo ""
echo "==> Step 3/4: Writing Ansible inventory..."

cat > ansible/inventory.yml << EOF
all:
  children:
    edge:
      hosts:
        edge-01:
          ansible_host: ${EDGE_PUB}
    worker:
      hosts:
        worker-01:
          ansible_host: ${WORKER_PUB}
    infra:
      hosts:
        infra-01:
          ansible_host: 100.69.246.61
EOF

echo "  → ansible/inventory.yml updated"

# ── Step 4: Run Ansible ──────────────────────────────
echo ""
echo "==> Step 4/4: Running Ansible playbook..."
echo "  (this will take 10-20 minutes for fresh nodes)"
echo ""

ansible-playbook ansible/playbooks/site.yml --limit edge-01,worker-01

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║  ✅  Provisioning complete!                        ║"
echo "║                                                    ║"
echo "║  edge-01:  $EDGE_PUB                              ║"
echo "║  worker-01: $WORKER_PUB                               ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""
echo "Infra services: http://100.69.246.61:<port>"
echo "  Gitea: 3000  |  Registry: 5000  |  VMetrics: 8428"
echo "  Prom: 9090   |  Uptime: 3001    |  Vaultwarden: 8888"
