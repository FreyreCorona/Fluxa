# Node Roles

Todos los nodos:
- pertenecen a Oracle Cloud (Always Free)
- se provisionan con Terraform + CloudInit
- pertenecen a la misma VCN y red Tailscale
- ejecutan OracleCloudAgent para métricas OCI
- utilizan OCI Vault para secretos
- priorizan aislamiento entre planos de responsabilidad

---

# EDGE NODE — `edge-01`

Shape: `VM.Standard.E2.1.Micro` (1/8 OCPU, 1 GB RAM)

Rol: ingress stateless

Responsabilidad:
- recibir tráfico público
- terminación TLS
- reverse proxy (Traefik)
- routing hacia workloads internos via Tailscale
- protección básica (fail2ban)

Servicios:
- Traefik
- fail2ban
- OracleCloudAgent

Networking:
- puertos públicos: 80, 443
- puertos privados: ninguno
- Tailscale
- OCI VCN security lists restrictivas

Notas:
- sin bases de datos
- sin k3s
- sin workloads
- reemplazable sin perder estado

CloudInit:
```bash
# bootstrap mínimo
apt update && apt install -y tailscale docker.io
tailscale up --auth-key $(oci vault secret --from OCI)
docker run -d --name traefik ...  # o systemd unit
```

---

# CONTROL NODE — `control-01`

Shape: `VM.Standard.E2.1.Micro` (1/8 OCPU, 1 GB RAM)

Rol: control plane + base de datos + observabilidad

Responsabilidad:
- administración del cluster k3s
- base de datos PostgreSQL
- observabilidad (métricas + uptime)
- almacenamiento de estado de plataforma

Servicios:
- k3s server (control plane)
- PostgreSQL
- VictoriaMetrics + Grafana
- UptimeKuma
- OracleCloudAgent

Networking:
- sin puertos públicos
- Tailscale
- PostgreSQL: solo escucha en Tailscale IP
- k3s API: disponible via Tailscale (6443)
- VictoriaMetrics/Grafana: disponible via Tailscale

Notas:
- 1 GB RAM es ajustado. PostgreSQL configurado con `shared_buffers=256MB`, `effective_cache_size=512MB`.
- k3s server con `--disable-agent` para no schedulear workloads aquí (hasta tener worker dedicado).
- Si no hay ARM A1 disponible, este nodo también corre workloads como worker temporal.

Secretos (almacenados en OCI Vault):
- PostgreSQL password
- k3s token
- Tailscale auth key
- Grafana admin password

CloudInit:
```bash
# bootstrap
apt update && apt install -y tailscale docker.io
tailscale up --auth-key $(oci vault secret --from OCI)

# PostgreSQL (optimizado para 1 GB RAM)
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=$(oci vault secret --from OCI) \
  -e shared_buffers=256MB \
  -v /data/postgres:/var/lib/postgresql/data \
  postgres:17

# k3s server
curl -sfL https://get.k3s.io | sh -s - \
  --token $(oci vault secret --from OCI) \
  --disable-agent \
  --disable traefik \
  --write-kubeconfig-mode 644

# VictoriaMetrics + Grafana (docker compose)
...
```

---

# WORKER NODE — `worker-01`

Shape: `VM.Standard.A1.Flex` (ARM, pendiente disponibilidad)

Rol: runtime de workloads

Responsabilidad:
- ejecutar workloads clientes
- ejecutar workloads internos
- aislamiento de workloads
- exposición indirecta mediante edge-01

Servicios:
- k3s agent
- runtime agent (metrics exporter)
- OracleCloudAgent

Networking:
- sin puertos públicos
- Tailscale
- solo se comunica con control-01 (k3s API) y edge-01 (tráfico ingress)

Notas:
- ARM A1 — pendiente de disponibilidad en la región.
- Mientras tanto, los workloads se schedulean en control-01 como nodo k3s.
- Al obtener ARM A1, control-01 deja de schedulear workloads.

---

# Worker Temporal (hasta obtener ARM A1)

Mientras `worker-01` no exista, `control-01` actúa también como worker:

```bash
# Reconfigurar k3s server para permitir pods
k3s server --token $(oci vault secret --from OCI) \
  --disable traefik \
  --node-label "node-role.kubernetes.io/worker=true"
```

Esto permite tener el PaaS funcional con 2 AMD Micro, aunque con capacidad limitada.

---

# Tabla Resumen

| Nodo       | Shape             | RAM  | Público | Rol principal        | Cuando agregar ARM A1       |
|------------|-------------------|------|---------|----------------------|-----------------------------|
| edge-01    | E2.1.Micro        | 1 GB | Sí      | Traefik + fail2ban   | Se queda igual              |
| control-01 | E2.1.Micro        | 1 GB | No      | k3s + PG + metrics   | Deja de schedulear workloads|
| worker-01  | A1.Flex (ARM)     | 12 GB| No      | Workloads clientes   | Nuevo nodo dedicado         |
