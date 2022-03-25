#!/usr/bin/env bash

sudo -s

set -xeuo pipefail

export REPO_DIR="/home/assisted"
export TEST_FUNC=test_install
export TEST_SUITE=full

PULL_SECRET="$(cat /tmp/pull-secret.json)"
export PULL_SECRET

dnf install -y make git jq
git clone https://github.com/openshift/assisted-test-infra /home/assisted
cd /home/assisted

make create_full_environment run test_parallel

export KUBECONFIG=/home/assisted/build/kubeconfig
export TEST_FUNC=test_late_binding_kube_api_sno
make deploy_assisted_operator test_kube_api_parallel
