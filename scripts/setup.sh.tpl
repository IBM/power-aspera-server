#!/bin/bash

apikey="${ibmcloud_api_key}"
apikey_id="${ibmcloud_api_key_id}"
public_network_id="${pi_public_network_id}"
cos_bucket_name="${cos_bucket_name}"
region="${vpc_region}"
cos_region="${cos_region}"
nfs_mount_string="${nfs_mount_string}"
aspera_dl_dir=${export_volume_directory}
private_network_gateway="${pi_private_network_gateway}"
private_network_cidr="${pi_private_network_cidr}"
health_ok=OK
f_pointer=/tmp/json.pointer
download_dir=/tmp
aspera_part_label=aspera-data

# Wait for network
until ping -c1 clis.cloud.ibm.com >/dev/null 2>&1; do :; done
echo Network found

# Install IBM Cloud CLI
curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
export IBMCLOUD_API_KEY=$apikey
ibmcloud login -r $region -a https://cloud.ibm.com
ibmcloud plugin install cos

# Download aspera files
f_aspera_lisence=""
f_aspera_installer=""
f_result=/tmp/objects.json
aspera_installer_pattern="^ibm-aspera-(.*)-linux-ppc64le-release.rpm$"
ibmcloud target -r $cos_region
ibmcloud cos config ddl --ddl $download_dir
ibmcloud cos objects --bucket $cos_bucket_name --output json > $f_result
for ((i=0;i<=200;i++)); do
    # The version of jsonpointer included with Linux-CentOS-8-3 requires a file for BOTH the pointer and the json data
    k=$(echo \"/Contents/$i/Key\" > $f_pointer; jsonpointer $f_pointer $f_result 2>&1 | tr -d '"')

    if [[ $k == *".aspera-license" ]]; then
        f_aspera_lisence=$k
        ibmcloud cos download --bucket $cos_bucket_name --key $k
    fi

    if [[ $k =~ $aspera_installer_pattern ]]; then
        f_aspera_installer=$k
        ibmcloud cos download --bucket $cos_bucket_name --key $k
    fi

    if [[ $f_aspera_installer ]] && [[ $f_aspera_lisence ]]; then
        break
    fi

    if [[ $k == "Could not resolve pointer"* ]]; then
        >&2 echo Unable to download required Aspera installer and license
        exit 1
    fi
done
ibmcloud target -r $region
echo Aspera downloaded successfully

# Mount Aspera Destination
sudo mkdir -p $aspera_dl_dir
if [[ -z "$nfs_mount_string" ]]; then
    # Look for existing aspera partition
    storage_part=$(find -L /dev/mapper -samefile /dev/disk/by-label/$aspera_part_label 2> /dev/null)
    if [[ -z "$storage_part" ]]; then
        # Find new local storage
        primary_part=$(mount | grep /dev/mapper | awk 'NR==1{print $1}')
        mpaths=($(ls /dev/mapper/mpath* | grep -v $${primary_part::-1}))
        if [[ $${#mpaths[@]} != 1 ]]; then
            echo Local storage not found; exit 1
        fi
        storage_dev=$${mpaths[0]}
        storage_part=$${storage_dev}1

        # Partition local storage
        parted --s -a minimal -- $storage_dev mklabel gpt mkpart primary 0 -1
        mkfs.ext4 $storage_part
        e2label $storage_part $aspera_part_label
    fi

    # Mount local storage
    echo "$storage_part $aspera_dl_dir ext4 defaults 0 2" >> /etc/fstab
    mount -a

    # Export local storage
    chmod 777 $aspera_dl_dir
    systemctl enable --now nfs-server.service rpcbind.service
    echo "$aspera_dl_dir $${private_network_cidr}(rw,sync,no_subtree_check)" >> /etc/exports
    exportfs -ra
else
    # Mount remote storage
    echo "$nfs_mount_string $aspera_dl_dir nfs defaults 0 0" >> /etc/fstab
    mount -a
fi

# Install Aspera
rpm -ivh $download_dir/$f_aspera_installer
mv $download_dir/$f_aspera_lisence /opt/aspera/etc/aspera-license
asconfigurator -F "set_user_data;user_name,root;absolute,$aspera_dl_dir"
ascp -A

# Get Token and export for detach calls
f_result=/tmp/token.json
ibmcloud iam oauth-tokens --output json > $f_result
token=$(echo \"/iam_token\" > $f_pointer; jsonpointer $f_pointer $f_result 2>&1 | tr -d '"')
if [[ $token == "Could not resolve pointer"* ]]; then
    >&2 echo Unable to get IAM token
    exit 1
fi
export IBMCLOUD_IAM_TOKEN=$token
echo IAM token set

# Wait for health to be "OK"
instance_id=$(get_instance_id)
active_timeout=1200
end=$(($(date +%s)+$active_timeout))
while [[ $(date +%s) -lt $end ]]; do
    health_status=$(get_health_status $instance_id)
    if [[ $? -eq 0 ]] && [[ $health_status == $health_ok ]]; then
        break
    fi
    sleep 5
done
echo Instance health OK

# Delete API key
ibmcloud iam api-key-delete -f $apikey_id

# Get Interfaces
public_interface=$(ip route show | grep default | awk '{print $5}')
private_interface=$(ip route show | grep "$private_network_cidr via" | awk '{print $5}')

# Detach Public
detach_network $instance_id $public_network_id

# Reconfigure Network
echo "GATEWAY=$private_network_gateway" >> /etc/sysconfig/network-scripts/ifcfg-$private_interface
echo "DEFROUTE=yes" >> /etc/sysconfig/network-scripts/ifcfg-$private_interface
rm -f /etc/sysconfig/network-scripts/ifcfg-$public_interface
nmcli networking off && nmcli networking on
systemctl restart NetworkManager

# Remove this file
rm $0
