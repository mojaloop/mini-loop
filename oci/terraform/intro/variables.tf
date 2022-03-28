variable "compartment_name" {
  type = string
  description = "Compartment name"
}

variable "tenancy_id" {
  type = string
  description = "tenancy ocid"
}

variable "user_id" {
  type = string
  description = "user ocid"
}

variable "region" {
  type = string
  description = "oci region"
}

variable "operating_system" {
  type = string
  description = "image operating system"
}

variable "shape" {
  type = string
  description = "instance shape"
}

variable "instance_name1" {
  type = string
  description = "instance_name1"
}

variable "instance_shape_config_memory_in_gbs" {
  type = number
  description = "instance memory"
}

variable "instance_shape_config_ocpus" {
  type = number
  description = "instance ocpus"
}

