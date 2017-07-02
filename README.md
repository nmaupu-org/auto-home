Personal machines provisioning scripts.

Prerequisites
=============

Install the following locally (not auto for now) :
- docker
- terraform 0.9.6 max (bug with current terraform code)
- terraform-provider-matchbox binary from https://github.com/coreos/terraform-provider-matchbox/releases in `/usr/local/bin`
- Configure your `~/.terraformrc` like so :
```
providers {
  matchbox = "/usr/local/bin/terraform-provider-matchbox"
}
```

---
**NOTE**

For an obscure reason, `terraform-provider-matchbox` is not working using docker container, so for now, using it locally :/

---

Ansible provisioning
====================

Use docker image nmaupu/builder like so :
```
./scripts/apply-ansible.sh home.yml --limit test
./scripts/apply-ansible.sh work.yml --limit test
```

`--limit test` is used to limit action to test machine configured in `ansible/hosts` file

Kubernetes cluster using CoreOS
===============================

Installation instructions
-------------------------

- First, install PXE server using ansible :
```
./scripts/apply-ansible.sh home.yml --limit raspbastion
```

- Second, prepare terraform source code :
```
ansible-playbook ansible/local-terraform-coreos.yml
```
Configuration can be done modifying `ansible/host_vars/localhost` file

- Add your ssh key to a local ssh-agent (important)

- Then, launch `terraform apply` using the script `scripts/terraform-kube.sh`. This script should get key and crt to connect to matchbox and deploy all configuration needed to bootstrap a kubernetes cluster. Beware though, Terraform will try to both update matchbox config but also provision servers which are not yet installed ...

- While Terraform is still running, pxe boot all servers and install them. In case of problems, try looking at `/var/lib/matchbox/groups` on PXE server to see if config has been updated as expected.
Once installed, the controllers and nodes will reboot automatically on CoreOS (installed on disk).

- When every machines have rebooted, terraform should have finished with an error, you can run the script again :
```
./scripts/terraform-kube.sh
```

Using kubectl
-------------

- Use the docker image nmaupu/builder :
```
DOCKER_OPTS=-it ./scripts/apply-wrapper.sh bash
```

- Then, simply use kubectl :
```
bash-4.3# kubectl get nodes
NAME                           STATUS    AGE       VERSION
kcontroller1.home.fossar.net   Ready     5m        v1.6.4+coreos.0
knode1.home.fossar.net         Ready     5m        v1.6.4+coreos.0
```
