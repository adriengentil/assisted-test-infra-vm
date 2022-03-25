#!/usr/bin/env bash

set -xeuo pipefail

# shellcheck source=.env
source ".env"

DOMAIN_NAME="${1}"

echo "Wait for the VM to grab an IP..."
VM_IP_ADDR=""
until [[ "${VM_IP_ADDR}" != "" ]]
do
    sleep 1
    VM_IP_ADDR=$(sudo virsh -q domifaddr "${DOMAIN_NAME}" | awk '{print $4}' | cut -d/ -f 1)
done

echo "Wait for SSH ${BASE_OS_SSH_USER}@${VM_IP_ADDR}..."
until ssh -o "StrictHostKeyChecking no" -q -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" exit
do
    sleep 1
done

export VM_IP_ADDR