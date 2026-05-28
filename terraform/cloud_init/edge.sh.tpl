#cloud-config

package_update: true
packages:
  - docker.io
runcmd: 
  - curl -sfL https://get.k3s.io | K3S_TOKEN="${k3s_token}" sh -
  - curl -fsSL https://tailscale.com/install.sh | sh
  - sudo tailscale up --auth-key="${tailscale_auth_key}"