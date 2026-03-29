# IoT Machine — Context for NixOS Migration

## Machine Overview

- **Hostname**: `iot`
- **Role**: IoT hub — Home Assistant, MQTT, Zigbee, automation
- **Current OS**: Talos Linux v1.8.3
- **IP**: `192.168.12.40/24` (DHCP with static lease on OpenWrt router, bound to MAC `68:1d:ef:33:f8:33`)
- **Network interface**: `enp1s0` (MAC: `68:1d:ef:33:f8:33`)
- **CPU**: Intel N100 (4 cores), 16 GB RAM
- **Disk**: Single SATA SSD `sda` — N900-512, 512 GB

### Disk Layout (current Talos partitions)
| Partition | Label     | FS       | Size    |
|-----------|-----------|----------|---------|
| sda1      | EFI       | vfat     | 105 MB  |
| sda2      | BIOS      | —        | 1 MB    |
| sda3      | BOOT      | xfs      | 982 MB  |
| sda4      | META      | talosmeta| 524 kB  |
| sda5      | STATE     | xfs      | 92 MB   |
| sda6      | EPHEMERAL | xfs      | 511 GB  |

All PVC data lives in sda6 (EPHEMERAL). **The entire disk will be wiped** for NixOS install.

---

## USB Zigbee Coordinators

Two USB serial adapters plugged in — critical to preserve udev symlinks on NixOS.

| Symlink                  | Driver    | Vendor:Product | Serial                             | Device           |
|--------------------------|-----------|----------------|------------------------------------|------------------|
| `/dev/sonoff_coord_xiaomi` | cp210x  | `10c4:ea60`    | `5c1d7030e96aef11aa58a4adc169b110` | Sonoff Zigbee 3.0 USB Dongle Plus |
| `/dev/zazah_coord_misc`    | ch341-uart| `1a86:7523`   | *(no serial — match by vid:pid only)* | CH341 USB Serial |

### NixOS udev rules (to put in `modules/iot/udev.nix`)
```nix
services.udev.extraRules = ''
  ACTION=="add", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", ATTRS{serial}=="5c1d7030e96aef11aa58a4adc169b110", SYMLINK+="sonoff_coord_xiaomi"
  ACTION=="add", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="zazah_coord_misc"
'';
```

> Note: The zazah device (ch341) has no unique serial — the match on vid:pid alone is acceptable since only one such device is plugged in. If a second ch341 device is ever added, revisit.

---

## Kubernetes State

- **k8s version**: v1.31.2
- **Container runtime**: containerd 2.0.0
- **CNI**: Flannel (VXLAN, VNI 1)
- **Pod CIDR**: `10.244.0.0/16`
- **Service CIDR**: `10.96.0.0/12`
- **Node taints**: none

---

## Storage

### StorageClass
- **`openebs-hostpath`** (default) — OpenEBS local provisioner, base path: `/var/openebs/local`
- `mayastor-etcd-localpv` / `mayastor-loki-localpv` — used only by openebs internal etcd/loki (non-critical, can be discarded)

### PVC → Host Path Mapping (all data to back up)

| Namespace    | PVC                              | Host Path                                                                          | Size   | Priority  |
|--------------|----------------------------------|------------------------------------------------------------------------------------|--------|-----------|
| hass         | home-assistant-cnpg-main-1       | `/var/openebs/local/pvc-648e6d1a-f951-4003-9a33-f2a0aad35e73`                     | 50Gi   | CRITICAL  |
| hass         | home-assistant-cnpg-main-1-wal   | `/var/openebs/local/pvc-41efafd3-a172-4011-b4fd-cae6afa341e4`                     | 50Gi   | CRITICAL  |
| hass         | home-assistant-config            | `/var/openebs/local/pvc-976c3ecb-e684-4833-8724-b76f585be789`                     | 200Mi  | HIGH      |
| hass         | home-assistant-conf-reloader     | `/var/openebs/local/pvc-5a85f915-5e55-4839-904e-36dc3b7e7b9a`                     | 200Mi  | LOW (git) |
| mosquitto    | mosquitto-data                   | `/var/openebs/local/pvc-b32c9089-b16c-427e-935b-7c59b442bae0`                     | 1Gi    | HIGH      |
| mosquitto    | mosquitto-configinc              | `/var/openebs/local/pvc-fc672405-d293-4be1-ba10-07749815eb60`                     | 10Mi   | LOW       |
| zigbee2mqtt  | data-volume-zigbee2mqtt-misc-0   | `/var/openebs/local/pvc-18d20531-b53e-405b-ae31-c2c3aee7a14f`                     | 1Gi    | HIGH      |
| zigbee2mqtt  | data-volume-zigbee2mqtt-xiaomi-0 | `/var/openebs/local/pvc-6b0ecc73-6caf-4825-9ee7-97fed6ecc609`                     | 1Gi    | HIGH      |
| gotomation   | gotomation-config                | `/var/openebs/local/pvc-4c0776c4-2add-4226-aa7a-4dc8601faf27`                     | 10Mi   | LOW (git) |
| tools        | iot-sshd-misc                    | `/var/openebs/local/pvc-800a27d6-d185-4ad0-b49b-ed5f31a03af7`                     | 1Gi    | LOW       |
| tools        | iot-sshd-server-keys             | `/var/openebs/local/pvc-081d0032-d3df-43da-8dcf-51bf296c2ecc`                     | 1Mi    | LOW       |

**Discard**: openebs-internal etcd (`/var/local/iot-openebs/...`) and loki PVCs — not application data.

### Backup Strategy
Backup destination: NAS via NFS (e.g., `/tank/backup-iot/openebs/`).
```bash
# On iot node (via talosctl shell or kubectl debug node)
rsync -aHAX /var/openebs/local/ /mnt/nas/iot-openebs-backup/
```
Restore: same path `/var/openebs/local/` on NixOS — openebs-hostpath will pick up existing directories if PV objects are recreated with matching names.

**PostgreSQL (CNPG)**: PostgreSQL 16.10, single instance, database `app`. Back up with pg_dump in addition to raw PVC:
```bash
kubectl exec -n hass home-assistant-cnpg-main-1 -- pg_dumpall -U postgres > hass-pg-backup.sql
```

---

## Applications

### Network
| Service     | IP               | Port  | Protocol |
|-------------|------------------|-------|----------|
| Traefik     | 192.168.100.1    | 80/443| TCP      |
| Traefik     | 192.168.100.10   | —     | (main svc)|
| Mosquitto   | 192.168.100.35   | 1883  | TCP      |
| SSHD        | 192.168.100.22   | 22    | TCP      |

MetalLB pool: `192.168.100.0/24`, BGP peer: `192.168.12.1` (home router, ASN 65000), cluster ASN 66001.

### Ingresses (TLS via cert-manager + Google Cloud DNS01)
| Host                          | Backend        |
|-------------------------------|----------------|
| hass.home.fossar.net          | Home Assistant |
| hass.iot.home.fossar.net      | Home Assistant |
| z2m-misc.iot.home.fossar.net  | Zigbee2MQTT misc |
| z2m-xiaomi.iot.home.fossar.net| Zigbee2MQTT xiaomi |

### App Summary
| App             | Namespace       | Chart / Version      | Notes                                        |
|-----------------|-----------------|----------------------|----------------------------------------------|
| Traefik         | ingress-controller | v30.4.1           | LB IPs 192.168.100.1 + 192.168.100.10        |
| MetalLB         | metallb         | v0.15.3              | BGP mode                                     |
| cert-manager    | cert-manager    | v6.2.3               | Google DNS01 issuer, prod + staging          |
| Sealed Secrets  | sealed-secrets  | v2.16.0              | Bitnami, iot has its own controller          |
| OpenEBS         | openebs         | v4.1.1               | localpv only (lvm/zfs/mayastor disabled)     |
| CloudNative PG  | cnpg            | v8.2.0               | PostgreSQL 16.10 operator                    |
| Home Assistant  | hass            | v28.15.2             | hostNetwork:true, CNPG DB, git config reload |
| Mosquitto       | mosquitto       | v17.11.4             | MQTT broker, auth via passwordfile secret    |
| Zigbee2MQTT misc| zigbee2mqtt     | v2.6.3               | /dev/zazah_coord_misc, PAN 6755, ch 11       |
| Zigbee2MQTT xiaomi| zigbee2mqtt   | v2.7.1               | /dev/sonoff_coord_xiaomi, PAN 6756, ch 15    |
| Gotomation      | gotomation      | v1.1.16              | custom-jsonnet plugin, git config            |
| SSHD            | tools           | v0.0.4               | LB 192.168.100.22:22                         |
| kube-prometheus-stack | monitoring | v61.2.0            | CRDs only, no alertmanager/prometheus/grafana|

### Home Assistant specifics
- Config pulled from https://github.com/nmaupu/hass-config.git via init container + cron job (every minute)
- Uses `hostNetwork: true` for UDP multicast (emulated_roku, emulated_hue)
- CNPG database: `home-assistant-cnpg-main`, PostgreSQL 16.10, 1 instance, 50Gi+50Gi WAL
- Secrets: `hass-secrets` (secret.yaml), `hass-passwords` (hass-passwords.json)

### Gotomation specifics
- Source: https://github.com/nmaupu/gotomation.git
- Config: https://github.com/nmaupu/gotomation-config.git
- Uses k8s-libsonnet/1.32 (not 1.30)
- Secrets: HASS_TOKEN, OMG_MQTT credentials, SENDER_CONFIGS

---

## Sealed Secrets

IoT cluster has its **own sealed-secrets controller** (namespace `sealed-secrets`).
Sealing cert location: `k8s/argocd/iot/statics/certs/` (check this path — or retrieve with `kubeseal --fetch-cert`).

To re-seal for iot cluster:
```bash
kubeseal --context admin@iot --fetch-cert > k8s/argocd/iot/iot-sealed-secrets.crt
kubeseal --cert k8s/argocd/iot/iot-sealed-secrets.crt --format yaml < secret.yaml > sealed.yaml
```

Existing sealed secrets:
- `iot-cluster` (argocd ns on NAS) — ArgoCD cluster registration, sealed with NAS cert
- `hass-secrets`, `hass-passwords` (hass ns)
- `mosquitto-passwordfile` (mosquitto ns)
- `zigbee2mqtt` (zigbee2mqtt ns)
- `gotomation-extra-flags` (gotomation ns)
- `google-dns-issuer-prod`, `google-dns-issuer-staging`, `google-dns01-solver` (cert-manager ns)

---

## ArgoCD Integration

ArgoCD runs on NAS machine (not on iot). The iot cluster is registered as destination `iot`.
- Cluster secret: `k8s/argocd/iot/deploy/cluster/iot-sealed.yaml` (sealed with NAS cert)
- After NixOS install: if iot API endpoint/certs change, re-generate kubeconfig, update the cluster secret, and re-seal.
- ArgoCD kubeconfig for iot stored in argocd namespace on NAS as secret `iot-cluster`.

---

## NixOS Migration — Target Config

### Repository layout (to create)
```
nix/
  hosts/
    iot/
      configuration.nix
      hardware-configuration.nix   # generated by nixos-generate-config on install
  modules/
    iot/
      udev.nix       # USB zigbee device symlinks
      monitoring.nix # Netdata only (no Scrutiny/ZFS)
      telegram-bot.nix # adapted from nas version (k8s commands, no ZFS/SMB)
  secrets/
    iot.yaml         # sops-encrypted: telegram_token, telegram_chat_id, nmaupu_user_password
```

### Shared modules to reuse (no changes needed)
- `modules/shared/k3s.nix` — same k3s setup, same disabled components (traefik, servicelb, local-storage)
- `modules/shared/telegram.nix` — same telegram-alert script
- `modules/shared/zsh.nix` — same shell setup

### Key NixOS config points for iot
- **No ZFS** — no zfs modules, no pool import
- **No SMB/NFS/FTP** — iot is not a fileserver
- **k3s**: single-node, disable traefik/servicelb/local-storage (same as NAS)
- **udev**: see USB zigbee rules above
- **hostId**: generate fresh 8-hex-char ID for NixOS (ZFS not used but hostId is harmless, actually not needed without ZFS)
- **sops-nix**: age key from iot SSH host key post-install
- **Telegram**: same shared module, new `secrets/iot.yaml`
- **Auto-update**: daily systemd service like NAS, target `#iot`
- **Users**: `nmaupu` only (uid 1001), same SSH key, NOPASSWD sudo
- **IP**: DHCP — OpenWrt router has a static lease for MAC `68:1d:ef:33:f8:33` → `192.168.12.40`. No static IP config needed in NixOS.
- **kernel modules**: `br_netfilter`, `overlay` (for k3s — already in shared k3s.nix)
- **i915 / Intel GPU**: N100 has Intel GPU, may need `boot.initrd.kernelModules = ["i915"]` for early KMS (optional)

### sops secrets needed (`secrets/iot.yaml`)
```
telegram_token
telegram_chat_id
nmaupu_user_password
```

---

## Migration Checklist Summary

### Phase 0 — Pre-migration (Talos running)
- [ ] Confirm OpenWrt static lease still active for MAC `68:1d:ef:33:f8:33` → `192.168.12.40`
- [ ] Backup `/var/openebs/local/` to NAS (all PVCs, especially CNPG 100Gi)
- [ ] pg_dump from CNPG pod as extra safety
- [ ] Scale down all stateful workloads before backup

### Phase 1 — NixOS install
- [ ] Boot NixOS ISO on iot
- [ ] Partition sda (single root, EFI)
- [ ] `nixos-generate-config` → copy hardware-configuration.nix to repo
- [ ] `nixos-install --flake .#iot`
- [ ] Reboot

### Phase 2 — Post-boot config
- [ ] Get age pubkey: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`
- [ ] Add to `.sops.yaml`, create `secrets/iot.yaml`, `sops updatekeys`
- [ ] `nixos-rebuild switch --flake .#iot`
- [ ] Verify k3s running, udev symlinks present

### Phase 3 — Restore data + redeploy
- [ ] Restore `/var/openebs/local/` from backup (preserve directory names/UIDs)
- [ ] Verify ArgoCD iot cluster secret still valid (certs may change → re-seal if needed)
- [ ] Push → ArgoCD syncs: openebs → sealed-secrets → cert-manager → metallb → traefik → apps
- [ ] Validate all apps healthy

### Phase 4 — Validation
- [ ] `ls -la /dev/zazah_coord_misc /dev/sonoff_coord_xiaomi` on iot node
- [ ] MetalLB IPs up: 100.1, 100.10, 100.22, 100.35
- [ ] MQTT: `mosquitto_sub -h 192.168.100.35 -t '#'`
- [ ] Zigbee2MQTT both instances connected
- [ ] Home Assistant up at https://hass.home.fossar.net
- [ ] Gotomation processing automations
- [ ] Telegram alerting from iot

---

## Talos Config Reference (for migration context only)

Talos schematic ID: `e4cbca0436815af5149e0cb1e60807981c87241f85e3c5618c23ebc1d2aec339`
(includes i915-ucode, mei, util-linux-tools extensions — needed for N100)

Talos config files: `/home/nmaupu/work/tmp/talos/` (local machine)
- `talosconfig` — client config
- `controlplane.yaml` — machine config

These are only useful for reference/rollback. They become irrelevant after NixOS migration.
