#!/bin/sh

set -euo pipefail

: "${NAS:=192.168.12.8}"
: "${SHARE:=/mnt/tank/le-certs}"
: "${MOUNTPOINT:=/mnt/le-certs}"

mkdir -p /mnt/le-certs
/sbin/mount.nfs "$NAS:$SHARE" "$MOUNTPOINT" -o nolock,ro
/bin/cp "${MOUNTPOINT}/fw-cert.crt" /etc/nginx/conf.d/_lan.crt
/bin/cp "${MOUNTPOINT}/fw-cert.key" /etc/nginx/conf.d/_lan.key
/usr/bin/umount "$MOUNTPOINT"

/sbin/uci delete nginx._lan.uci_manage_ssl 2>/dev/null || true
/sbin/uci commit

/bin/chmod 644 /etc/nginx/conf.d/_lan.crt
/bin/chmod 600 /etc/nginx/conf.d/_lan.key

/sbin/service nginx reload
