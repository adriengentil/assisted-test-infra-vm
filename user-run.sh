#!/usr/bin/env bash

set -xeuo pipefail

export REPO_DIR="/home/assisted"
export TEST_FUNC=test_install
export TEST_SUITE=full
export TEST_TEARDOWN=false

PULL_SECRET="$(cat /tmp/pull-secret.json)"
export PULL_SECRET

export PATH="${PATH}:/usr/local/bin" # required to access skipper

cd "${REPO_DIR}"
minikube start
make run test_parallel

export KUBECONFIG=/home/assisted/build/kubeconfig
export TEST_FUNC=test_late_binding_kube_api_sno
make deploy_assisted_operator test_kube_api_parallel
