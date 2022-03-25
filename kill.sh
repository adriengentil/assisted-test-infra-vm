#!/usr/bin/env bash

set -xeuo pipefail

# shellcheck source=.env
source ".env"

DOMAIN_NAME="${1}"

virsh undefine "${DOMAIN_NAME}"
virsh destroy "${DOMAIN_NAME}"
rm -rf "./${WORKDIR}/${DOMAIN_NAME}"
