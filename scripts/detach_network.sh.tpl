#!/bin/bash

if [[ -z $IBMCLOUD_IAM_TOKEN ]]; then
    echo You must specify your IBM Cloud IAM token as the environmental variable IBMCLOUD_IAM_TOKEN
    exit 1
fi

if [[ $# -ne 2 ]]; then
    echo "Usage: detach_network <PowerVS Server ID> <PowerVS Network ID>"
    exit 1
fi

token=$IBMCLOUD_IAM_TOKEN
crn="${pi_crn}"
f_result=/tmp/detach_result.json
instance_id=$1
network_id=$2

response=$(curl -s -w "%%{http_code}" -X DELETE -H "Authorization: $token" -H "CRN: $crn" https://${pi_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/${pi_guid}/pvm-instances/$instance_id/networks/$network_id -o $f_result)
if [[ $response -eq 200 ]]; then
    echo Succesfully detached network $2 from server $1
    exit 0
fi

>&2 echo Unable to detach network
exit 1
