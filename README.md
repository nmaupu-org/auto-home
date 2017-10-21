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

Ansibling and kubernetizing
===========================

Kubernetes architecture is quite simple :

- a CoreOS cluster composed of 4 machines (1 controller and 3 nodes)
- traefik as ingress controller
- a nginx acting as reverse proxy outside the cluster with a very basic configuration

General use
-----------

Use docker image nmaupu/builder like so :
```
./scripts/apply-ansible.sh home-pxe.yml --limit test
./scripts/apply-ansible.sh work.yml --limit test
```

`--limit test` is used to limit action to test machine configured in `ansible/hosts` file

Reverse proxy provisioning
--------------------------

Kubernetes requires a reverse proxy outside the cluster to serve ingress controller. I am using a freenas jail here (FreeBSD).
FreeNAS jails can be created using the api. The jail can then be provisionned as usual (but needs python2.7 installed before !)
```
./freenas/kube-rproxy-jail.py nas.home.fossar.net root password | jq
./scripts/apply-ansible.sh home-kube-rproxy.yml
```

Apply kubernetes yaml
---------------------

```
./scripts/apply-wrapper.sh /workspace/scripts/kube-provision-tools.sh
```

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

Useful tools and projects
=========================

- https://github.com/coreos/matchbox
- https://github.com/hjacobs/kube-ops-view
- https://github.com/containous/traefik

