#!/bin/ash
# shellcheck shell=dash
# Author: nmaupu

usage() {
  cat << EOF
Usage: $0 <client-name>
EOF
}

[ $# -ne 1 ] && usage && exit 1

CLIENT_NAME="$1"

# Configuration parameters
OVPN_PKI="/etc/easy-rsa/pki"
OVPN_DIR=/etc/openvpn
export EASYRSA_PKI="${OVPN_PKI}"


easyrsa build-client-full "$CLIENT_NAME" nopass
openvpn --tls-crypt "${EASYRSA_PKI}/private/server.pem" \
  --genkey --secret "${EASYRSA_PKI}/private/${CLIENT_NAME}.pem"

OVPN_CA="$(openssl x509 -in ${OVPN_PKI}/ca.crt)"
OVPN_TA=$(cat "${OVPN_DIR}/ta.key")
OVPN_KEY=$(cat "${OVPN_PKI}/private/${CLIENT_NAME}.key")
OVPN_CERT=$(openssl x509 -in "${OVPN_PKI}/issued/${CLIENT_NAME}.crt")

# Fetch WAN IP address
# shellcheck source=/dev/null
. /lib/functions/network.sh
network_flush_cache
network_find_wan NET_IF
network_get_ipaddr NET_ADDR "${NET_IF}"
OVPN_SERV="${NET_ADDR}"
OVPN_PORT=$(grep port "${OVPN_DIR}/server.conf" | awk '{print $2}')
OVPN_PROTO=$(grep proto "${OVPN_DIR}/server.conf" | awk '{print $2}')


cat << EOF > "${OVPN_DIR}/${CLIENT_NAME}.ovpn"
user nobody
group nogroup
dev tun
nobind
client
remote ${OVPN_SERV} ${OVPN_PORT} ${OVPN_PROTO}
auth-nocache
remote-cert-tls server
key-direction 1
<tls-auth>
${OVPN_TA}
</tls-auth>
<key>
${OVPN_KEY}
</key>
<cert>
${OVPN_CERT}
</cert>
<ca>
${OVPN_CA}
</ca>
EOF
