#!/bin/bash

DIRNAME="$(cd $(dirname $0)/.. && pwd)"

usage() {
  cat << EOF
Usage: $0 <script>
EOF
}

[ -z "${DOCKER_ID_USER}" ] && echo "ERROR! DOCKER_ID_USER environment variable must be defined" >&2 && exit 1
[ -z "${VAULT_ADDR}" ] && echo "ERROR! VAULT_ADDR environment variable must be defined" >&2 && exit 1
[ $# -lt 1 ] && usage && exit 2

SCRIPT="$1"

DOCKER_IMAGE="${DOCKER_ID_USER}/builder:1.1"
ANSIBLE_DIR="/workspace/ansible"
DOCKER_OPTS="${DOCKER_OPTS:--t}"

[ -f ${HOME}/.kube/kubeconfig-home ] && OTHER_VOLUMES="${OTHER_VOLUMES} -v ${HOME}/.kube:/root/.kube"
[ -d /etc/ansible ]                  && OTHER_VOLUMES="${OTHER_VOLUMES} -v /etc/ansible:/etc/ansible"
[ -d /usr/local/etc/ansible ]        && OTHER_VOLUMES="${OTHER_VOLUMES} -v /usr/local/etc/ansible:/usr/local/etc/ansible"

docker run ${DOCKER_OPTS} --rm \
  --network=host \
  -e ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  -e ANSIBLE_HOST="${ANSIBLE_HOST}" \
  -e VAULT_CAHOSTVERIFY=no \
  -e VAULT_ADDR="${VAULT_ADDR}" \
  -v "${DIRNAME}":/workspace \
  -v "${HOME}/.vault-token:/root/.vault-token" \
  ${OTHER_VOLUMES} \
  -w /workspace \
  "${DOCKER_IMAGE}" \
  ${SCRIPT}
