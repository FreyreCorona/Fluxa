# Fluxa — Modular PaaS on Oracle Cloud Free Tier

Infrastructure-as-Code platform built on **Oracle Cloud Always Free Tier** with **Terraform** and **k3s Kubernetes**. Designed as a hands-on learning project to master cloud provisioning, Kubernetes orchestration, and multi-node cluster management.

## Architecture

```
Terraform → provisions VCN, subnets, security lists, compute instances, load balancer
    ↓
cloud-init → bootstraps each node with Docker + k3s
    ↓
k3s cluster → edge (control plane) + worker nodes
    ↓
Go Operator (future) → CRD-driven service management
```

## Stack

| Component | Technology |
|-----------|-----------|
| **Cloud** | Oracle Cloud Infrastructure (Always Free) |
| **IaC** | Terraform with OCI provider |
| **Kubernetes** | k3s lightweight distribution |
| **Ingress** | Traefik (built-in k3s) |
| **Connectivity** | Tailscale (edge-to-worker mesh) |
| **Operator** | Go + controller-runtime (WIP) |

## Provisioning

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your OCI credentials
terraform init
terraform apply
```

The instances self-configure via cloud-init:
- **edge-01**: k3s server (control plane), Tailscale
- **worker-01**: k3s agent joins cluster

## Resources

- `oci_vcn` — VCN, subnet, security lists, internet gateway, route table
- `oci_micro_instance` — compute instance with auto-generated SSH key
- `oci_load_balancer` — flexible load balancer with HTTP listener
- `cloud_init/` — cloud-config templates for edge and worker nodes

## Learning Roadmap

Followed as a structured deep-dive into:

1. **Terraform** — provider setup, modules, remote state, multi-resource orchestration
2. **k3s + multi-tenancy** — cloud-init provisioning, cluster formation, namespaces, quotas
3. **Go Kubernetes Operator** — CRDs, reconciler, controller-runtime, envtest

## Project Status

Working k3s cluster with 2 OCI nodes. Next: multi-tenancy (ResourceQuota, NetworkPolicy), Helm, Go operator.
