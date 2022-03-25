#!/usr/bin/env bash

set -xeuo pipefail

WORKDIR="workdir"
COMMON_WORKDIR="${WORKDIR}/common"
PULL_SECRET_FILE="${HOME}/pull-secret.json"

VM_OS_FILENAME="os.qcow2"
VM_IMAGE_SIZE="200G"
VM_VCPUS="64"
VM_RAM="200000"

BASE_OS_URL="https://dl.rockylinux.org/pub/rocky/8.5/images/Rocky-8-GenericCloud-8.5-20211114.2.x86_64.qcow2"
BASE_OS_FILENAME="base.qcow2"
BASE_OS_SSH_USER="rocky"

CLOUD_INIT_ISO_NAME="cloudinit.iso"
CLOUD_INIT_INSTANCE_ID="instance"

SSH_KEY_NAME="generic"

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
qemu-img create -f qcow2 -o backing_file="${COMMON_WORKDIR}/${BASE_OS_FILENAME}" "${WORKDIR}/${DOMAIN_NAME}/${VM_OS_FILENAME}"
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

echo "Wait for the VM to grab an IP..."
until VM_IP_ADDR=$(virsh -q domifaddr "${DOMAIN_NAME}" | awk '{print $4}' | cut -d/ -f 1)
do
    sleep 1
done

echo "Wait for SSH ${BASE_OS_SSH_USER}@${VM_IP_ADDR}..."
until ssh -q -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" exit
do
    sleep 1
done

scp -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}"  "${PULL_SECRET_FILE}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}:/tmp"
scp -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${RUN_SCRIPT}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}:/tmp"
ssh -q -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" -- nohup /tmp/run.sh > /tmp/run.log 2>&1