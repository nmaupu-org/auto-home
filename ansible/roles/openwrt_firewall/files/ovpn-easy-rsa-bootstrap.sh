#!/bin/ash
# shellcheck shell=dash

set -x

# Install packages
# Done with ansible as preliminary task
#opkg update
#opkg install openvpn-openssl openvpn-easy-rsa

# Configuration parameters  # OVPN_POOL config any network are OK except your local network
OVPN_DIR="/etc/openvpn"
OVPN_PKI="/etc/easy-rsa/pki"
OVPN_PORT="1194"
OVPN_PROTO="udp"
OVPN_POOL="192.168.8.0 255.255.255.0"
OVPN_DNS="${OVPN_POOL%.* *}.1"
OVPN_DOMAIN="$(uci get dhcp.@dnsmasq[0].domain)"

# Fetch WAN IP address
# shellcheck source=/dev/null
. /lib/functions/network.sh
network_flush_cache
network_find_wan NET_IF
network_get_ipaddr NET_ADDR "${NET_IF}"
OVPN_SERV="${NET_ADDR}"

# Configuration parameters
export EASYRSA_PKI="${OVPN_PKI}"
export EASYRSA_REQ_CN="ovpnca"
export EASYRSA_BATCH="1"
export EASYRSA_CERT_EXPIRE="3650" # Increases the client cert expiry from the default of 825 days to match the CA expiry

# Remove and re-initialize PKI directory
easyrsa init-pki

# Generate DH parameters
easyrsa gen-dh

# Create a new CA
easyrsa build-ca nopass

# Generate server keys and certificate
easyrsa build-server-full server nopass
#openvpn --genkey tls-crypt-v2-server "${EASYRSA_PKI}/private/server.pem"
openvpn --genkey --secret "${EASYRSA_PKI}/private/server.pem"

# Generate client keys and certificate
easyrsa build-client-full client nopass
#openvpn --tls-crypt-v2 "${EASYRSA_PKI}/private/server.pem" \
#  --genkey tls-crypt-v2-client "${EASYRSA_PKI}/private/client.pem"
openvpn --tls-crypt "${EASYRSA_PKI}/private/server.pem" \
  --genkey --secret "${EASYRSA_PKI}/private/client.pem"

openvpn --genkey --secret ${OVPN_DIR}/ta.key


# Configure firewall
uci rename firewall.@zone[0]="lan"
uci rename firewall.@zone[1]="wan"
uci del_list firewall.lan.device="tun+"
uci add_list firewall.lan.device="tun+"
uci -q delete firewall.ovpn
uci set firewall.ovpn="rule"
uci set firewall.ovpn.name="Allow-OpenVPN"
uci set firewall.ovpn.src="wan"
uci set firewall.ovpn.dest_port="${OVPN_PORT}"
uci set firewall.ovpn.proto="${OVPN_PROTO}"
uci set firewall.ovpn.target="ACCEPT"
uci commit firewall
/etc/init.d/firewall restart

# Configure VPN service and generate client profiles
umask go=
OVPN_CA="$(openssl x509 -in ${OVPN_PKI}/ca.crt)"
# shellcheck disable=SC2012
ls ${OVPN_PKI}/issued \
| sed -e "s/\.\w*$//" \
| while read -r OVPN_ID
do
  OVPN_TA=$(cat "${OVPN_DIR}/ta.key")
  OVPN_KEY=$(cat "${OVPN_PKI}/private/${OVPN_ID}.key")
  OVPN_CERT=$(openssl x509 -in "${OVPN_PKI}/issued/${OVPN_ID}.crt")
  OVPN_EKU=$(echo "${OVPN_CERT}" | openssl x509 -noout -purpose)
  case ${OVPN_EKU} in
    (*"SSL server : Yes"*)
    OVPN_CONF="${OVPN_DIR}/${OVPN_ID}.conf"
    cat << EOF > "${OVPN_CONF}" ;;
user nobody
group nogroup
dev tun
port ${OVPN_PORT}
proto ${OVPN_PROTO}
server ${OVPN_POOL}
topology subnet
client-to-client
keepalive 10 60
ca       ${OVPN_PKI}/ca.crt
cert     ${OVPN_PKI}/issued/server.crt
key      ${OVPN_PKI}/private/server.key
dh       ${OVPN_PKI}/dh.pem
tls-auth ${OVPN_DIR}/ta.key 0
persist-tun
persist-key
push "dhcp-option DNS ${OVPN_DNS}"
push "dhcp-option DOMAIN ${OVPN_DOMAIN}"
push "redirect-gateway def1"
push "persist-tun"
push "persist-key"
cipher AES-256-CBC
verb 3
mute 20
explicit-exit-notify 1
EOF
    (*"SSL client : Yes"*)
    OVPN_CONF="${OVPN_DIR}/${OVPN_ID}.ovpn"
    cat << EOF > "${OVPN_CONF}" ;;
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
  esac
done
/etc/init.d/openvpn restart
ls ${OVPN_DIR}/*.ovpn
touch ${OVPN_DIR}/ovpn_bootstrapped
