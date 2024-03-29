#!/bin/bash

BASEDIR=$(cd "$(dirname "$0")/.." && pwd)

usage() {
  cat << EOF
Usage: $0 <filename.yml> [extra-opts]

filename.yml     yaml file to execute (must be at the root of ansible directory)
extra-opts       Any extra options to pass to ansible-playbook command (e.g. --limit test)
EOF
}

[ $# -lt 1 ] && usage && exit 2

YAML_FILE="$1"; shift
EXTRA_OPTS="$*"
WORK_DIR="/workspace"
HOME_DIR="/home/builder"
ANSIBLE_DIR="${WORK_DIR}/ansible"
: "${SSH_KEYS_DIR:=${HOME}/.ssh}"
: "${INVENTORY_FILE:=${ANSIBLE_DIR}/hosts}"
#CMD="ansible-playbook -i "${INVENTORY_FILE}" -c paramiko ${EXTRA_OPTS} "${ANSIBLE_DIR}/${YAML_FILE}""
CMD="ansible-playbook -i ${INVENTORY_FILE} ${EXTRA_OPTS} "${ANSIBLE_DIR}/${YAML_FILE}""

OTHER_VOLUMES="-v ${SSH_KEYS_DIR}:${HOME_DIR}/.ssh" \
  "${BASEDIR}/scripts/apply-wrapper.sh" "${CMD}"
