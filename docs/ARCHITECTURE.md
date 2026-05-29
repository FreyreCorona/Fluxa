# Architecture

Current cluster on Oracle Cloud Always Free Tier:

```
edge-01 (AMD, 1 GB) → k3s server + Tailscale
   └── worker-01 (AMD, 1 GB) → k3s agent
```

- **edge-01**: control plane, ingress (Traefik built-in), Tailscale mesh gateway
- **worker-01**: compute node for workloads
- **Tailscale**: secure mesh between nodes

Provisioned entirely via Terraform + cloud-init. No manual setup.
