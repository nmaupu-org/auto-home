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
  "https://%s/api/v1.0/sharing/nfs/" % nas_addr,
  auth=(nas_login, nas_password),
  headers={"Content-Type": "application/json"},
  verify=False,
  data=json.dumps({
    "nfs_comment": "photoweb NFS share",
    "nfs_paths": ["/mnt/tank/photos/web/photos-web"],
    "nfs_ro": True,
    "nfs_alldirs": False,
    "nfs_hosts": "knode1 knode2 knode3"
  }),
)

print(r.text)
