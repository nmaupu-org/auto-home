# Requirements

Install all dependencies using :
```
ansible-galaxy install -r requirements.yml
```

# Openwrt devices bootstrap

ssh to the device and do:
```
opkg update
opkg install python-light python-logging python-openssl python-codecs openssh-sftp-server
```

Otherwise, ansible will not be able to run.
