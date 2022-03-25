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
    VM_IP_ADDR=$(virsh -q domifaddr "${DOMAIN_NAME}" | awk '{print $4}' | cut -d/ -f 1)
done

echo "Wait for SSH ${BASE_OS_SSH_USER}@${VM_IP_ADDR}..."
until ssh -q -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" exit
do
    sleep 1
done

scp -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}"  "${PULL_SECRET_FILE}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}:/tmp"
scp -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${RUN_SCRIPT}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}:/tmp"
ssh -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" -- nohup /tmp/run.sh > /tmp/run.log 2>&1