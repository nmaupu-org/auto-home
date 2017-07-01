#!/bin/bash

DIRNAME="$(cd $(dirname $0)/.. && pwd)"

usage() {
  cat << EOF
Usage: $0 <filename.yml> [extra-opts]

filename.yml     yaml file to execute (must be at the root of ansible directory)
extra-opts       Any extra options to pass to ansible-playbook command (e.g. --limit test)
EOF
}

[ -z "${DOCKER_ID_USER}" ] && echo "ERROR! DOCKER_ID_USER environment variable must be defined" >&2 && exit 1
[ $# -lt 1 ] && usage && exit 2

YAML_FILE="$1"; shift
EXTRA_OPTS="$@"

DOCKER_IMAGE="${DOCKER_ID_USER}/builder"
ANSIBLE_DIR="/workspace/ansible"
CMD="ansible-playbook -i "${ANSIBLE_DIR}/hosts" ${EXTRA_OPTS} "${ANSIBLE_DIR}/${YAML_FILE}""

docker run -t --rm \
  -e ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  -v "${DIRNAME}":/workspace \
  -v ~/.ssh:/root/.ssh \
  -w /workspace \
  "${DOCKER_IMAGE}" \
  ${CMD}
