data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_id
}

data "oci_identity_compartments" "ml_compartments" {
    #Required
    compartment_id = var.tenancy_id

    #Optional
    compartment_id_in_subtree = true
    filter {
        name = "name"
        values = [var.compartment_name,]
    }
}

data "oci_core_images" "latest_images" {
  compartment_id           = var.tenancy_id
  operating_system         = var.operating_system
  #operating_system_version = var.node_pool_os_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
}

