output "generated_private_key_pem" {
  value     = (var.ssh_public_key != "") ? var.ssh_public_key : tls_private_key.module_ssh_key.private_key_pem
  sensitive = true
}

output "public_ip" {
  value = oci_core_instance.module_instance.public_ip
  sensitive = false
}

output "private_ip" {
  value = oci_core_instance.module_instance.private_ip
  sensitive = true
}