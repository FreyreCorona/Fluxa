output "lb_public_ip" {
  value = oci_load_balancer_load_balancer.module_lb.ip_address_details
}