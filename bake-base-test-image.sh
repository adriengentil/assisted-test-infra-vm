#!/usr/bin/env bash

set -xeuo pipefail

# shellcheck source=.env
source ".env"

DOMAIN_NAME="bake"

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
qemu-img create -f qcow2 \
                -F qcow2 \
                -o backing_file="$(readlink -f ${COMMON_WORKDIR}/${BASE_OS_FILENAME})" \
                "${COMMON_WORKDIR}/${BASE_TEST_IMAGE_FILENAME}" \
                "${VM_IMAGE_SIZE}"

# start VM
echo "Start the VM..."
virt-install --connect qemu:///system \
                -n "${DOMAIN_NAME}" \
                --vcpu "${VM_VCPUS}" \
                --ram="${VM_RAM}" \
                -w network=default \
                --import \
                --disk path="${COMMON_WORKDIR}/${BASE_TEST_IMAGE_FILENAME}" \
                --disk path="${COMMON_WORKDIR}/${CLOUD_INIT_ISO_NAME},device=cdrom"\
                --nographics \
                --noautoconsole

# shellcheck source=wait.sh
source ./wait-ssh.sh "${DOMAIN_NAME}"

scp -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}"  "${PULL_SECRET_FILE}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}:/tmp"
scp -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BAKE_SCRIPT}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}:/tmp"
ssh -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" << EOF
nohup sudo "/tmp/${BAKE_SCRIPT}" > /tmp/bake.log 2>&1 &
echo \$! > /tmp/bake.pid
EOF

until ! ssh -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" -- ps -p $\(cat /tmp/bake.pid\)
do
    ssh -o "StrictHostKeyChecking no" -i "${COMMON_WORKDIR}/${SSH_KEY_NAME}" "${BASE_OS_SSH_USER}@${VM_IP_ADDR}" -- tail -f /tmp/bake.log --pid $\(cat /tmp/bake.pid\)
done

virsh shutdown "${DOMAIN_NAME}"
sleep 60
./kill.sh "${DOMAIN_NAME}"