#!/bin/bash

if [[ -z $IBMCLOUD_IAM_TOKEN ]]; then
    echo You must specify your IBM Cloud IAM token as the environmental variable IBMCLOUD_IAM_TOKEN
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: get_instance_status <PowerVS Server ID>"
    exit 1
fi

token=$IBMCLOUD_IAM_TOKEN
crn="${pi_crn}"
f_result=/tmp/instance_result.json
f_pointer=/tmp/json.pointer
instance_id=$1

response=$(curl -s -w "%%{http_code}" -H "Authorization: $token" -H "CRN: $crn" https://${pi_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/${pi_guid}/pvm-instances/$instance_id -o $f_result)
if [[ $response -eq 200 ]]; then
    echo \"/health/status\" > $f_pointer; jsonpointer $f_pointer $f_result 2>&1 | tr -d '"'
    exit 0
fi

>&2 echo Error communicating with PowerVS API
exit 1
