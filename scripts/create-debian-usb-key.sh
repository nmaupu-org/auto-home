#!/usr/bin/env bash

set -e -x -o pipefail

DIRNAME="$(dirname $0)"

DISK="$1"
: "${DEBIAN_RELEASE:=stretch}"
: "${DEBIAN_VERSION:=9.2.1}"
: "${DEBIAN_MIRROR:=http://ftp.debian.org}"
: "${ARCH:=amd64}"
: "${REMOTE_ISO:=https://cdimage.debian.org/debian-cd/current/${ARCH}/iso-cd/debian-${DEBIAN_VERSION}-${ARCH}-netinst.iso}"
ISO_NAME="${REMOTE_ISO##*/}"

usage() {
  cat << EOF
Usage: $0 <disk> <iso>

disk     Disk to use (e.g. /dev/sdb) - will be wiped out

Overriding options via environment variables
DEBIAN_RELEASE  Release of Debian (default: buster)
DEBIAN_VERSION  VERSION of Debian (default: 9.2.1)
DEBIAN_MIRROR   Debian mirror (default: http://ftp.debian.org)
ARCH            Architecture (default: amd64)
EOF
}

[ $# -ne 1 ]     && echo "Please provide required args" && usage && exit 1
[ -z "${DISK}" ] && echo "Please provide a disk"        && usage && exit 1

PART="${DISK}1"

echo "Getting ISO"
wget --continue -O "${DIRNAME}/${ISO_NAME}" "${REMOTE_ISO}"
ISO="${DIRNAME}/${ISO_NAME}"

echo "Wiping out beginning of ${DISK}"
dd if=/dev/zero of="${DISK}" bs=10M count=5

echo "Preparing disk partitions"
(echo n; echo p; echo 1; echo ; echo ; echo w) | fdisk "${DISK}"
partx -u /dev/sdb

echo "Creating a filesystem on ${PART}"
mkfs.ext2 "${PART}"

mkdir -p /mnt/usb
mount "${PART}" /mnt/usb
grub-install --root-directory=/mnt/usb "${DISK}"

echo "Download the initrd image"
mkdir "/mnt/usb/hdmedia-${DEBIAN_RELEASE}"
wget -O "/mnt/usb/hdmedia-${DEBIAN_RELEASE}/vmlinuz"   "${DEBIAN_MIRROR}/debian/dists/${DEBIAN_RELEASE}/main/installer-${ARCH}/current/images/hd-media/vmlinuz"
wget -O "/mnt/usb/hdmedia-${DEBIAN_RELEASE}/initrd.gz" "${DEBIAN_MIRROR}/debian/dists/${DEBIAN_RELEASE}/main/installer-${ARCH}/current/images/hd-media/initrd.gz"
mkdir -p /mnt/usb/isos
rsync -aP "${ISO}" /mnt/usb/isos

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

mkdir /mnt/usb/preseed

echo "Creating custom preseed late_command requirements"
cat << EOF > /mnt/usb/preseed/nobeep.conf
blacklist pcspkr
EOF

cat << EOF > /mnt/usb/preseed/bootstrap.service
[Unit]
Description=Bootstrap machine using auto-home
ConditionPathExists=!/usr/share/already-bootstrapped
[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/root
ExecStart=wget -O - https://raw.githubusercontent.com/nmaupu/auto-home/master/scripts/provision-work.sh | bash
ExecStartPost=/bin/touch /usr/share/already-bootstrapped
EOF

cat << EOF > /mnt/usb/preseed/debian.preseed
d-i debian-installer/locale           string   en_US
d-i keyboard-configuration/xkb-keymap select   us
d-i console-tools/archs               select   skip-config
d-i time/zone                         string   EU/Paris
d-i hw-detect/load_firmware           boolean  true
d-i passwd/make-user                  boolean  false
d-i passwd/root-password              password root
d-i passwd/root-password-again        password root
d-i netcfg/enable                     boolean  false
d-i clock-setup/utc                   boolean  true
d-i clock-setup/ntp                   boolean  true

# We assume the target computer has only one harddrive.
# In most case the USB Flash drive is attached on /dev/sda
# but sometimes the harddrive is detected before the USB flash drive and
# it is attached on /dev/sda and the USB flash drive on /dev/sdb
# You can set manually partman-auto/disk and grub-installer/bootdev or
# used the early_command option to automatically set the device to use.
d-i partman/early_command string \
    USBDEV=\$(mount | grep hd-media | cut -d" " -f1 | sed "s/\(.*\)./\1/");\
    BOOTDEV=\$(list-devices disk | grep -v \$USBDEV | head -1);\
    debconf-set partman-auto/disk \$BOOTDEV;\
    debconf-set grub-installer/bootdev \$BOOTDEV;

d-i grub-installer/only_debian   boolean true
d-i grub-installer/with_other_os boolean false

##############
# Partioning #
##############
d-i partman-auto/method                string  lvm
d-i partman-auto/purge_lvm_from_device boolean true
d-i partman-auto-lvm/new_vg_name       string  sys
d-i partman-lvm/device_remove_lvm      boolean true
d-i partman-lvm/device_remove_lvm_span boolean true
d-i partman/alignment                  string  optimal
d-i partman-auto-lvm/guided_size       string  max

# This makes partman automatically partition without confirmation, provided
# that you told it what to do using one of the methods above.
d-i partman-lvm/confirm             boolean true
d-i partman/mount_style             select  uuid
d-i partman/choose_partition        select  Finish partitioning and write changes to disk
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition        select  finish
d-i partman/confirm                 boolean true
d-i partman-auto/expert_recipe string           \
    my-scheme ::                                \
        2000 10000 2000 xfs                     \
            \$primary{ }                        \
            \$bootable{ }                       \
            method{ format } format{ }          \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ / }                     \
        .                                       \
        100 1000 1000000000 xfs                 \
            \$defaultignore{ }                  \
            \$primary{ }                        \
            method{ lvm }                       \
            vg_name{ sys }                      \
        .                                       \
        8000 512 8000 swap                      \
            \$lvmok{ }                          \
            in_vg{ sys }                        \
            lv_name{ swap }                     \
            method{ swap }                      \
            format{ }                           \
        .                                       \
        8000 1000 10000 usr                     \
            \$lvmok{ }                          \
            in_vg{ sys }                        \
            lv_name{ usr }                      \
            method{ format }                    \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /usr }                  \
            format{ }                           \
        .                                       \
        8000 1000 10000 var                     \
            \$lvmok{ }                          \
            in_vg{ sys }                        \
            lv_name{ var }                      \
            method{ format }                    \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /var }                  \
            format{ }                           \
        .                                       \
        10000 1000 50000 var-docker             \
            \$lvmok{ }                          \
            in_vg{ sys }                        \
            lv_name{ var-docker }               \
            method{ format }                    \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /var/lib/docker }       \
            format{ }                           \
        .                                       \
        2000 1000 2000 tmp                      \
            \$lvmok{ }                          \
            in_vg{ sys }                        \
            lv_name{ tmp }                      \
            method{ format }                    \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /tmp }                  \
            format{ }                           \
        .                                       \
        5000 1000 10000 opt                     \
            \$lvmok{ }                          \
            in_vg{ sys }                        \
            lv_name{ opt }                      \
            method{ format }                    \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /opt }                  \
            format{ }                           \
        .                                       \
        5000 1000 50000 home                    \
            \$lvmok{ }                          \
            in_vg{ sys }                        \
            lv_name{ home }                     \
            method{ format }                    \
            use_filesystem{ } filesystem{ xfs } \
            mountpoint{ /home }                 \
            format{ }                           \
        .


# Installation settings and mirror
d-i base-installer/install-recommends      boolean true
d-i apt-setup/non-free                     boolean true
d-i apt-setup/contrib                      boolean true
d-i apt-setup/use_mirror                   boolean false
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
  cp /hd-media/preseed/nobeep.conf       /target/etc/modprobe.d/nobeep.conf; \
  cp /hd-media/preseed/bootstrap.service /target/etc/systemd/system/bootstrap.service; \
  in-target /bin/systemctl daemon-reload; \
  in-target /bin/systemctl enable bootstrap;
EOF

sync
umount /mnt/usb
