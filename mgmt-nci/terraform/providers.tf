terraform {
  required_providers {
    nutanix = {
      source = "nutanix/nutanix"
      version = "2.3.4"
    }
  }
}

provider "nutanix" {
  username     = var.nutanix_pe_username
  password     = var.nutanix_pe_password
  endpoint     = var.nutanix_pe_endpoint
  port         = var.nutanix_pe_port
  insecure     = true
  wait_timeout = 10
}