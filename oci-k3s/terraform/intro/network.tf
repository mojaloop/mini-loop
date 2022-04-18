
# Source from https://registry.terraform.io/modules/oracle-terraform-modules/vcn/oci/
module "vcn"{
  source  = "oracle-terraform-modules/vcn/oci"
  version = "3.3.0"
  # insert the 8 required variables here

    compartment_id = data.oci_identity_compartments.ml_compartments.compartment_id
    defined_tags = null 
    drg_rpc_acceptor_id = null
    drg_rpc_acceptor_region = null
    internet_gateway_route_rules = null
    local_peering_gateways = null
    nat_gateway_route_rules = null
    region = var.region 

  # Optional Inputs
  vcn_name = "mojaloop_vcn"
  vcn_dns_label = "mlvcn"
  vcn_cidrs = ["10.0.0.0/16"]
  
  create_internet_gateway = true
  internet_gateway_display_name="igw"
  #create_nat_gateway = true
  #create_service_gateway = true  
}

#Source from https://registry.terraform.io/providers/hashicorp/oci/latest/docs/resources/core_security_list
resource "oci_core_security_list" "public-security-list"{
# Required
  compartment_id = data.oci_identity_compartments.ml_compartments.compartment_id
  vcn_id = module.vcn.vcn_id

# Optional
  display_name = "security-list-for-public-subnet"

  ingress_security_rules { 
        stateless = false
        source = "0.0.0.0/0"
        source_type = "CIDR_BLOCK"
        # Get protocol numbers from https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml TCP is 6
        protocol = "6"
        tcp_options { 
            min = 22
            max = 22
        }
      }
    ingress_security_rules { 
        stateless = false
        source = "0.0.0.0/0"
        source_type = "CIDR_BLOCK"
        # Get protocol numbers from https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml ICMP is 1  
        protocol = "1"
    
        # For ICMP type and code see: https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml
        icmp_options {
          type = 3
          code = 4
        } 
      }   
    
    ingress_security_rules { 
        stateless = false
        source = "10.0.0.0/16"
        source_type = "CIDR_BLOCK"
        # Get protocol numbers from https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml ICMP is 1  
        protocol = "1"
    
        # For ICMP type and code see: https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml
        icmp_options {
          type = 3
        } 
      }

    egress_security_rules {
        stateless = false
        destination = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
        protocol = "all" 
    }
}

### Subnet ### 

# Source from https://registry.terraform.io/providers/hashicorp/oci/latest/docs/resources/core_subnet
resource "oci_core_subnet" "vcn-public-subnet"{
  # Required
  compartment_id = data.oci_identity_compartments.ml_compartments.compartment_id
  vcn_id = module.vcn.vcn_id
  cidr_block = "10.0.0.0/24"
 
  # Optional
  display_name = "mojaloop_sub"
  dns_label = "mlsub" 
  route_table_id = module.vcn.ig_route_id
  security_list_ids = [oci_core_security_list.public-security-list.id]
}