#!/usr/bin/env bash

set -xeuo pipefail

export REPO_DIR="/home/assisted"
PULL_SECRET="$(cat /tmp/pull-secret.json)"
export PULL_SECRET

dnf install -y make git jq python3-pip
pip3 install strato-skipper
export PATH="${PATH}:/usr/local/bin" # required to access skipper

git clone https://github.com/openshift/assisted-test-infra "${REPO_DIR}"
cd "${REPO_DIR}"

# fix libvirt uri
git remote add agentil https://github.com/adriengentil/assisted-test-infra.git
git fetch agentil
git cherry-pick 85d59f11ae8cfd6dc202fc182be895ee0f6a37d4

make create_full_environment