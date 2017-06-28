#!/bin/bash

DIRNAME="$(dirname $0)"
ANSIBLE_DIR="${DIRNAME}/ansible"

usage() {
  cat << EOF
Usage: $0 <file.yml> [extra-opts]
EOF
}

[ $# -lt 1 ] && usage && exit 1

YAML_FILE="$1"
EXTRA_OPTS="$@"

ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg" \
  ansible-playbook -i "${ANSIBLE_DIR}/hosts" "${EXTRA_OPTS}" "${YAML_FILE}"
