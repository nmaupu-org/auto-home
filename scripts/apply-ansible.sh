#!/bin/bash

BASEDIR="$(cd $(dirname $0)/.. && pwd)"

usage() {
  cat << EOF
Usage: $0 <filename.yml> [extra-opts]

filename.yml     yaml file to execute (must be at the root of ansible directory)
extra-opts       Any extra options to pass to ansible-playbook command (e.g. --limit test)
EOF
}

[ $# -lt 1 ] && usage && exit 2

YAML_FILE="$1"; shift
EXTRA_OPTS="$@"
ANSIBLE_DIR="/workspace/ansible"
ANSIBLE_CFG="${ANSIBLE_DIR}/ansible.cfg"
CMD="ansible-playbook -i "${ANSIBLE_DIR}/hosts" ${EXTRA_OPTS} "${ANSIBLE_DIR}/${YAML_FILE}""

${BASEDIR}/scripts/apply-wrapper.sh "${CMD}"
