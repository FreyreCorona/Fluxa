# Nodes

## edge-01

| Attribute | Value |
|-----------|-------|
| Provider | Oracle Always Free |
| Shape | VM.Standard.E2.1.Micro (1 GB RAM) |
| Role | k3s server (control plane), Tailscale gateway |
| Public | Yes (SSH, HTTP/HTTPS via LB) |
| Provisioning | Terraform + cloud-init |

## worker-01

| Attribute | Value |
|-----------|-------|
| Provider | Oracle Always Free |
| Shape | VM.Standard.E2.1.Micro (1 GB RAM) |
| Role | k3s agent (workloads) |
| Public | No (only via edge/LB) |
| Provisioning | Terraform + cloud-init |
