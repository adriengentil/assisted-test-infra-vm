#!/usr/bin/env bash

set -xeuo pipefail

# shellcheck source=.env
source ".env"

DOMAIN_NAME="${1}"

virsh undefine "${DOMAIN_NAME}" || true
virsh destroy "${DOMAIN_NAME}" || true
rm -rf "./${WORKDIR}/${DOMAIN_NAME}" || true
