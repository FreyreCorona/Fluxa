#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "╔═══════════════════════════════════════════════════╗"
echo "║         Fluxa — Provision                        ║"
echo "║   Terraform + CloudInit (no Ansible)             ║"
echo "╚═══════════════════════════════════════════════════╝"

cd terraform
terraform init -upgrade >/dev/null
terraform apply -auto-approve


echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  ✅  Provisioning complete                            ║"
echo "║                                                       ║"
echo "║  edge-01:    $(terraform output -raw edge_01_public_ip)                    ║"
echo "║  worker-01:  $(terraform output -raw worker_01_private_ip) (private)       ║"
echo "║                                                       ║"
echo "║  Bootstrap logs (first boot):                         ║"
echo "║  ssh -i ~/.ssh/fluxa_ed25519 ubuntu@<ip>              ║"
echo "║  tail -f /var/log/fluxa-bootstrap.log                 ║"
echo "╚═══════════════════════════════════════════════════════╝"
