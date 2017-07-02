#!/bin/bash

## Terraform is used to update config on matchbox side
## AND to provision kube controllers / nodes using the same set of commands

set -e

BASEDIR=$(cd $(dirname $0)/.. && pwd)

# Get login/ip of the machine on which is installed matchbox
ANSIBLE_HOST=${ANSIBLE_HOST:-raspbastion}
eval "$(grep "^${ANSIBLE_HOST} " ${BASEDIR}/ansible/hosts | tr -s " " "\n" | grep '=')"

echo "Getting matchbox client crt and key from root@${ansible_host}"

mkdir -p ~/.matchbox && \
  scp root@${ansible_host}:/usr/local/matchbox-*/scripts/tls/client.* ~/.matchbox && \
  scp root@${ansible_host}:/usr/local/matchbox-*/scripts/tls/ca.crt   ~/.matchbox
[ $? -gt 0 ] && echo "Cannot get client keys, aborting." >&2 && exit 1

cd ${BASEDIR}/terraform/examples/terraform/bootkube-install
rm -f terraform.tfstate*
terraform get && TF_LOG=debug terraform apply

if [ -f ${BASEDIR}/terraform/examples/terraform/bootkube-install/assets/auth/kubeconfig ]; then
  mkdir -p ~/.kube
  cp -a ${BASEDIR}/terraform/examples/terraform/bootkube-install/assets/auth/kubeconfig ~/.kube/kubeconfig-home
fi
