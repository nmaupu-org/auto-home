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
ansible-galaxy install -p /etc/ansible/roles angstwad.docker_ubuntu,v3.3.2

## Ugly hack if debian is buster (testing in 2017)
# angstwad.docker_ubuntu is not ready for buster version of debian
# docker apt repo neither
if grep -q buster /etc/debian_version; then
  sed -i -e 's/stretch/buster/g' /etc/ansible/roles/angstwad.docker_ubuntu/tasks/main.yml
  sed -i -e 's/{{ ansible_lsb.codename|lower }}/stretch/' /etc/ansible/roles/angstwad.docker_ubuntu/defaults/main.yml
fi

# Installing docker on docker's stretch repo is failing on the first service start
# because it seems that docker is starting using init script (instead of systemd) and thus
# the socket does not exist and everything fails (socket is nowhere to be found).
# It finally works because systemd retries later and creates the socket
# (because a socket unit creates it). We can thus ignore this fail when installing
# but it is indeed very ugly.
cat << EOF | patch -i - /etc/ansible/roles/angstwad.docker_ubuntu/tasks/main.yml || true
@@ -113,6 +113,7 @@
     state: "{{ 'latest' if update_docker_package else 'present' }}"
     update_cache: "{{ update_docker_package }}"
     cache_valid_time: "{{ docker_apt_cache_valid_time }}"
+  ignore_errors: true

 - name: Set systemd playbook var
   set_fact:
EOF
## End ugly hack for buster

cat << EOF > "${CLONE_DIR}/bootstrap.yml"
---
- name: Run docker.ubuntu
  hosts: all
  roles:
    - angstwad.docker_ubuntu
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
