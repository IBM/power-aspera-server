##############################################################################
# Account Variables
##############################################################################

variable "ibmcloud_api_key" {
  description = "The IBM Cloud platform API key needed to deploy IAM enabled resources"
  type        = string
  sensitive   = true
}

variable "power_workspace_location" {
  description = <<-EOD
    The location used to create the power workspace.

    Available locations are: dal10, dal12, us-south, us-east, wdc06, wdc07, sao01, sao04, tor01, mon01, eu-de-1, eu-de-2, lon04, lon06, syd04, syd05, tok04, osa21
    Please see [PowerVS Locations](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-power-virtual-server) for an updated list.
  EOD
  type        = string
}

variable "power_workspace_name" {
  description = "Existing power workspace name where the Aspera server will be created."
  type        = string
}

variable "power_subnet_name" {
  description = "Existing power network subnet name the Aspera server will be attached to."
  type        = string
}

variable "ssh_key_name" {
  description = <<-EOD
    SSH key for the Aspera Server. This key must exist in the PowerVS Workspace.
    It is used for root SSH access as well as the Aspera connection.
  EOD
  type        = string
}

variable "name" {
  description = <<-EOD
    The name used for the Aspera server.
    Other resources created will use this for their basename and be suffixed by a random identifier.
  EOD
  type        = string
}

variable "cos_region" {
  description = <<-EOD
    Optional variable to specify the region the COS bucket resides in.

    Available regions are: jp-osa, jp-tok, eu-de, eu-gb, ca-tor, us-south, us-east, and br-sao.
    Please see [Regions](https://cloud.ibm.com/docs/overview?topic=overview-locations) for an updated list.

    If not specified, the region corresponding to the `power_workspace_location` will be used.
  EOD
  type        = string
  default     = ""
}

variable "cos_bucket_name" {
  description = "COS bucket that contains the Aspera installer and license file."
  type        = string
}

variable "nfs_mount_string" {
  description = <<-EOD
    Either `nfs_mount_string` or `export_volume_size` MUST be specified.

    This will specify the NFS mount string in the format `<IP>:<shared directory>`
    Used for the Aspera destination.
  EOD
  type        = string
  default     = ""
}

variable "export_volume_name" {
  description = "Optional variable for name for volume created to export."
  type        = string
  default     = "aspera"
}

variable "export_volume_type" {
  description = <<-EOD
    Optional variable for the type of disk for volume created to export.
    Supported values are `ssd`, `standard`, `tier0`, `tier1`, `tier3`, and `tier5k`."
  EOD
  type        = string
  default     = "tier3"
}

variable "export_volume_size" {
  description = <<-EOD
    Either `nfs_mount_string` or `export_volume_size` MUST be specified.

    Size of disk in GB for volume created to export.
    When greater than 0, Aspera will use this as the destination instead of the `nfs_mount_string`.
    When equal to 0, volume is not created and Aspera will use `nfs_mount_string` as its destination.
    The export volume will be exported as an NFS share.
  EOD
  type        = number
  default     = 0
}

variable "export_volume_directory" {
  description = "Optional variable for directory used for export volume. Must be absolute."
  type        = string
  default     = "/aspera"
}

variable "powervs_instance_memory" {
  description = "Optional variable to set memory in GiB for PowerVS instance."
  type        = number
  default     = 8
}

variable "powervs_instance_cores" {
  description = "Optional variable to set CPU cores for PowerVS instance."
  type        = number
  default     = 2
}

variable "powervs_processor_type" {
  description = "Optional variable to set CPU processor type. Available options: `shared`, `capped` or `dedicated`"
  type        = string
  default     = "shared"
}

variable "powervs_system_type" {
  description = "Optional variable to set Power system type. Available options: `s922`, `e880`, `e980`, `s1022`, and `e1080`."
  type        = string
  default     = "s922"
}

variable "powervs_ip_address" {
  description = <<-EOD
    Optional variable to statically set the private network IP address for the Aspera server.
    The default behavior is to randomly assign an IP from the `power_subnet_name` network.
  EOD
  type        = string
  default     = ""
}

variable "data_location_file_path" {
  description = <<-EOD
    Debug variable to indicated where the file with PER location data is stored.
    This variable is used for testing, and should not normally be altered.
  EOD
  type        = string
  default     = "./data/locations.yaml"
}

variable "aspera_base_image_name" {
  description = <<-EOD
    Debug variable to specify the base OS for the Aspera server.
    This Aspera server automation has been tested with CentOS 8.3 on PowerVS.
    Use this variable if you wish to try another version.
  EOD
  type        = string
  default     = "CentOS-Stream-8"
}
