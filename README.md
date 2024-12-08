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


# Talos Linux installation

- Create an iso from the Factory (some pc requires `i915-ucode` and `mei` to boot successfully !)
- Report the ID and the version in `ansible/roles/openwrt_pxe/defaults/main.yml`
- Update PXE server with:

```bash
SSH_KEYS_DIR=/tmp VAULT_ADDR=not-used ./scripts/apply-ansible.sh home.yml --limit openwrt --tags pxe-ipxe,pxe-talos
```

- Boot from PXE and select Talos !

- Once done, the node should be in maintenance mode. Get configs:

``` bash
vault read -field talosconfig secret/talos-iot > talosconfig
vault read -field controlplane.yaml secret/talos-iot > controlplane.yaml
```

Note: initial configuration has been generated with the following command:

```bash
talosctl gen config iot https://192.168.12.40:6443 -f
```

Be careful to use to custom image from [Talos dev factory](https://factory.talos.dev/) with **i915** and **mei** activated !
One can also activate linux-util package.

- Apply the configuration with:

``` bash
talosctl apply-config --insecure --nodes 192.168.12.40 --file controlplane.yaml
```

- Once rebooted, bootstrap the cluster:

``` bash
talosctl bootstrap -e 192.168.12.40 -n 192.168.12.40 --talosconfig talosconfig
```

The node is bootstrapping. This operation can take several minutes to complete...

- When the cluster is ready, get the kubeconfig with:

``` bash
talosctl kubeconfig --nodes 192.168.12.40 --endpoints 192.168.12.40 --talosconfig talosconfig
```

- To start over and reset from the beginning:

``` bash
talosctl reset --nodes 192.168.12.40 -e 192.168.12.40 --talosconfig talosconfig --reboot --graceful=false
```
