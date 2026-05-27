terraform {
  required_providers {
    oci = {
        version = ">= 8.15"
        source = "oracle/oci"
    }
  }
}


resource "oci_load_balancer_load_balancer" "module_lb" {
  subnet_ids = [var.subnet_id]
  shape = "flexible"
  shape_details {
    maximum_bandwidth_in_mbps = 10
    minimum_bandwidth_in_mbps = 10
  }
  display_name = var.lb_display_name
  compartment_id = var.compartment_id
}

resource "oci_load_balancer_backend_set" "module_lb_backend_set" {
  name             = var.lb_backend_set_name
  load_balancer_id = oci_load_balancer_load_balancer.module_lb.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = "80"
    protocol            = "HTTP"
    response_body_regex = ".*"
    url_path            = "/"
  }

  session_persistence_configuration {
    cookie_name      = "lb-session1"
    disable_fallback = true
  }
}

resource "oci_load_balancer_listener" "module_lb_listener0" {
  load_balancer_id         = oci_load_balancer_load_balancer.module_lb.id
  name                     = "http"
  default_backend_set_name = oci_load_balancer_backend_set.module_lb_backend_set.name
  port                     = 80
  protocol                 = "HTTP"

  connection_configuration {
    idle_timeout_in_seconds = "240"
  }
}

resource "oci_load_balancer_backend" "module_lb_backend" {
  count = length(var.instance_private_ips)

  backendset_name  = oci_load_balancer_backend_set.module_lb_backend_set.name
  ip_address       = var.instance_private_ips[count.index]
  load_balancer_id = oci_load_balancer_load_balancer.module_lb.id
  port             = "80"
}