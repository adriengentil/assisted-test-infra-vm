#!/usr/bin/env bash

set -xeuo pipefail

export REPO_DIR="/home/assisted"
mkdir -p "${REPO_DIR}/minikube_home"
export MINIKUBE_HOME="${REPO_DIR}/minikube_home"

export TEST_FUNC=test_install
export TEST_SUITE=full
export TEST_TEARDOWN=false
export CHECK_CLUSTER_VERSION=True
export INSTALLER_KUBECONFIG="${REPO_DIR}/build/kubeconfig"

PULL_SECRET="$(cat /tmp/pull-secret.json)"
export PULL_SECRET

export PATH="${PATH}:/usr/local/bin" # required to access skipper

cd "${REPO_DIR}"
make create_full_environment run test_parallel

KUBECONFIG=$(find ${INSTALLER_KUBECONFIG} -type f)
export KUBECONFIG
export TEST_FUNC=test_late_binding_kube_api_sno
make deploy_assisted_operator test_kube_api_parallel
