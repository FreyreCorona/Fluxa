variable "instance_shape" {
  type = string
  default = "VM.Standard.E2.1.Micro"
}

variable "compartment_id" {
  type = string
  default = ""
}

variable "ssh_public_key" {
  sensitive = false
  type = string
  default = ""
}

variable "display_name" {
  type = string
  default = ""
}

variable "subnet_id" {
  type = string
  default = ""
}

variable "cloudInit_script" {
  type = string
  default = ""
}
