#!/usr/bin/env bash

set -xeuo pipefail

# shellcheck source=.env
source ".env"

DOMAIN_NAME="${1}"

if [ ! -e "${COMMON_WORKDIR}/${BASE_TEST_IMAGE_FILENAME}" ]
then
    ./bake-base-test-image.sh
fi

# Create qemu overlay and resize it
mkdir -p "${WORKDIR}/${DOMAIN_NAME}"
qemu-img create -f qcow2 \
                 -F qcow2 \
                 -o backing_file="$(readlink -f ${COMMON_WORKDIR}/${BASE_TEST_IMAGE_FILENAME})" \
                 "${WORKDIR}/${DOMAIN_NAME}/${VM_OS_FILENAME}" \
                 "${VM_IMAGE_SIZE}"

# start VM
echo "Start the VM..."
virt-install --connect qemu:///system \
                -n "${DOMAIN_NAME}" \
                --vcpu "${VM_VCPUS}" \
                --ram="${VM_RAM}" \
                -w network=default \
                --import \
                --disk path="${WORKDIR}/${DOMAIN_NAME}/${VM_OS_FILENAME}" \
                --nographics \
                --noautoconsole

# shellcheck source=wait.sh
source ./wait.sh "${DOMAIN_NAME}"

scp -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}"  "${PULL_SECRET_FILE}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}:/tmp"
scp -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${RUN_SCRIPT}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}:/tmp"
ssh -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" << EOF
nohup sudo "/tmp/${RUN_SCRIPT}" > /tmp/run.log 2>&1 &
echo \$! > /tmp/run.pid
EOF

until ! ssh -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" -- ps -p $\(cat /tmp/run.pid\)
do
    ssh -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" -- tail -f /tmp/run.log --pid $\(cat /tmp/run.pid\)
done
