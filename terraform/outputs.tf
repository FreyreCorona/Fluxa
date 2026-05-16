output "edge_01_public_ip" {
  description = "Public IP of edge-01 (SSH + HTTP/HTTPS)"
  value       = oci_core_instance.edge_01.public_ip
}

output "edge_01_private_ip" {
  description = "Private IP of edge-01 (VCN)"
  value       = oci_core_instance.edge_01.private_ip
}

output "worker_01_private_ip" {
  description = "Private IP of worker-01 (VCN, no public IP)"
  value       = oci_core_instance.worker_01.private_ip
}

output "ssh_private_key" {
  description = "Path to the generated SSH key"
  value       = local_sensitive_file.ssh_private.filename
}

output "ssh_public_key" {
  description = "Path to the generated SSH public key"
  value       = local_sensitive_file.ssh_public.filename
}

output "connect" {
  description = "SSH commands to access nodes"
  value = <<-EOF
edge-01:   ssh -i ~/.ssh/fluxa_ed25519 ubuntu@${oci_core_instance.edge_01.public_ip}
worker-01: ssh -i ~/.ssh/fluxa_ed25519 -J ubuntu@${oci_core_instance.edge_01.public_ip} \
             ubuntu@${oci_core_instance.worker_01.private_ip}
EOF
}

output "k3s_kubeconfig" {
  description = "After bootstrap, get kubeconfig from worker-01"
  value = <<-EOF
scp -i ~/.ssh/fluxa_ed25519 -J ubuntu@${oci_core_instance.edge_01.public_ip} \
  ubuntu@${oci_core_instance.worker_01.private_ip}:/root/kubeconfig.yaml ./kubeconfig.yaml
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
EOF
}
