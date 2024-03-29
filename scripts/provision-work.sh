#!/usr/bin/env bash

##
## Provisioning work machine from scratch
##

set -e -o pipefail

: "${DOCKER_ID_USER:=nmaupu}"
: "${HOME:=/root}"

# When executing from systemd, ~ directory is not bound to
# any user's home
export ANSIBLE_LOCAL_TEMP=$HOME/.ansible/tmp
export ANSIBLE_REMOTE_TEMP=$HOME/.ansible/tmp

# First getting local ip
: ${IPADDR:="$(/sbin/ip -4 -o addr show | awk '{ if($2 != "lo" && $2 != "docker0") { split($4, tab, "/"); print tab[1] } }')"}
[ -z "${IPADDR}" ] && echo "Cannot get local IP address, aborting" && exit 1
echo "IP address is ${IPADDR}"

# Installing necessary packages
apt-get update
apt-get install -y git ansible sudo

CLONE_DIR="${HOME}/bootstrap-machine"
rm -rf "${CLONE_DIR}"
: ${BRANCH:=master}
git clone --depth 1 --branch "${BRANCH}" https://github.com/nmaupu/auto-home "${CLONE_DIR}"

## From now on, we use script from freshly cloned repo

# Ansible version should be too old to provision everything, we will do it with docker
ansible-galaxy install -p /etc/ansible/roles geerlingguy.docker,4.1.0

cat << EOF > "${CLONE_DIR}/bootstrap.yml"
---
- name: Run docker installation playbook
  hosts: all
  vars:
    - docker_service_state: started
    - docker_service_enabled: true
    - docker_restart_handler_state: restarted
    - docker_apt_repository: "deb [arch={{ docker_apt_arch }}] {{ docker_repo_url }}/{{ ansible_distribution | lower }} bullseye {{ docker_apt_release_channel }}"
  roles:
    - geerlingguy.docker
EOF
ansible-playbook -u root -i "localhost, " -c local "${CLONE_DIR}/bootstrap.yml"

# Creating a local ssh key pair for ansible to be able to remotely connect to localhost
SSH_KEYS_DIR="${HOME}/ssh-bootstrap-keys"
# Creating home ssh directory if needed
mkdir -p "${HOME}/.ssh" && chmod 700 "${HOME}/.ssh"
# Generating temporary ssh keys
rm -rf "${SSH_KEYS_DIR}" && \
  mkdir -p "${SSH_KEYS_DIR}" && \
  ssh-keygen -q -b 2048 -t rsa -C dummy-bootstrap-key -f "${SSH_KEYS_DIR}/id_rsa" -N ''
# Authorizing this pub key to connect as root
cp "${SSH_KEYS_DIR}/id_rsa.pub" "${HOME}/.ssh/authorized_keys"

# Create a dummy inventory file
cat << EOF > ${CLONE_DIR}/dummy-bootstrap-inventory
[work]
local ansible_host=${IPADDR} ansible_user=root
EOF

# Install all requirements
ansible-galaxy install -p /etc/ansible/roles -r "${CLONE_DIR}/ansible/requirements.yml"

# Provision local machine
INVENTORY_FILE="/workspace/dummy-bootstrap-inventory" \
  DOCKER_ID_USER="${DOCKER_ID_USER}" \
  VAULT_ADDR="not used" \
  SSH_KEYS_DIR="${SSH_KEYS_DIR}" \
  "${CLONE_DIR}/scripts/apply-ansible.sh" work.yml

# Cleaning
rm -rf "${CLONE_DIR}" "${SSH_KEYS_DIR}"
