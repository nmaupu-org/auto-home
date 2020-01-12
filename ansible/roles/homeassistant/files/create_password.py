#!/usr/bin/env python3
# Based on https://github.com/home-assistant/home-assistant/blob/4c5ea54df94038e59332c82df92497c7573ef1b6/homeassistant/auth/providers/homeassistant.py#L144
import bcrypt
import base64
import sys

data=sys.stdin.readlines()
passwd = data[0].rstrip()
passwd_hashed: bytes = bcrypt.hashpw(passwd.encode(), bcrypt.gensalt(rounds=12))
print(base64.b64encode(passwd_hashed).decode())
