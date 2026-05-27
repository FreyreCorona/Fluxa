variable "compartment_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "lb_display_name" {
  type = string
  default = "default_load_balancer"
}

variable "lb_backend_set_name" {
  type = string
  default = "default_load_balancer_backend_set"
}

variable "instance_private_ips" {
  type = list(string)
}