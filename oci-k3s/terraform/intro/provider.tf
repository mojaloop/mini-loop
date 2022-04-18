provider "oci" {
  tenancy_ocid = var.tenancy_id
  user_ocid = var.user_id
  private_key_path = "~/.ssh/oci_free_2022.pem"
  fingerprint = "eb:bd:62:8b:67:e5:f0:9c:32:22:ad:4a:0b:09:bb:a2"
  region = var.region
  
}

terraform {
  required_version = ">= 0.12.6"
  required_providers {
    oci = {
      version = ">= 4.0.0"
    }
  }
}