#!/bin/bash

if [[ -z $IBMCLOUD_IAM_TOKEN ]]; then
    echo You must specify your IBM Cloud IAM token as the environmental variable IBMCLOUD_IAM_TOKEN
    exit 1
fi

token=$IBMCLOUD_IAM_TOKEN
crn="${pi_crn}"
f_result=/tmp/instances_result.json
f_pointer=/tmp/json.pointer

response=$(curl -s -w "%%{http_code}" -H "Authorization: $token" -H "CRN: $crn" https://${pi_region}.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/${pi_guid}/pvm-instances -o $f_result)
if [[ $response -ne 200 ]]; then
    >&2 echo Error communicating with PowerVS API
    exit 1
fi

# jsonschema not found on Power's Linux-CentOS-8-3 (using jsonschema-3 which is)
jsonschema-3 $f_result &> /dev/null
if [[ $? -ne 0 ]]; then
    >&2 echo Invalid JSON result
    exit 1
fi

serverName=$(hostname -s)
for ((i=0;i<=200;i++)); do
    # The version of jsonpointer included with Linux-CentOS-8-3 requires a file for BOTH the pointer and the json data
    o=$(echo \"/pvmInstances/$i/serverName\" > $f_pointer; jsonpointer $f_pointer $f_result 2>&1 | tr -d '"')

    shopt -s nocasematch
    if [[ $o == $serverName ]]; then
        echo \"/pvmInstances/$i/pvmInstanceID\" > $f_pointer; jsonpointer $f_pointer $f_result | tr -d '"'
        exit 0
    fi

    if [[ $o == "Could not resolve pointer"* ]]; then
        >&2 echo Unable to resolve this instance ID
        exit 1
    fi
done

>&2 echo Exhausted server instance search
exit 1
