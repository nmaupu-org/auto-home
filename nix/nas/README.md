# NAS — NixOS Installation Guide

Full reinstallation procedure, from bare metal to a running system.

---

## Hardware

- **Boot disks**: 2× Verbatim Vi550 S3 119GiB SSDs — mirrored via mdadm RAID1 (root) + GRUB mirroredBoots (EFI)
  - `ata-Verbatim_Vi550_S3_493504108891827` → primary (`/boot`)
  - `ata-Verbatim_Vi550_S3_493504108891828` → fallback (`/boot-fallback`)
- **Data disks**: ZFS pools `tank` (raidz2, 4×8TB) and `dls-tmp` (mirror, 2×2TB) — **never touch these**
- **Architecture**: x86_64, UEFI

---

## Phase 1 — Boot the NixOS installer

1. Download the NixOS minimal ISO (25.05 or later):
   https://nixos.org/download

2. Write it to a USB drive:
   ```bash
   dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress
   ```

3. Boot the NAS from the USB drive (select UEFI boot in the BIOS boot menu).

4. Once booted, set a root password or add your SSH key so you can work remotely:
   ```bash
   passwd root
   # or
   mkdir -p ~/.ssh && echo "ssh-ed25519 AAAA..." > ~/.ssh/authorized_keys
   ```

---

## Phase 2 — Partition and format the boot SSDs

### Identify the disks

Run:
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
ls /dev/disk/by-id/
```

Expected output (disk letters may vary across reboots — always use by-id):

| by-id | Model | Size | Role |
|---|---|---|---|
| `ata-Verbatim_Vi550_S3_493504108891827` | Verbatim Vi550 S3 | 119GiB | **NixOS boot SSD #1** |
| `ata-Verbatim_Vi550_S3_493504108891828` | Verbatim Vi550 S3 | 119GiB | **NixOS boot SSD #2** |
| `ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2585040` | WD Red 2TB | 1.8TiB | dls-tmp pool |
| `ata-WDC_WD20EFRX-68EUZN0_WD-WCC4M2658965` | WD Red 2TB | 1.8TiB | dls-tmp pool |
| `ata-ST8000VN004-3CP101_WRQ2HCAN` | Seagate 8TB | 7.3TiB | tank pool |
| `ata-ST8000VN004-3CP101_WWZ5711R` | Seagate 8TB | 7.3TiB | tank pool |
| `ata-ST8000VN004-3CP101_WWZ5QLQ6` | Seagate 8TB | 7.3TiB | tank pool |
| `ata-ST8000VN004-3CP101_WWZ5VT0V` | Seagate 8TB | 7.3TiB | tank pool |

Resolve by-id to current device letters:
```bash
ls -la /dev/disk/by-id/ata-Verbatim_Vi550_S3_4935041088918{27,28}
```

Example output:
```
ata-Verbatim_Vi550_S3_493504108891827 -> ../../sdb
ata-Verbatim_Vi550_S3_493504108891828 -> ../../sdc
```

> **Warning**: disk letters (sdb, sdc…) are assigned by the kernel at boot and can
> change. Always reference disks by their by-id path for anything permanent.

### Partition both SSDs

The root filesystem is mirrored via mdadm RAID1. Each SSD gets identical partitioning:
- **Part 1** (512MiB): EFI system partition — GRUB installs on both, kept in sync automatically
- **Part 2** (rest): mdadm RAID1 member — ext4 root on top

```bash
for dev in \
  /dev/disk/by-id/ata-Verbatim_Vi550_S3_493504108891827 \
  /dev/disk/by-id/ata-Verbatim_Vi550_S3_493504108891828; do
  parted $dev -- mklabel gpt
  parted $dev -- mkpart ESP fat32 1MiB 512MiB
  parted $dev -- mkpart primary ext4 512MiB 100%
  parted $dev -- set 1 esp on
done
```

### Create the mdadm RAID1 array

`--bitmap=internal` enables write-intent bitmap: after an unclean shutdown only
dirty blocks are resynced instead of the full disk.

`--metadata=1.0` stores metadata at the end of the partition so the EFI firmware
can still read the partition as a plain disk if needed.

```bash
mdadm --create /dev/md0 \
  --level=1 \
  --raid-devices=2 \
  --metadata=1.0 \
  --bitmap=internal \
  /dev/disk/by-id/ata-Verbatim_Vi550_S3_493504108891827-part2 \
  /dev/disk/by-id/ata-Verbatim_Vi550_S3_493504108891828-part2
```

Monitor initial sync (optional, install can proceed in parallel):
```bash
watch cat /proc/mdstat
```

### Format

```bash
# EFI on both SSDs (GRUB will keep them in sync after install)
mkfs.fat -F32 -n BOOT     /dev/disk/by-id/ata-Verbatim_Vi550_S3_493504108891827-part1
mkfs.fat -F32 -n BOOTFALL /dev/disk/by-id/ata-Verbatim_Vi550_S3_493504108891828-part1

# Root on the RAID array
mkfs.ext4 -L nixos /dev/md0
```

### Mount

```bash
mount /dev/md0 /mnt
mkdir -p /mnt/boot /mnt/boot-fallback
mount /dev/disk/by-id/ata-Verbatim_Vi550_S3_493504108891827-part1 /mnt/boot
mount /dev/disk/by-id/ata-Verbatim_Vi550_S3_493504108891828-part1 /mnt/boot-fallback
```

---

## Phase 3 — Install NixOS

### Get the config

```bash
cd /tmp
git clone <repo-url>
cd auto-home/nix/nas
```

### Install

```bash
nixos-install --flake .#nas
```

Set a root password when prompted at the end.

### Reboot

```bash
reboot
```

Remove the USB drive. The system should boot from the SSD into NixOS.

---

## Phase 4 — First boot

SSH in:
```bash
ssh nmaupu@<nas-ip>
```

### Import the ZFS pools

```bash
sudo zpool import -f tank
sudo zpool import -f dls-tmp
```

Verify:
```bash
zpool status
zfs list
```

Check that mountpoints are correct (`/tank/...`). If datasets mounted under a different prefix, adjust paths in `modules/smb.nix`, `modules/nfs.nix`, and `modules/ftp.nix`, then rebuild.

---

## Phase 5 — sops secrets

### Get the age public key from the SSH host key

```bash
nix-shell -p ssh-to-age --run 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
```

### Update `.sops.yaml`

On your dev machine, replace the `age1xxx...` placeholder in `.sops.yaml` with the output above.

### Create and encrypt the secrets file

```bash
cd nix/nas
sops secrets/secrets.yaml
```

Add the following keys:
```yaml
telegram_token: "bot<your-token>"
telegram_chat_id: "<your-chat-id>"
smb_user_password: "<password>"
ftp_user_password: "<password>"
```

Save and exit. The file is now encrypted on disk.

### Rebuild to activate secrets

Commit `.sops.yaml` and `secrets/secrets.yaml`, push, then on the NAS:
```bash
cd /tmp/auto-home
git pull
sudo nixos-rebuild switch --flake nix/nas#nas
```

---

## Phase 6 — Service passwords

### Samba (nmaupu and bicou)

```bash
sudo smbpasswd -a nmaupu
sudo smbpasswd -a bicou
```

### FTP (ftpuser — used by the printer)

```bash
sudo passwd ftpuser
```

Configure the printer's FTP target:
- **Host**: `<nas-ip>`
- **Port**: 21
- **User**: `ftpuser`
- **Remote path**: `/printer` (chrooted to `/tank/ftp_home`)

---

## Phase 7 — k3s and ArgoCD

### Verify k3s is running

```bash
sudo systemctl status k3s
sudo k3s kubectl get nodes
```

### Create the openEBS ZFS dataset if missing

```bash
sudo zfs create -o mountpoint=none tank/openebs-zfs
```

### Bootstrap ArgoCD via Helm

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

helm repo add truecharts https://charts.truecharts.org
helm repo update

helm install argocd truecharts/argocd \
  --namespace argocd \
  --create-namespace
```

### Point ArgoCD at the GitOps repo

Once ArgoCD is up, add the repository and apply the app manifests from `argocd/iot/` (or equivalent NAS app definitions). ArgoCD will reconcile and redeploy all applications.

### Create per-user Time Machine subdirectories

```bash
sudo mkdir -p /tank/backup-mac-pro-bicou/nmaupu
sudo mkdir -p /tank/backup-mac-pro-bicou/bicou
sudo chown nmaupu /tank/backup-mac-pro-bicou/nmaupu
sudo chown bicou  /tank/backup-mac-pro-bicou/bicou
```

---

## Verification checklist

```bash
# ZFS
zpool status
zpool list

# Services
systemctl status samba smbd nmbd samba-wsdd
systemctl status nfs-server
systemctl status proftpd
systemctl status smartd
systemctl status k3s

# Samba shares visible from macOS Finder / Windows Explorer
# Time Machine targets reachable (backup-air, backup-pro-bicou)
# Printer FTP upload works
# NFS export mounted on 192.168.12.0/24 clients
# Telegram alert fires: echo "test" | sudo /etc/telegram-alert "test message"

# k3s
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A
```

---

## Testing the config in a QEMU VM (before touching real hardware)

```bash
# Create a disk image
mkdir -p ~/.virt/nixos-test
qemu-img create -f qcow2 ~/.virt/nixos-test/disk.qcow2 20G

# Boot the installer (legacy BIOS — use OVMF for UEFI, see below)
qemu-system-x86_64 -m 4096 -smp 2 -enable-kvm \
  -cdrom ~/Downloads/nixos-minimal-*.iso \
  -boot d \
  -drive file=~/.virt/nixos-test/disk.qcow2,format=qcow2,if=virtio \
  -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22

# After install, boot from disk with UEFI (required for systemd-boot)
qemu-system-x86_64 -m 4096 -smp 2 -enable-kvm \
  -bios /path/to/OVMF.fd \
  -drive file=~/.virt/nixos-test/disk.qcow2,format=qcow2,if=virtio \
  -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22

# SSH into VM
ssh -p 2222 nmaupu@localhost
```

On Guix, get OVMF with:
```bash
guix build ovmf-x86-64
# OVMF.fd is at: <store-path>/share/firmware/ovmf_x64.bin
```
