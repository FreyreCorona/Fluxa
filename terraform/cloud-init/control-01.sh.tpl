#!/bin/bash
set -euo pipefail

exec > /var/log/fluxa-bootstrap.log 2>&1

echo "=== Fluxa control-01 bootstrap ==="

# ── Wait for apt ──
while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done

# ── Packages ──
apt-get update -y
apt-get install -y tailscale docker.io

# ── Tailscale ──
tailscale up --auth-key "${tailscale_key}" --hostname control-01 --accept-routes
sleep 5

TAILSCALE_IP=$(tailscale ip -4)
echo "Tailscale IP: ${TAILSCALE_IP}"

# ── PostgreSQL (optimizado para 1 GB RAM) ──
mkdir -p /data/postgres
docker run -d \
  --name postgres \
  --restart always \
  --network host \
  -e POSTGRES_PASSWORD="${pg_password}" \
  -e POSTGRES_DB=fluxa \
  -e POSTGRES_USER=fluxa \
  -v /data/postgres:/var/lib/postgresql/data \
  postgres:17 \
  -c shared_buffers=256MB \
  -c effective_cache_size=512MB \
  -c maintenance_work_mem=64MB \
  -c max_connections=20 \
  -c wal_buffers=4MB \
  -c random_page_cost=1.1

echo "PostgreSQL started"

# ── k3s server ──
curl -sfL https://get.k3s.io | \
  K3S_TOKEN="${k3s_token}" \
  INSTALL_K3S_EXEC="server \
    --disable traefik \
    --disable-agent \
    --node-ip ${TAILSCALE_IP} \
    --advertise-address ${TAILSCALE_IP} \
    --flannel-iface tailscale0 \
    --write-kubeconfig-mode 644 \
    --kube-controller-manager-arg bind-address=0.0.0.0 \
    --kube-scheduler-arg bind-address=0.0.0.0" \
  sh -

echo "k3s server started"
sleep 10

# Permitir que workloads también corran aquí (hasta tener ARM A1)
k3s kubectl taint nodes --all node-role.kubernetes.io/master- || true
k3s kubectl label node control-01 node-role.kubernetes.io/worker=true || true

# ── Observability stack (Docker Compose) ──
mkdir -p /data/victoria /data/grafana

cat > /root/docker-compose.yml << COMPOSE
services:
  victoriametrics:
    image: victoriametrics/victoriaMetrics:v1.108.0
    restart: always
    ports:
      - "${TAILSCALE_IP}:8428:8428"
    volumes:
      - /data/victoria:/storage
    command:
      - '-storageDataPath=/storage'
      - '-retentionPeriod=30d'

  grafana:
    image: grafana/grafana:11.4.0
    restart: always
    ports:
      - "${TAILSCALE_IP}:3000:3000"
    volumes:
      - /data/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${grafana_password}
      - GF_INSTALL_PLUGINS=grafana-clock-panel
COMPOSE

cd /root && docker compose up -d

echo "Observability stack started"

# ── UptimeKuma ──
docker run -d \
  --name uptime-kuma \
  --restart always \
  --network host \
  -v /data/uptime:/app/data \
  louislam/uptime-kuma:1

echo "UptimeKuma started"

# ── kubeconfig for GitHub Actions ──
# Export and make accessible for GitHub Actions deployment
cp /etc/rancher/k3s/k3s.yaml /root/kubeconfig.yaml
sed -i "s/127.0.0.1/${TAILSCALE_IP}/g" /root/kubeconfig.yaml

echo "=== control-01 bootstrap complete ==="
echo "TAILSCALE_IP=${TAILSCALE_IP}"
