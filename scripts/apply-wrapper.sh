#!/bin/bash

DIRNAME="$(cd $(dirname $0)/.. && pwd)"

usage() {
  cat << EOF
Usage: $0 <script>
EOF
}

[ -z "${DOCKER_ID_USER}" ] && echo "ERROR! DOCKER_ID_USER environment variable must be defined" >&2 && exit 1
[ $# -lt 1 ] && usage && exit 2

SCRIPT="$1"

DOCKER_IMAGE="${DOCKER_ID_USER}/builder"
ANSIBLE_DIR="/workspace/ansible"
DOCKER_OPTS="${DOCKER_OPTS:--t}"

[ -f ${HOME}/.kube/kubeconfig-home ] && OTHER_VOLUMES="-v ${HOME}/.kube:/root/.kube"

docker run ${DOCKER_OPTS} --rm \
  -e ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  -e ANSIBLE_HOST="${ANSIBLE_HOST}" \
  -v "${DIRNAME}":/workspace \
  -v ~/.ssh:/root/.ssh ${OTHER_VOLUMES} \
  -w /workspace \
  "${DOCKER_IMAGE}" \
  ${SCRIPT}
