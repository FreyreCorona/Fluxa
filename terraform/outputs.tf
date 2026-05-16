output "edge_01_public_ip" {
  description = "Public IP of edge-01"
  value       = oci_core_instance.edge_01.public_ip
}

output "edge_01_private_ip" {
  description = "Private IP of edge-01"
  value       = oci_core_instance.edge_01.private_ip
}

output "worker_01_public_ip" {
  description = "Public IP of worker-01"
  value       = oci_core_instance.worker_01.public_ip
}

output "worker_01_private_ip" {
  description = "Private IP of worker-01"
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

output "inventory_yml" {
  description = "Ansible inventory YAML — paste into ansible/inventory.yml"
  value = <<-EOF
all:
  children:
    edge:
      hosts:
        edge-01:
          ansible_host: ${oci_core_instance.edge_01.public_ip}
    worker:
      hosts:
        worker-01:
          ansible_host: ${oci_core_instance.worker_01.public_ip}
    infra:
      hosts:
        infra-01:
          ansible_host: <infra-01-tailscale-ip>
EOF
}

output "k3s_server_ip" {
  description = "Private IP of edge-01 for k3s URL"
  value       = oci_core_instance.edge_01.private_ip
}
