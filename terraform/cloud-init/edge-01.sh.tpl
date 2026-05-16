#!/bin/bash
set -euo pipefail

exec > /var/log/fluxa-bootstrap.log 2>&1

echo "=== Fluxa edge-01 bootstrap ==="

# ── Wait for apt ──
while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done

# ── Packages ──
apt-get update -y
apt-get install -y tailscale docker.io fail2ban

# ── Tailscale ──
tailscale up --auth-key "${tailscale_key}" --hostname edge-01 --accept-routes
sleep 3

# ── Traefik ──
mkdir -p /data/traefik/dynamic

cat > /data/traefik/traefik.yml << 'TRAEFIK'
api:
  dashboard: true
  debug: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "traefik"
  file:
    directory: /etc/traefik/dynamic
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${acme_email}
      storage: /etc/traefik/acme.json
      httpChallenge:
        entryPoint: web
TRAEFIK

docker network create traefik 2>/dev/null || true

docker run -d \
  --name traefik \
  --restart always \
  --network traefik \
  -p 80:80 \
  -p 443:443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /data/traefik:/etc/traefik \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.dashboard.rule=Host(`traefik.${domain}`)" \
  --label "traefik.http.routers.dashboard.service=api@internal" \
  --label "traefik.http.routers.dashboard.middlewares=auth" \
  --label "traefik.http.middlewares.auth.basicauth.users=${traefik_users}" \
  traefik:v3.1

echo "=== edge-01 bootstrap complete ==="
