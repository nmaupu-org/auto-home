#!/bin/sh

set -eu

: "${NAS:=192.168.12.8}"
: "${SHARE:=/tank/le-certs}"
: "${MOUNTPOINT:=/mnt/le-certs}"

mkdir -p /mnt/le-certs
/sbin/mount.nfs "$NAS:$SHARE" "$MOUNTPOINT" -o nolock,ro
/bin/cp "${MOUNTPOINT}/fw-cert.crt" /etc/luci-cert.crt
/bin/cp "${MOUNTPOINT}/fw-cert.key" /etc/luci-cert.key
/usr/bin/umount "$MOUNTPOINT"

/bin/chmod 644 /etc/luci-cert.crt
/bin/chmod 600 /etc/luci-cert.key

/sbin/uci delete uhttpd.defaults || true
/sbin/uci set uhttpd.main.cert='/etc/luci-cert.crt'
/sbin/uci set uhttpd.main.key='/etc/luci-cert.key'
/sbin/uci commit

/sbin/service uhttpd restart
