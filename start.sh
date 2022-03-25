#!/usr/bin/env bash

set -xeuo pipefail

# shellcheck source=.env
source ".env"

DOMAIN_NAME="${1}"

# Common dir with OS, SSH keys, cloud-init iso
mkdir -p "${COMMON_WORKDIR}"

if [ ! -e "${COMMON_WORKDIR}/${BASE_OS_FILENAME}" ]
then
    curl -o "${COMMON_WORKDIR}/${BASE_OS_FILENAME}" "${BASE_OS_URL}"
fi

if [ ! -e "${COMMON_WORKDIR}/${SSH_KEY_NAME}" ]
then
    ssh-keygen -t ed25519 -N '' -f "${COMMON_WORKDIR}/${SSH_KEY_NAME}"
fi
SSH_PUB_KEY=$(cat "${COMMON_WORKDIR}/${SSH_KEY_NAME}.pub")

if [ ! -e "${COMMON_WORKDIR}/${CLOUD_INIT_ISO_NAME}" ]
then
    cat << EOF > "${COMMON_WORKDIR}/meta-data"
instance-id: ${CLOUD_INIT_INSTANCE_ID}
EOF
    cat << EOF > "${COMMON_WORKDIR}/user-data"
#cloud-config
ssh_authorized_keys:
  - ${SSH_PUB_KEY}
EOF
    genisoimage -o "${COMMON_WORKDIR}/${CLOUD_INIT_ISO_NAME}" \
                -V cidata \
                -r \
                -J "${COMMON_WORKDIR}/user-data" "${COMMON_WORKDIR}/meta-data"
fi

# Create qemu overlay and resize it
mkdir -p "${WORKDIR}/${DOMAIN_NAME}"
qemu-img create -f qcow2 -o backing_file="$(readlink -f ${COMMON_WORKDIR}/${BASE_OS_FILENAME})" "${WORKDIR}/${DOMAIN_NAME}/${VM_OS_FILENAME}"
qemu-img resize "${WORKDIR}/${DOMAIN_NAME}/${VM_OS_FILENAME}" "${VM_IMAGE_SIZE}"

# start VM
echo "Start the VM..."
virt-install --connect qemu:///system \
                -n "${DOMAIN_NAME}" \
                --vcpu "${VM_VCPUS}" \
                --ram="${VM_RAM}" \
                -w network=default \
                --import \
                --disk path="${WORKDIR}/${DOMAIN_NAME}/${VM_OS_FILENAME}" \
                --disk path="${COMMON_WORKDIR}/${CLOUD_INIT_ISO_NAME},device=cdrom"\
                --nographics \
                --noautoconsole

./boostrap.sh "${DOMAIN_NAME}"