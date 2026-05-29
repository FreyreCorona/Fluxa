#cloud-config

package_update: true
packages:
  - docker.io
runcmd: 
  - sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable-agent" K3S_TOKEN="${k3s_token}" sh -
  - curl -fsSL https://tailscale.com/install.sh | sh
  - sudo tailscale up --auth-key="${tailscale_auth_key}"
  - sudo iptables -I INPUT 6 -p tcp --dport 6443 -j ACCEPT
  - sudo iptables -I INPUT 6 -p tcp --dport 10250 -j ACCEPT