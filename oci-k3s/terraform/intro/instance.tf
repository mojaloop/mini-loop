
resource "oci_core_instance" "ubuntu_instance" {
    # Required
    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
    compartment_id = data.oci_identity_compartments.ml_compartments.compartment_id
    shape = var.shape
    source_details {
        source_id = data.oci_core_images.latest_images.images[0].id
        source_type = "image"
    }

    # Optional
    shape_config {
        #Optional
        #baseline_ocpu_utilization = var.instance_shape_config_baseline_ocpu_utilization
        memory_in_gbs = var.instance_shape_config_memory_in_gbs
        ocpus = var.instance_shape_config_ocpus
    }
    display_name = var.instance_name1
    create_vnic_details {
        assign_public_ip = true
        subnet_id = oci_core_subnet.vcn-public-subnet.id
    }
    metadata = {
        ssh_authorized_keys = file("~/.ssh/oci_free_ssh.key.pub")
    } 
    preserve_boot_volume = false
}