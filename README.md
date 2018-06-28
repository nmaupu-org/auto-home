Personal machines provisioning scripts.

# Work machine

USB boot disk creation
======================

Distribution used is Debian and USB bootable disk can be created using 'scripts/create-debian-usb-key.sh':
```
sudo ./scripts/create-debian-usb-key.sh efi /dev/sdb bobby "Bobby Lapointe"
```

`/dev/sdb` has to be replaced by the USB device of course.
Passwords for user `bobby` and `root` will be prompted. You can also provide a hash via 2 environment variables:

If using that on a legacy system (not EFI ready), use `legacy` instead of `efi` on the previous command line.

```
sudo -i
UP=<hash>
RP=<hash>
USER_PASSWORD=${UP} ROOT_PASSWORD=${RP} ./scripts/create-debian-usb-key.sh /dev/sdb bobby "Bobby Lapointe"
```

Hash's password can be calculated using the following command:
```
mkpasswd -m sha-512 -S $(pwgen -ns 16 1)
```

It is also possible to update the USB stick without formatting it again:
```
sudo env DO_NOT_FORMAT=yes ./scripts/create-debian-usb-key.sh /dev/sdb bobby "Bobby Lapointe"
```

Installation
============

Preseeded installation is done choosing the relevant entry in the grub bootloader.
The only prompt you will have is the one for *physical volume encryption* passphrase.

At the end of installation, machine will reboot itself and boot into Debian.
When booted, the system will bootstrap itself using systemd `bootstrap.service` unit installed at the end of preseed.
This unit will *wget* `scripts/provision-work.sh` and will pipe it to *bash*.

Logs are available as root with:

```
journalctl -u bootstrap -f
```

In case of success at the end of the process, the file `/usr/share/already-bootstrapped` will be created.
Unit **will not run** if this file is present.

Troubleshooting
===============

It is possible to run the process manually using the following command as root:
```
wget -O - https://raw.githubusercontent.com/nmaupu/auto-home/master/scripts/provision-work.sh | /bin/bash
```

or simply by restarting the unit:
```
systemctl restart bootstrap
```

Day to day usage
================

Once bootstrapped, updates are assured with a *regular user* from the repo:
`mymachine` has to be present in `ansible/hosts` file before proceeding.

```
VAULT_ADDR=not-used ./scripts/apply-ansible.sh work.yml --limit mymachine
```

Bunch of tags are also available and can be combined:
```
.VAULT_ADDR=not-used /scripts/apply-ansible.sh work.yml --limit mymachine --tags linux-base,sshd,work
```

*Work* part can also be cut down using several tags:
  - init
  - rxvt
  - golang
  - zsh
  - fzf
  - vim
  - xmonad


# CoreOS, Kubernetes and Home

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
/scripts/apply-ansible.sh <file>.yml --limit test --tags <tags>
/scripts/apply-ansible.sh work.yml --limit test
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

Troubleshooting
===============

If cluster crashes somehow and controller does boot but does not start those vital containers :
```
ssh kcontroller1 -l core
$ sudo rm -f /opt/bootkube/init_bootkube.done
$ sudo systemctl start bootkube
$ journalctl -u bootkube -f
```

Be patient !

Upgrading kubernetes binaries
=============================

CoreOS self-hosts a kubernetes cluster. Its lifecycle is not dependent on CoreOS version so far. Kubernetes has to be upgraded separately from CoreOS!
For CoreOS releases, see: https://coreos.com/releases/
To get latest kubernetes release images used by CoreOS, see: https://github.com/coreos/kubernetes/releases
Note: replace `+` character by `_` ;-)

For a kubernetes doc, see: See: https://coreos.com/matchbox/docs/latest/bootkube-upgrades.html

Note: To upgrade kubelets (which are using systemd on each host), one can do the following:
- edit /etc/kubernetes/kubelet.env
- Change the version of the image
- restart kubelet service

In case of issues, see troubleshooting above to get back a running cluster.
