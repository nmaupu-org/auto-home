#!/usr/bin/env bash

set -e -o pipefail

DIRNAME="$(dirname $0)"

## Call would be something like :
## sudo env USER_PASSWORD="$(mkpasswd -m sha-512 -S $(pwgen -ns 16 1))" ROOT_PASSWORD="$(mkpasswd -m sha-512 -S $(pwgen -ns 16 1))" ./create-debian-usb-key.sh /dev/sdx bobby "Bobby Lapointe"
## If passwords are not provided, they will be prompted.
## Set env var DO_NOT_FORMAT to skip usb formatting

DISK="$1"
USER_NAME="$2"
USER_FULLNAME="$3"
: "${DEBIAN_MIRROR:=http://ftp.debian.org}"
: "${ARCH:=amd64}"

#: "${DEBIAN_RELEASE:=stretch}"
#DEBIAN_VERSION=9.2.1
#: "${REMOTE_ISO:=https://cdimage.debian.org/debian-cd/current/${ARCH}/iso-cd/debian-${DEBIAN_VERSION}-${ARCH}-netinst.iso}"
: "${DEBIAN_RELEASE:=buster}"
: "${REMOTE_ISO:=https://cdimage.debian.org/cdimage/buster_di_alpha1/amd64/iso-cd/debian-buster-DI-alpha1-amd64-netinst.iso}"

ISO_NAME="${REMOTE_ISO##*/}"

usage() {
  cat << EOF
Usage: $0 <disk> <user> "<fulluser>"

disk     Disk to use (e.g. /dev/sdb) - will be wiped out
user     Regular username to use for the preseed installation
fulluser Regular full user name for the preseed installation

Passwords will be prompted if not set by environment variables

Overriding options via environment variables
DEBIAN_RELEASE  Release of Debian (default: stretch)
DEBIAN_MIRROR   Debian mirror (default: http://ftp.debian.org)
ARCH            Architecture (default: amd64)

All Passwords has to provided hashed (e.g. sha-512)
Use the following command to do so (mkpasswd is part of whois package):
  mkpasswd -m sha-512 -S $(pwgen -ns 16 1)

USER_PASSWORD   Regular user password
ROOT_PASSWORD   Password to use for root
EOF
}


[ $# -ne 3 ]              && echo "Please provide required args"    && usage && exit 1
[ -z "${DISK}" ]          && echo "Please provide a disk"           && usage && exit 1
[ -z "${USER_NAME}" ]     && echo "Please provide a username"       && usage && exit 1
[ -z "${USER_FULLNAME}" ] && echo "Please provide a user full name" && usage && exit 1

if [ -z "${USER_PASSWORD}" ]; then
  echo "Enter password for regular user ${USER_NAME}"
  USER_PASSWORD=$(mkpasswd -m sha-512 -S $(pwgen -ns 16 1))
fi

if [ -z "${ROOT_PASSWORD}" ]; then
  echo "Enter password for root user"
  ROOT_PASSWORD=$(mkpasswd -m sha-512 -S $(pwgen -ns 16 1))
fi

PART="${DISK}1"


# To accelerate debugging, use this env var to avoid reformatting and copying stuff
# each time you want to try something new
if [ -z "${DO_NOT_FORMAT}" ]; then
  echo "Wiping out beginning of ${DISK}"
  dd if=/dev/zero of="${DISK}" bs=10M count=5
  
  echo "Preparing disk partitions"
  (echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk "${DISK}"
  partx -u "${DISK}"
  
  echo "Creating a filesystem on ${PART}"
  mkfs.ext2 "${PART}"
fi

mkdir -p /mnt/usb
mount "${PART}" /mnt/usb
grub-install --root-directory=/mnt/usb "${DISK}"

echo "Download the initrd image"
mkdir -p "/mnt/usb/hdmedia-${DEBIAN_RELEASE}"
wget -O "/mnt/usb/hdmedia-${DEBIAN_RELEASE}/vmlinuz"   "${DEBIAN_MIRROR}/debian/dists/${DEBIAN_RELEASE}/main/installer-${ARCH}/current/images/hd-media/vmlinuz"
wget -O "/mnt/usb/hdmedia-${DEBIAN_RELEASE}/initrd.gz" "${DEBIAN_MIRROR}/debian/dists/${DEBIAN_RELEASE}/main/installer-${ARCH}/current/images/hd-media/initrd.gz"

echo "Getting ISO"
mkdir -p /mnt/usb/isos
wget --continue -O "/mnt/usb/isos/${ISO_NAME}" "${REMOTE_ISO}"

echo "Create grub config file"
cat << EOF > /mnt/usb/boot/grub/grub.cfg
set hdmedia="/hdmedia-${DEBIAN_RELEASE}"
set preseed="/hd-media/preseed"
set iso="/isos/${ISO_NAME}"

menuentry "Debian ${DEBIAN_RELEASE} ${ARCH} manual install" {
  linux  \$hdmedia/vmlinuz iso-scan/filename=\$iso priority=critical
  initrd \$hdmedia/initrd.gz
}
menuentry "Debian ${DEBIAN_RELEASE} ${ARCH} auto install" {
  linux  \$hdmedia/vmlinuz iso-scan/filename=\$iso priority=critical auto=true preseed/file=\$preseed/debian.preseed
  initrd \$hdmedia/initrd.gz
}
EOF
  
mkdir -p /mnt/usb/preseed
  
echo "Creating custom preseed late_command requirements"
cat << EOF > /mnt/usb/preseed/nobeep.conf
blacklist pcspkr
EOF
  
cat << EOF > /mnt/usb/preseed/bootstrap.service
[Unit]
Description=Bootstrap machine using auto-home
ConditionPathExists=!/usr/share/already-bootstrapped
After=network.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/root
ExecStartPre=/bin/sleep 30
ExecStart=/bin/bash -c 'set -o pipefail; /usr/bin/wget -O - https://raw.githubusercontent.com/nmaupu/auto-home/master/scripts/provision-work.sh | /bin/bash'
ExecStartPost=/bin/touch /usr/share/already-bootstrapped

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /mnt/usb/preseed/debian.preseed
d-i debian-installer/locale           string   en_US
d-i keyboard-configuration/xkb-keymap select   us
d-i console-tools/archs               select   skip-config
d-i time/zone                         string   Europe/Paris
d-i hw-detect/load_firmware           boolean  true
d-i netcfg/enable                     boolean  true
d-i netcfg/choose_interface           select   auto
d-i clock-setup/utc                   boolean  true
d-i clock-setup/ntp                   boolean  true

# Root and regular user
d-i passwd/make-user                  boolean  true
d-i passwd/root-password-crypted      password ${ROOT_PASSWORD}
d-i passwd/username                   string   ${USER_NAME}
d-i passwd/user-fullname              string   ${USER_FULLNAME}
d-i passwd/user-password-crypted      password ${USER_PASSWORD}

# We assume the target computer has only one harddrive.
# In most case the USB Flash drive is attached on /dev/sda
# but sometimes the harddrive is detected before the USB flash drive and
# it is attached on /dev/sda and the USB flash drive on /dev/sdb
# First line is to avoid erasing the disk before crypto
# This is discouraged but here it is for the science
# source: http://www.linuxjournal.com/content/preseeding-full-disk-encryption?page=0,1
d-i partman/early_command string \
    sed -i.bak 's/-f \$id\/skip_erase/-d \$id/g' /lib/partman/lib/crypto-base.sh; \
    USBDEV=\$(mount | grep hd-media | cut -d" " -f1 | sed "s/\(.*\)./\1/");\
    BOOTDEV=\$(list-devices disk | grep -v \$USBDEV | head -1);\
    debconf-set partman-auto/disk      \$BOOTDEV;\
    debconf-set grub-installer/bootdev \$BOOTDEV;

d-i grub-installer/only_debian   boolean true
d-i grub-installer/with_other_os boolean false

##############
# Partioning #
##############
d-i partman-auto/method                string  crypto
#d-i partman-crypto/passphrase          password password
#d-i partman-crypto/passphrase-again    password password
d-i partman/default_filesystem         string  xfs
d-i partman-auto/purge_lvm_from_device boolean true
d-i partman-lvm/device_remove_lvm      boolean true
d-i partman-lvm/device_remove_lvm_span boolean true
d-i partman/alignment                  string  optimal
d-i partman-auto-lvm/guided_size       string  80%

# When using crypto as partman-auto/method, in_vg NEEDS a space before the {
# whereas, normaly, you don't have to put any space before {
# See https://serverfault.com/questions/674137/preeseding-a-debian-stable-install-with-a-complex-partitioning-scheme-missing
d-i partman-auto-lvm/new_vg_name            string sys
d-i partman-auto/choose_recipe              select mine-encrypted
d-i partman-auto/expert_recipe              string mine-encrypted :: \
        512 512 1074 xfs                        \
            \$primary{ } \$bootable{ }          \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /boot }                 \
        .                                       \
        1000 10000 2000 xfs                     \
            \$lvmok{ }                          \
            lv_name{ root }                     \
            options/noatime{ noatime }          \
            label{ root }                       \
            in_vg { sys }                       \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ / }                     \
        .                                       \
        8000 512 8000 swap                      \
            \$lvmok{ }                          \
            in_vg { sys }                       \
            lv_name{ swap }                     \
            method{ swap }                      \
            format{ }                           \
        .                                       \
        8000 1000 10000 usr                     \
            \$lvmok{ }                          \
            options/noatime{ noatime }          \
            label{ usr }                        \
            in_vg { sys }                       \
            lv_name{ usr }                      \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /usr }                  \
        .                                       \
        8000 1000 10000 var                     \
            \$lvmok{ }                          \
            options/noatime{ noatime }          \
            label{ var }                        \
            in_vg { sys }                       \
            lv_name{ var }                      \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /var }                  \
        .                                       \
        20000 1000 50000 docker                 \
            \$lvmok{ }                          \
            options/noatime{ noatime }          \
            label{ docker }                     \
            in_vg { sys }                       \
            lv_name{ docker }                   \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /var/lib/docker }       \
        .                                       \
        2000 1000 2000 tmp                      \
            \$lvmok{ }                          \
            options/noatime{ noatime }          \
            label{ tmp }                        \
            in_vg { sys }                       \
            lv_name{ tmp }                      \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /tmp }                  \
        .                                       \
        5000 1000 10000 opt                     \
            \$lvmok{ }                          \
            options/noatime{ noatime }          \
            label{ opt }                        \
            in_vg { sys }                       \
            lv_name{ opt }                      \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /opt }                  \
        .                                       \
        20000 1000 50000 home                   \
            \$lvmok{ }                          \
            options/noatime{ noatime }          \
            label{ home }                       \
            in_vg { sys }                       \
            lv_name{ home }                     \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /home }                 \
        .                                       \
        1024 1024 1024 ext4                     \
            \$lvmok{ }                          \
            in_vg { sys }                       \
            lv_name{ lv_delete }                \
        .

# This makes partman automatically partition without confirmation
d-i partman-md/device_remove_md             boolean  true
d-i partman/mount_style                     select   uuid
d-i partman/choose_partition                select   finish
d-i partman/confirm_write_new_label         boolean  true
d-i partman-lvm/confirm_nooverwrite         boolean  true
d-i partman-lvm/confirm                     boolean  true
d-i partman/confirm_nooverwrite             boolean  true
d-i partman/confirm                         boolean  true

# Installation settings and mirror
d-i base-installer/install-recommends      boolean true
d-i apt-setup/non-free                     boolean true
d-i apt-setup/contrib                      boolean true
d-i apt-setup/use_mirror                   boolean true
d-i debian-installer/allow_unauthenticated boolean true
d-i mirror/country                         string  fr
d-i mirror/http/hostname                   string  ftp.fr.debian.org
d-i mirror/http/directory                  string  /debian
d-i mirror/http/proxy                      string

# Install a standard debian system + openssh-server
tasksel            tasksel/first                     multiselect standard
d-i                pkgsel/include                    string      openssh-server
d-i                pkgsel/upgrade                    select      none
popularity-contest popularity-contest/participate    boolean     false
d-i                finish-install/reboot_in_progress note

d-i preseed/late_command string \
  in-target apt-get update; \
  in-target apt-get -y upgrade; \
  lvremove -f /dev/sys/lv_delete; \
  cp /hd-media/preseed/nobeep.conf       /target/etc/modprobe.d/nobeep.conf; \
  cp /hd-media/preseed/bootstrap.service /target/etc/systemd/system/bootstrap.service; \
  in-target /bin/systemctl daemon-reload; \
  in-target /bin/systemctl enable bootstrap;
EOF

sync
umount /mnt/usb
