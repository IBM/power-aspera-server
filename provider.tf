##############################################################################
# Terraform Providers
##############################################################################

terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "1.58.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.2"
    }
  }
  required_version = ">= 1.5.0"
}

##############################################################################


##############################################################################
# IBM Cloud Provider
##############################################################################

locals {
  location_lookup = yamldecode(file(var.data_location_file_path))
  location        = local.location_lookup[lower(var.power_workspace_location)]
  region          = local.location.region
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = local.region
  zone             = var.power_workspace_location
}

##############################################################################
