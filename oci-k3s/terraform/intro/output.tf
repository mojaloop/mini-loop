# Output the "list" of all availability domains.
output "all-availability-domains-in-your-tenancy" {
  value = data.oci_identity_availability_domains.ads.availability_domains
}

output "ml_compartment_id" {
  value = data.oci_identity_compartments.ml_compartments.compartment_id
}

output "ml_image_name" {
  value = data.oci_core_images.latest_images.images[0].display_name
}
output "ml_image_id" {
  value = data.oci_core_images.latest_images.images[0].id
}

output "instance_name" { 
    value = oci_core_instance.ubuntu_instance.display_name
}

output "instance_ip" { 
    value = oci_core_instance.ubuntu_instance.public_ip
}