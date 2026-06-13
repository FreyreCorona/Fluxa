#cloud-config

package_update: true
packages:
  - docker.io
  - iptables-persistent
runcmd: 
  - sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644 --disable servicelb --disable metrics-server" K3S_TOKEN="${k3s_token}" sh -
  - mkdir -p /etc/systemd/system/k3s.service.d
  - |
    cat > /etc/systemd/system/k3s.service.d/memory-limit.conf << 'EOF'
    [Service]
    MemoryMax=550M
    EOF
  - sudo systemctl daemon-reload && sudo systemctl restart k3s
  - mkdir -p /var/lib/rancher/k3s/server/manifests
  - |
    cat > /var/lib/rancher/k3s/server/manifests/traefik-config.yaml << 'EOF'
    apiVersion: helm.cattle.io/v1
    kind: HelmChartConfig
    metadata:
      name: traefik
      namespace: kube-system
    spec:
      valuesContent: |-
        nodeSelector:
          node-role.kubernetes.io/control-plane: "true"
        tolerations:
          - key: "node-role.kubernetes.io/control-plane"
            operator: "Exists"
            effect: "NoSchedule"
        replicas: 1
    EOF
  - sudo iptables -I INPUT 6 -p tcp --dport 6443 -j ACCEPT
  - sudo iptables -I INPUT 6 -p tcp --dport 10250 -j ACCEPT
  - sudo iptables-save > /etc/iptables/rules.v4
  - curl -fsSL https://tailscale.com/install.sh | sh
  - sudo tailscale up --auth-key="${tailscale_auth_key}"