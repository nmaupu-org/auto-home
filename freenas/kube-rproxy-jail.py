#!/usr/bin/env python3

import json
import requests
import sys
import urllib3
urllib3.disable_warnings()

try:
  nas_addr = str(sys.argv[1])
  nas_login = str(sys.argv[2])
  nas_password = str(sys.argv[3])
except IndexError as e:
  print("Please provide all arguments")
  print("Usage: %s nas_addr login password" % sys.argv[0])
  sys.exit(1)

r = requests.post(
  "https://%s/api/v1.0/jails/jails/" % nas_addr,
  auth=(nas_login, nas_password),
  headers={"Content-Type": "application/json"},
  verify=False,
  data=json.dumps({
    "jail_host": "kube-rproxy",
    "jail_ipv4": "192.168.12.157",
    "jail_ipv4_netmask": "24",
    "jail_flags": "allow.raw_sockets=true",
  }),
)

print(r.text)
