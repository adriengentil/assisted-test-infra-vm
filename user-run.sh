#!/usr/bin/env bash

set -xeuo pipefail

export REPO_DIR="/home/assisted"
export TEST_FUNC=test_install
export TEST_SUITE=full

PULL_SECRET="$(cat /tmp/pull-secret.json)"
export PULL_SECRET

dnf install -y make git jq python3-pip
pip3 install strato-skipper
export PATH="${PATH}:/usr/local/bin" # required to access skipper

git clone https://github.com/openshift/assisted-test-infra /home/assisted
cd /home/assisted

# fix libvirt uri
git remote add agentil https://github.com/adriengentil/assisted-test-infra.git
git fetch agentil
git cherry-pick 85d59f11ae8cfd6dc202fc182be895ee0f6a37d4

make create_full_environment run test_parallel

export KUBECONFIG=/home/assisted/build/kubeconfig
export TEST_FUNC=test_late_binding_kube_api_sno
make deploy_assisted_operator test_kube_api_parallel
