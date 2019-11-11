# Requirements

Install all dependencies using :
```
ansible-galaxy install -r requirements.yml
```

# Openwrt devices bootstrap

** You need to use an ethernet cable for the bootstrap procedure ! **

First, plug and boot the device:
- wan cable to the box, bridge mode
- lan cables as needed
- USB key in USB port, formatted as `fat32` or `ext4`

Boot the device up and:
- connect to http://192.168.1.1
- set a root password via the ui
- set a ssh public key (needed for ansible later on)

SSH to the device and install the following (needed for ansible):
```
opkg update
opkg install python-light python-logging python-openssl python-codecs openssh-sftp-server uclient-fetch libustream-mbedtls ca-bundle ca-certificates
uci set network.lan.ipaddr=192.168.12.1
uci commit
/etc/init.d/network restart
```

** Device IP has now changed to 192.168.12.1, renew locale DHCP lease before proceeding further ! **

To install, simply use:
```
VAULT_ADDR=not-used ./scripts/apply-ansible.sh home.yml --limit openwrt --extra-vars "firewall_wireless_key='my secret wifi password'"
```

First run will timeout when running handlers. CTRL+C and renew dhcp lease, rerun with the new ip address
