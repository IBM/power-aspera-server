# PowerVS Aspera Server

## Overview

This module allows a user to easily create a Power Virtual Server running an Aspera server. Aspera
is a data transport and streaming technology that provides high-speed data transfer service. The
Power Virtual Server will be connected by the automation with either an existing NFS share or an
attached block storage where the data uploaded will be stored.

This Terraform module deploys the following infrastructure:

- PowerVS Server
- PowerVS Public Network**
- IBM API Key**
- PowerVS Image (Stock Import)*
- PowerVS Block Storge^

|||
|---|---|
| * | A CentOS Stream 8 image is imported from the stock images if it doesn't exist in the Workspace. |
| ** | The public network and API key are only needed for setup. They are deleted once complete. |
| ^ | A block storage device is created when using [attached storage](#attached-storage-export-volume). |

## Compatibility

This module includes bash shell scripts that are run during the Terraform apply. These are written
to work with most Linux distributions. You may also use this module with
[IBM Schematics](#ibm-schematics).

- Linux / WSL
  - [`jq`](https://jqlang.github.io/jq/) must be installed
- [IBM Schematics](#ibm-schematics)

### Deployment Model

![Deployment Model](./doc/materials/aspera-server.png)

The Aspera Server (green box) is created by this automation. The other components show an example of
how it might be accessed by onsite infrastructure. A VPN connection as shown in the diagram can be
created by the [PowerVS VPN Gateway IaC](https://github.com/IBM/power-vpn-gateway).

#### Attached Storage (Export Volume)

You may also choose to create the Aspera server with attached block storage instead of connecting to a
remote NFS share. Use the variables that begin with `export_volume_` to define this behavior. The
only required variable to set to enable this is `export_volume_size` (greater than 0). This will
tell the automation how large (in GB) to allocate for Aspera's storage. The automation will create a
volume, then partition and format it. The volume will be exported via NFS and you can then mount it
remotely with another host in the PowerVS network. The diagram below shows an example of how this
could be used. Note, you may not use attached storage and also mount a remote NFS share. When
enabled the output variable `aspera_nfs_mount` will be the local network endpoint for this volume.

![Aspera Server with Block Storage](./doc/materials/aspera-server-local.png)

The block storage volume created is named using the `export_volume_name`. When the automation is
destroyed, this volume will persist. This is to protect the data from being deleted after the
Aspera server is no longer needed. If you wish to delete this volume, visit the PowerVS storage
portal for your Workspace. If this automation is re-applied and the volume exists, it will be
reused.

You may also have advanced use cases for the data volume. You may choose to create the volume ahead
of deployment and specify that existing volume as the `export_volume_name`. In this case, you will
need to supply either an empty volume or a volume with a single ext4 partition with the label
`aspera-data`. Any other configuration will fail to mount the volume. You may also wish to write
data to one volume and then create or attach a new volume. You can do this by changing the
`export_volume_name` variable and re-applying the automation. This could be useful if you are
wishing to populate multiple volumes and then attach to workload servers later.

#### Static IP Address

If you are planning to reuse the Aspera server with different configurations, you may wish to use a
static IP address with it. This can be done by specifying the variable `powervs_ip_address`. It must
be an available IP address in the subnet you define with the variable `power_subnet_name`. This can
be useful when populating many block storage devices, preventing a need to change to the client
configuration with each one. Otherwise, a random IP assignment from the network will be made with
each apply.

## Setup Requirements

### Prerequisites

#### Upgrading your IBM Cloud Account

To order and use IBM Cloud services, billing information is required for your account. See
[Upgrading Your Account](https://cloud.ibm.com/docs/account?topic=account-upgrading-account).

#### Install Terraform

If you wish to run Terraform locally, see
[Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform).

#### IBM Cloud API Key

You must supply an IBM Cloud API key so that Terraform can connect to the IBM Cloud Terraform
provider. See
[Create API Key](https://cloud.ibm.com/docs/account?topic=account-userapikey&interface=ui#create_user_key).

#### Aspera Binary Download

You can download the Apsera binaries needed for the server and client software from the
[IBM Aspera Download](https://www.ibm.com/products/aspera/downloads) page.

#### Install Files

Before running this automation you must upload the Aspera binary and your license file to a Cloud
Object Store bucket. See
[Getting started with Cloud Object Storage](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage)
or [Create Object Storage](https://cloud.ibm.com/objectstorage/create).

- Aspera Binary: Linux RPM binary, you will need the ppc64le version. This should have a file name
that starts with `ibm-aspera-hsts` and ends with `linux-ppc64le-release.rpm`.

- Aspera License: This will be an encoded file with the extension `aspera-license`.

#### PowerVS Workspace and Subnet

Before deploying, you will need to have created a landing zone for the Aspera server. This could be
a network in an existing PowervS Workspace or a new one you create. The volumes Aspera will write to
must be in the Workspace you ultimately wish to use them. These can be the volumes that Aspera
creates or via NFS shares from other machines on the same network.

#### NFS Export

Optionally, the Aspera server created by this automation can write data to an existing NFS share in
the same network (subnet). If chosen, before deploying this automation, you will first need to
create that NFS export for the data destination. You will supply the NFS mount string in the format
`<IP>:<shared directory>` to this automation's variable `nfs_mount_string`. This is not compatible
with creating attached storage for the Aspera server.

#### Connectivity

The Aspera server created by this automation will be connected to the private network you specify
with the variable `power_subnet_name`. This will allow it to connect with PowerVS machines on that
network. However, you must create a link between that subnet and your local network to upload files
to the Aspera server. One method of doing this is using the
[PowerVS VPN Gateway](https://github.com/IBM/power-vpn-gateway) automation.

### Deployment

#### Terraform CLI

You may choose to use the Terraform command line to deploy this module. You can download terraform here:
[Install Terraform](https://developer.hashicorp.com/terraform/install). Once installed, run
`terraform init` and then `terraform apply` to create the Aspera server. When you run apply,
terraform will prompt you for the required variables.

If you need to specify any of the optional variables, you can do so by exporting the variable using
the prefix `TF_VAR_`, using a `.tfvars` file, or by passing them as an option to the terraform
command using `-var`. For more information see
[Assigning Values to Root Module Variables](https://developer.hashicorp.com/terraform/language/values/variables#assigning-values-to-root-module-variables).

#### IBM Schematics

Schematics is an IBM Cloud service, that delivers Infrastructure as Code (IaC) tools as a service.
You can use the capabilities of Schematics to consistently deploy and manage your cloud
infrastructure environments. From a single pane of glass, you can run end-to-end automation to build
one or more stacks of cloud resources, manage their lifecycle, manage changes in their
configurations, deploy your app workloads, and perform day-2 operations.

To create an Aspera Server with Schematics,
first [create a workspace](https://cloud.ibm.com/schematics/workspaces/create). Specify this
repository for the repository URL and set the Terraform version to 1.5 or greater. Click Next, and then
give the workspace a name and any other details you'd like. You may choose to use any Resource Group
or Location.

| Specify Template | Workspace Details |
|---|---|
|![Specify Template](./doc/materials/schematics_specify_template.png)|![Workspace Details](./doc/materials/schematics_workspace_details.png)|

Once your Workspace is created. Use the Variables section below the Details section on the Settings
page to configure Aspera. You will need to edit and specify every variable that has a description
not starting with "Optional variable". If needed also specify any variables that are optional.

![Variables](./doc/materials/schematics_variables.png)

After setting the variables, you may use the "Apply plan" button at the top of the page to deploy.

![Apply Plan](./doc/materials/schematics_apply.png)

#### Wait for Deployment

Once the automation is applied, you will need to wait for the PowerVS server to boot and the install
scripts to complete. This can take 10-20 minutes. One way to ensure that the install is complete is
to look in the Cloud Portal at the Aspera PowerVS server's metadata. During the install, 2 network
adapters will be present. After the install is complete, only one network adapter (internal) will
remain attached to the PowerVS server.

### Post Deployment

#### Aspera Connection

This automation has two [output](#outputs) variables that will be shown once completed. The
`aspera_endpoint` will be the private network IP address of the Aspera server. You will need to have
completed the [connectivity](#connectivity) step in order to access this. Use your Aspera client to
create a new connection to this endpoint. For the credentials you must give the username `root` and
supply the private key matching the `ssh_key_name` key pair you specified previously.

#### NFS Export (Attached Storage)

If you've chosen to create the Aspera server with attached storage, you can access this by mounting
the [output](#outputs) variable `aspera_nfs_mount` from another server in the same network. This
will only be accessible while the Aspera server is running.

#### Working With Aspera

For more information on migration to PowerVS using Aspera technologies, visit the IBM Cloud
documentation:
[Migration strategies for IBM Power Systems Virtual Servers](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-migration-strategies-power#aspera-technologies).

## Variable Behavior

There are a number of variables defined in variables.tf used by this Terraform module to deploy and
configure your infrastructure. See [Inputs](#inputs) for full list of variables with their
descriptions, defaults, and conditions.

## Support

If you have problems or questions when using the underlying IBM Cloud infrastructure, you can get
help by searching for information or by asking questions through one of the forums. You can also
create a case in the
[IBM Cloud console](https://cloud.ibm.com/unifiedsupport/supportcenter).

For information about opening an IBM support ticket, see
[Contacting support](https://cloud.ibm.com/docs/get-support?topic=get-support-using-avatar).

To report bugs or make feature requests regarding this Terraform module, please create an issue in
this repository.

## References

- [What is Terraform](https://www.terraform.io/intro)
- [IBM Cloud provider Terraform getting started](https://cloud.ibm.com/docs/ibm-cloud-provider-for-terraform?topic=ibm-cloud-provider-for-terraform-getting-started)
- [IBM Cloud VPC VPN Gateway](https://cloud.ibm.com/docs/vpc?topic=vpc-using-vpn)
- [IBM Cloud PowerVS](https://www.ibm.com/products/power-virtual-server)
- [IBM Aspera](https://www.ibm.com/products/aspera)

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | 2.3.2 |
| <a name="requirement_ibm"></a> [ibm](#requirement\_ibm) | 1.62.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | 2.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ibm_iam_api_key.temp](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.62.0/docs/resources/iam_api_key) | resource |
| [ibm_pi_instance.aspera](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.62.0/docs/resources/pi_instance) | resource |
| [local_file.create_resource](https://registry.terraform.io/providers/hashicorp/local/2.4.0/docs/resources/file) | resource |
| [external_external.create_public_network](https://registry.terraform.io/providers/hashicorp/external/2.3.2/docs/data-sources/external) | data source |
| [external_external.create_volume](https://registry.terraform.io/providers/hashicorp/external/2.3.2/docs/data-sources/external) | data source |
| [external_external.import_catalog_image](https://registry.terraform.io/providers/hashicorp/external/2.3.2/docs/data-sources/external) | data source |
| [ibm_iam_auth_token.current](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.62.0/docs/data-sources/iam_auth_token) | data source |
| [ibm_pi_catalog_images.all](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.62.0/docs/data-sources/pi_catalog_images) | data source |
| [ibm_pi_key.aspera](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.62.0/docs/data-sources/pi_key) | data source |
| [ibm_pi_network.private](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.62.0/docs/data-sources/pi_network) | data source |
| [ibm_resource_instance.power_workspace](https://registry.terraform.io/providers/IBM-Cloud/ibm/1.62.0/docs/data-sources/resource_instance) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aspera_base_image_name"></a> [aspera\_base\_image\_name](#input\_aspera\_base\_image\_name) | Debug variable to specify the base OS for the Aspera server.<br>This Aspera server automation has been tested with CentOS 8.3 on PowerVS.<br>Use this variable if you wish to try another version. | `string` | `"CentOS-Stream-8"` | no |
| <a name="input_cos_bucket_name"></a> [cos\_bucket\_name](#input\_cos\_bucket\_name) | COS bucket that contains the Aspera installer and license file. | `string` | n/a | yes |
| <a name="input_cos_region"></a> [cos\_region](#input\_cos\_region) | Optional variable to specify the region the COS bucket resides in.<br><br>Available regions are: jp-osa, jp-tok, eu-de, eu-gb, ca-tor, us-south, us-east, and br-sao.<br>Please see [Regions](https://cloud.ibm.com/docs/overview?topic=overview-locations) for an updated list.<br><br>If not specified, the region corresponding to the `power_workspace_location` will be used. | `string` | `""` | no |
| <a name="input_data_location_file_path"></a> [data\_location\_file\_path](#input\_data\_location\_file\_path) | Debug variable to indicated where the file with PER location data is stored.<br>This variable is used for testing, and should not normally be altered. | `string` | `"./data/locations.yaml"` | no |
| <a name="input_export_volume_directory"></a> [export\_volume\_directory](#input\_export\_volume\_directory) | Optional variable for directory used for export volume. Must be absolute. | `string` | `"/aspera"` | no |
| <a name="input_export_volume_name"></a> [export\_volume\_name](#input\_export\_volume\_name) | Optional variable for name for volume created to export. | `string` | `"aspera"` | no |
| <a name="input_export_volume_size"></a> [export\_volume\_size](#input\_export\_volume\_size) | Either `nfs_mount_string` or `export_volume_size` MUST be specified.<br><br>Size of disk in GB for volume created to export.<br>When greater than 0, Aspera will use this as the destination instead of the `nfs_mount_string`.<br>When equal to 0, volume is not created and Aspera will use `nfs_mount_string` as its destination.<br>The export volume will be exported as an NFS share. | `number` | `0` | no |
| <a name="input_export_volume_type"></a> [export\_volume\_type](#input\_export\_volume\_type) | Optional variable for the type of disk for volume created to export.<br>Supported values are `ssd`, `standard`, `tier0`, `tier1`, `tier3`, and `tier5k`." | `string` | `"tier3"` | no |
| <a name="input_ibmcloud_api_key"></a> [ibmcloud\_api\_key](#input\_ibmcloud\_api\_key) | The IBM Cloud platform API key needed to deploy IAM enabled resources | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The name used for the Aspera server.<br>Other resources created will use this for their basename and be suffixed by a random identifier. | `string` | n/a | yes |
| <a name="input_nfs_mount_string"></a> [nfs\_mount\_string](#input\_nfs\_mount\_string) | Either `nfs_mount_string` or `export_volume_size` MUST be specified.<br><br>This will specify the NFS mount string in the format `<IP>:<shared directory>`<br>Used for the Aspera destination. | `string` | `""` | no |
| <a name="input_power_subnet_name"></a> [power\_subnet\_name](#input\_power\_subnet\_name) | Existing power network subnet name the Aspera server will be attached to. | `string` | n/a | yes |
| <a name="input_power_workspace_location"></a> [power\_workspace\_location](#input\_power\_workspace\_location) | The location used to create the power workspace.<br><br>Available locations are: dal10, dal12, us-south, us-east, wdc06, wdc07, sao01, sao04, tor01, mon01, eu-de-1, eu-de-2, lon04, lon06, syd04, syd05, tok04, osa21<br>Please see [PowerVS Locations](https://cloud.ibm.com/docs/power-iaas?topic=power-iaas-creating-power-virtual-server) for an updated list. | `string` | n/a | yes |
| <a name="input_power_workspace_name"></a> [power\_workspace\_name](#input\_power\_workspace\_name) | Existing power workspace name where the Aspera server will be created. | `string` | n/a | yes |
| <a name="input_powervs_instance_cores"></a> [powervs\_instance\_cores](#input\_powervs\_instance\_cores) | Optional variable to set CPU cores for PowerVS instance. | `number` | `2` | no |
| <a name="input_powervs_instance_memory"></a> [powervs\_instance\_memory](#input\_powervs\_instance\_memory) | Optional variable to set memory in GiB for PowerVS instance. | `number` | `8` | no |
| <a name="input_powervs_ip_address"></a> [powervs\_ip\_address](#input\_powervs\_ip\_address) | Optional variable to statically set the private network IP address for the Aspera server.<br>The default behavior is to randomly assign an IP from the `power_subnet_name` network. | `string` | `""` | no |
| <a name="input_powervs_processor_type"></a> [powervs\_processor\_type](#input\_powervs\_processor\_type) | Optional variable to set CPU processor type. Available options: `shared`, `capped` or `dedicated` | `string` | `"shared"` | no |
| <a name="input_powervs_system_type"></a> [powervs\_system\_type](#input\_powervs\_system\_type) | Optional variable to set Power system type. Available options: `s922`, `e880`, `e980`, `s1022`, and `e1080`. | `string` | `"s922"` | no |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | SSH key for the Aspera Server. This key must exist in the PowerVS Workspace.<br>It is used for root SSH access as well as the Aspera connection. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aspera_endpoint"></a> [aspera\_endpoint](#output\_aspera\_endpoint) | Aspera server endpoint for data transfer. |
| <a name="output_aspera_nfs_mount"></a> [aspera\_nfs\_mount](#output\_aspera\_nfs\_mount) | Mount point for exported volume. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
