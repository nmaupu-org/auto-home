# NAS — NixOS Installation Guide

Full reinstallation procedure, from bare metal to a running system.

---

## Hardware

- **Boot disk**: dedicated SSD (wiped during install)
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

## Phase 2 — Partition and format the boot SSD

### Identify the boot SSD

List disks and cross-reference with known data disk IDs to find the boot SSD:
```bash
lsblk -o NAME,SIZE,MODEL,SERIAL
ls /dev/disk/by-id/
```

The data disks are:
- `ata-ST8000VN004-*` — tank (×4)
- `ata-WDC_WD20EFRX-*` — dls-tmp (×2)
- `ata-Verbatim_Vi550_S3_*` — **these are the boot SSDs** (mirror for TrueNAS boot-pool, but the boot SSD for NixOS is one dedicated disk — confirm before wiping)

### Partition the boot SSD

Replace `/dev/sdX` with the correct device.

```bash
parted /dev/sdX -- mklabel gpt
parted /dev/sdX -- mkpart ESP fat32 1MiB 512MiB
parted /dev/sdX -- mkpart primary ext4 512MiB 100%
parted /dev/sdX -- set 1 esp on
```

### Format

```bash
mkfs.fat -F32 -n BOOT /dev/sdX1
mkfs.ext4 -L nixos /dev/sdX2
```

### Mount

```bash
mount /dev/sdX2 /mnt
mkdir -p /mnt/boot
mount /dev/sdX1 /mnt/boot
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
