terraform {
    required_version = ">= 1.15.3"
    required_providers {
      oci = {
        source = "oracle/oci"
        version = ">= 8.14"
      }
    }

    backend "oci" {
      bucket = "Fluxa-tfstate"
      key = "terraform.tfstate"
      region = "sa-saopaulo-1"
      namespace= "gr4pwtm8lqg3" 
    }
}

provider "oci" {
    user_ocid = var.user_ocid
    tenancy_ocid = var.tenancy_ocid
    region = var.region
    fingerprint = var.fingerprint
    private_key_path = var.private_key_path
}

/* Network*/
module "fluxa_network"{
  source = "./modules/oci_vcn"
  compartment_id = var.compartment_id
  vcn_display_name = "fluxa_vcn"
  vcn_dns_label = "fluxavcn"
  sc_display_name = "fluxa_security_list"
  subnet_display_name = "fluxa_subnet"
  subnet_dns_label = "fluxasubnet"
  route_table_display_name =  "fluxa_route_table"
  IG_display_name = "fluxa_gateway"

}

/* Load Balancer */
module "fluxa_lb" {
  source = "./modules/oci_load_balancer"
  subnet_id = module.fluxa_network.subnet_id
  compartment_id = var.compartment_id
  instance_private_ips = [module.fluxa_instance_01.private_ip,module.fluxa_instance_02.private_ip]

  lb_display_name = "fluxa_lb"
  lb_backend_set_name = "fluxa_lb_backend_set"
}

/* Instances*/
module "fluxa_instance_01" {
  source = "./modules/oci_micro_instance"
  compartment_id = var.compartment_id
  subnet_id = module.fluxa_network.subnet_id
  display_name = "worker-01"
  ssh_public_key = var.ssh_public_key
}

output "worker_public_ip" {
  value = module.fluxa_instance_01.public_ip
}

module "fluxa_instance_02" {
  source = "./modules/oci_micro_instance"
  compartment_id = var.compartment_id
  subnet_id = module.fluxa_network.subnet_id
  display_name = "edge-01"
  ssh_public_key = var.ssh_public_key
}

output "edge_public_ip" {
  value = module.fluxa_instance_02.public_ip
}

output "generated_private_key" {
  value     = module.fluxa_instance_01.generated_private_key_pem
  sensitive = true
}