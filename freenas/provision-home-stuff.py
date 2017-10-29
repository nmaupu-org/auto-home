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

class FreenasApiCaller:
    def __init__(self, nas_addr, nas_login, nas_password):
        self.nas_addr = nas_addr
        self.nas_login = nas_login
        self.nas_password = nas_password

    def createNfsShareForKube(self, nfs_comment, nfs_path, nfs_ro=True, mapall_user="root", mapall_group="wheel"):
        return requests.post(
            "https://%s/api/v1.0/sharing/nfs/" % self.nas_addr,
            auth=(self.nas_login, self.nas_password),
            headers={"Content-Type": "application/json"},
            verify=False,
            data=json.dumps({
                "nfs_comment": nfs_comment,
                "nfs_paths": [nfs_path],
                "nfs_ro": nfs_ro,
                "nfs_alldirs": False,
                "nfs_hosts": "knode1 knode2 knode3",
                "nfs_mapall_user": mapall_user,
                "nfs_mapall_group": mapall_group,
            }),
        )

    def createDataset(self, name, comment):
        return requests.post(
            "https://%s/api/v1.0/storage/volume/tank/datasets/" % self.nas_addr,
            auth=(self.nas_login, self.nas_password),
            headers={"Content-Type": "application/json"},
            verify=False,
            data=json.dumps({
                "name": name,
                "comments": comment,
            }),
        )

    def createUser(self, name, uid, group_id):
        return requests.post(
            "https://%s/api/v1.0/account/users/" % self.nas_addr,
            auth=(self.nas_login, self.nas_password),
            headers={"Content-Type": "application/json"},
            verify=False,
            data=json.dumps({
                "bsdusr_username": name,
                "bsdusr_full_name": name,
                "bsdusr_group": group_id,
                "bsdusr_creategroup": False,
                "bsdusr_password_disabled": True,
                "bsdusr_uid": uid,
            }),
        )

    def createGroup(self, name, gid):
        return requests.post(
            "https://%s/api/v1.0/account/groups/" % self.nas_addr,
            auth=(self.nas_login, self.nas_password),
            headers={"Content-Type": "application/json"},
            verify=False,
            data=json.dumps({
                "bsdgrp_gid": gid,
                "bsdgrp_group": name,
            }),
        )

    def createJail(self, name, ip, mask):
        return requests.post(
            "https://%s/api/v1.0/jails/jails/" % self.nas_addr,
             auth=(self.nas_login, self.nas_password),
             headers={"Content-Type": "application/json"},
             verify=False,
             data=json.dumps({
                 "jail_host": name,
                 "jail_ipv4": ip,
                 "jail_ipv4_netmask": mask,
                 "jail_flags": "allow.raw_sockets=true",
                 "jail_autostart": True,
             }),
        )

    def associateDataset(self, jail_name, src, dst, readonly=True):
        return requests.post(
             "https://%s/api/v1.0/jails/mountpoints/" % self.nas_addr,
             auth=(self.nas_login, self.nas_password),
             headers={"Content-Type": "application/json"},
             verify=False,
             data=json.dumps({
                 "jail": jail_name,
                 "source": src,
                 "destination": dst,
                 "mounted": True,
                 "readonly": readonly,
             }),
        )


##
def main():
    fac = FreenasApiCaller(nas_addr, nas_login, nas_password)
    
    
    # Main kube NFS dataset
    r = fac.createDataset("kube-nfs", "Kube NFS dataset")
    print(r.status_code, r.text)

    # Photoweb
    r = fac.createDataset("kube-nfs/photoweb", "Photoweb")
    print(r.status_code, r.text)
    r = fac.createNfsShareForKube("Photoweb NFS share for kube", "/mnt/tank/kube-nfs/photoweb", True)
    print(r.status_code, r.text)

    # Minio
    r = fac.createDataset("kube-nfs/minio", "Minio")
    print(r.status_code, r.text)
    r = fac.createNfsShareForKube("Minio NFS share for kube", "/mnt/tank/kube-nfs/minio", False)
    print(r.status_code, r.text)

    # Vault
    # Creating group vault as in the vault container (gid = 100)
    vault_name = "vault"
    r = fac.createGroup(vault_name, 100)
    print(r.status_code, r.text)
    json_obj = r.json()
    try:
        group_id = json_obj[0]["id"]
    except:
        # Group already exists, getting its id
        r = requests.get(
            "https://%s/api/v1.0/account/groups" % nas_addr,
            auth=(nas_login, nas_password),
            headers={"Content-Type": "application/json"},
            verify=False,
        )
        jo_all = r.json()
        group_id = -1
        for val in jo_all:
            if val["bsdgrp_group"] == vault_name:
                group_id = val["id"]
                break

    # Creating user vault as in the vault container - note : might be ok with only the group
    r = fac.createUser(vault_name, 1000, group_id)
    print(r.status_code, r.text)
    r = fac.createDataset("kube-nfs/vault", "Vault")
    print(r.status_code, r.text)
    # Yes, creating a share with root:vault permission
    r = fac.createNfsShareForKube("Vault NFS share for kube", "/mnt/tank/kube-nfs/vault", False, "root", vault_name)
    print(r.status_code, r.text)

    # Influx DB
    r = fac.createDataset("kube-nfs/monitoring-influxdb", "InfluxDB Monitoring")
    print(r.status_code, r.text)
    r = fac.createNfsShareForKube("Monitoring InfluxDB storage for Kube", "/mnt/tank/kube-nfs/monitoring-influxdb", False)
    print(r.status_code, r.text)
    # Grafana
    r = fac.createDataset("kube-nfs/grafana", "Grafana dashboard")
    print(r.status_code, r.text)
    r = fac.createNfsShareForKube("Grafana for Kube", "/mnt/tank/kube-nfs/grafana", False)
    print(r.status_code, r.text)

    ###################################
    ## jails and associated datasets ##
    ###################################
    r = fac.createJail("kube-rproxy", "192.168.12.157", "24")
    print(r.status_code, r.text)

    r = fac.createDataset("dls", "Downloads and stuff")
    print(r.status_code, r.text)
    r = fac.createDataset("dls/seedbox", "Seedbox jail specific")
    print(r.status_code, r.text)

    r = fac.createJail("seedbox", "192.168.12.158", "24")
    print(r.status_code, r.text)
    r = fac.associateDataset("seedbox", "/mnt/tank/dls/seedbox", "/mnt", False)
    print(r.status_code, r.text)


if __name__ == "__main__":
    main()
