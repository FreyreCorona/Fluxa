#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/terraform"

echo "=== Fluxa: Provisioning Oracle VPS with Terraform ==="

terraform init
terraform apply -auto-approve

echo "=== Generating Ansible inventory ==="

INVENTORY="../ansible/inventory.yml"

EDGE_PUBLIC=$(terraform output -raw edge_01_public_ip)
WORKER_PUBLIC=$(terraform output -raw worker_01_public_ip)
WORKER_PRIVATE=$(terraform output -raw worker_01_private_ip)
EDGE_PRIVATE=$(terraform output -raw edge_01_private_ip)

cat > "$INVENTORY" << EOF
all:
  children:
    edge:
      hosts:
        edge-01:
          ansible_host: ${EDGE_PUBLIC}
    worker:
      hosts:
        worker-01:
          ansible_host: ${WORKER_PUBLIC}
    infra:
      hosts:
        infra-01:
          ansible_host: <infra-01-tailscale-ip>
EOF

echo "=== Inventory written to $INVENTORY ==="
echo "edge-01: $EDGE_PUBLIC (public) / $EDGE_PRIVATE (private)"
echo "worker-01: $WORKER_PUBLIC (public) / $WORKER_PRIVATE (private)"
echo ""
echo "=== Running Ansible playbook ==="
echo "Run: ansible-playbook ansible/playbooks/site.yml"
