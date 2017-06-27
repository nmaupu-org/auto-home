#!/bin/bash

DIRNAME="$(dirname $0)"

ANSIBLE_CONFIG="${DIRNAME}/ansible.cfg" \
  ansible-playbook -i hosts --extra-vars "pxe_host=test" site.yml
