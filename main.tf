##############################################################################
# Terraform Main IaC
##############################################################################

data "ibm_resource_instance" "power_workspace" {
  name    = var.power_workspace_name
  service = "power-iaas"
}

data "ibm_pi_network" "private" {
  pi_cloud_instance_id = data.ibm_resource_instance.power_workspace.guid
  pi_network_name      = var.power_subnet_name
}

data "ibm_pi_key" "aspera" {
  pi_cloud_instance_id = data.ibm_resource_instance.power_workspace.guid
  pi_key_name          = var.ssh_key_name
}

data "ibm_pi_catalog_images" "all" {
  pi_cloud_instance_id = data.ibm_resource_instance.power_workspace.guid
}

data "ibm_iam_auth_token" "current" {}

locals {
  catalog_image               = data.ibm_pi_catalog_images.all.images[index(data.ibm_pi_catalog_images.all.images[*].name, var.aspera_base_image_name)]
  create_resource_script_path = format("%s/%s", path.module, "scripts/create_not_exist.sh")
  create_resource_script = templatefile(format("%s.tpl", local.create_resource_script_path), {
    ibmcloud_iam_token = data.ibm_iam_auth_token.current.iam_access_token,
    pi_crn             = data.ibm_resource_instance.power_workspace.crn,
    pi_region          = local.region,
    pi_guid            = data.ibm_resource_instance.power_workspace.guid,
  })
}

resource "local_file" "create_resource" {
  content  = local.create_resource_script
  filename = local.create_resource_script_path
}

data "external" "import_catalog_image" {
  depends_on = [local_file.create_resource]
  program    = ["bash", local.create_resource_script_path, "image"]
  query = {
    source  = "root-project",
    name    = var.aspera_base_image_name,
    imageID = local.catalog_image.image_id
  }
}

data "external" "create_public_network" {
  depends_on = [local_file.create_resource]
  program    = ["bash", local.create_resource_script_path, "network"]
  query = {
    name = format("public-%s", var.name),
    type = "pub-vlan"
  }
}

data "external" "create_volume" {
  count      = var.export_volume_size == 0 ? 0 : 1
  depends_on = [local_file.create_resource]
  program    = ["bash", local.create_resource_script_path, "volume"]
  query = {
    name     = var.export_volume_name,
    diskType = var.export_volume_type,
    size     = var.export_volume_size
  }
}

resource "ibm_iam_api_key" "temp" {
  name        = format("%s-tempkey", var.name)
  description = "API key created by power-aspera-server IaC"
}

locals {
  detach_network_script = templatefile(format("%s/%s", path.module, "scripts/detach_network.sh.tpl"), {
    pi_crn    = data.ibm_resource_instance.power_workspace.crn,
    pi_region = local.region,
    pi_guid   = data.ibm_resource_instance.power_workspace.guid
  })
  get_instance_id_script = templatefile(format("%s/%s", path.module, "scripts/get_instance_id.sh.tpl"), {
    pi_crn    = data.ibm_resource_instance.power_workspace.crn,
    pi_region = local.region,
    pi_guid   = data.ibm_resource_instance.power_workspace.guid
  })
  get_health_status_script = templatefile(format("%s/%s", path.module, "scripts/get_health_status.sh.tpl"), {
    pi_crn    = data.ibm_resource_instance.power_workspace.crn,
    pi_region = local.region,
    pi_guid   = data.ibm_resource_instance.power_workspace.guid
  })
  setup_script = templatefile(format("%s/%s", path.module, "scripts/setup.sh.tpl"), {
    ibmcloud_api_key           = ibm_iam_api_key.temp.apikey,
    ibmcloud_api_key_id        = ibm_iam_api_key.temp.apikey_id,
    pi_public_network_id       = data.external.create_public_network.result.networkID,
    pi_private_network_gateway = data.ibm_pi_network.private.gateway,
    pi_private_network_cidr    = data.ibm_pi_network.private.cidr
    cos_bucket_name            = var.cos_bucket_name,
    vpc_region                 = local.location.vpc_region,
    cos_region                 = var.cos_region == "" ? local.location.vpc_region : var.cos_region,
    nfs_mount_string           = var.nfs_mount_string,
    export_volume_directory    = var.export_volume_directory
  })
}

resource "ibm_pi_instance" "aspera" {
  lifecycle {
    ignore_changes       = all
    replace_triggered_by = [local_file.create_resource]
    precondition {
      condition     = (var.nfs_mount_string != "" || var.export_volume_size > 0) && !(var.nfs_mount_string != "" && var.export_volume_size > 0)
      error_message = "You must supply EITHER an NFS mount OR an export volume size greater than 0."
    }
  }

  pi_memory            = tostring(var.powervs_instance_memory)
  pi_processors        = tostring(var.powervs_instance_cores)
  pi_instance_name     = var.name
  pi_proc_type         = var.powervs_processor_type
  pi_image_id          = data.external.import_catalog_image.result.imageID
  pi_key_pair_name     = data.ibm_pi_key.aspera.id
  pi_sys_type          = var.powervs_system_type
  pi_cloud_instance_id = data.ibm_resource_instance.power_workspace.guid
  pi_health_status     = "WARNING"
  pi_storage_type      = "tier3"
  pi_volume_ids        = var.export_volume_size == 0 ? [] : [data.external.create_volume[0].result.volumeID]
  pi_network {
    network_id = data.external.create_public_network.result.networkID
  }
  pi_network {
    network_id = data.ibm_pi_network.private.id
    ip_address = var.powervs_ip_address == "" ? null : var.powervs_ip_address
  }
  pi_user_data = base64encode(format("%s\n%s", "#cloud-config", yamlencode({
    write_files = [
      {
        content     = local.detach_network_script
        path        = "/usr/local/bin/detach_network"
        permissions = "0755"
        owner       = "root"
      },
      {
        content     = local.get_instance_id_script
        path        = "/usr/local/bin/get_instance_id"
        permissions = "0755"
        owner       = "root"
      },
      {
        content     = local.get_health_status_script
        path        = "/usr/local/bin/get_health_status"
        permissions = "0755"
        owner       = "root"
      },
      {
        content     = local.setup_script
        path        = "/tmp/setup.sh"
        permissions = "0755"
        owner       = "root"
      },
    ],
    runcmd = [
      "/tmp/setup.sh &> /var/log/aspera_setup.log"
    ]
  })))
}
