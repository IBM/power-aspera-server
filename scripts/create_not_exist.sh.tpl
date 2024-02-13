#!/bin/bash

# This script is designed to find a Power resource by matching the type as its first argument and
# the name passed in the json query. If not found, it will attempt to create the resource using the
# full query passed. Return is limted to name and ID (format: `<type>ID`).

resource=$1
resources="$${resource}s"
query=$(jq -r '.|walk(if type == "string" then tonumber? // . else . end)')
name=$(jq -r .name <<< $query)

token="${ibmcloud_iam_token}"
crn="${pi_crn}"
region="${pi_region}"
instance_id="${pi_guid}"
endpoint="https://$region.power-iaas.cloud.ibm.com/pcloud/v1/cloud-instances/$instance_id/$resources"

f_result="$${resources}_result.json"
response=$(curl -s -w "%%{http_code}" -H "Authorization: $token" -H "CRN: $crn" $endpoint -o $f_result)
existing=$(jq -r ".$${resources}[] | select(.name==\"$name\")" $f_result)
if [[ -n "$existing" ]]; then
    jq ".|{name, $${resource}ID}" <<< $existing
    exit 0
fi

f_result="create_$${resource}_result.json"
response=$(curl -s -w "%%{http_code}" -X POST -H "Authorization: $token" -H "CRN: $crn" -H 'Content-Type: application/json' -d "$query" $endpoint -o $f_result)
if [[ $response -ge 200 ]] && [[ $response -le 202 ]]; then
    jq ".|{name, $${resource}ID}" $f_result
    exit 0
fi

>&2 echo Unable to create resource
exit 1
