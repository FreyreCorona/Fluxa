#cloud-config

package_update: true
packages:
  - docker.io
runcmd: 
  - echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
  - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent" K3S_URL="https://${edge_private_ip}:6443" K3S_TOKEN="${k3s_token}" sh -

