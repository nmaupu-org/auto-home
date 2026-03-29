# NixOS NAS Migration — Claude Context

## Repository Layout

This NixOS config lives in the `nix/` subdirectory of the `auto-home` monorepo.
All paths in this document are relative to `nix/`.
Ignore everything outside `nix/`: `ansible/`, `argocd/`, `scripts/`, etc.

## Other Machines

- **iot** — N100 machine running Talos Linux. ArgoCD configs in `argocd/iot/`. Not on NixOS yet, possible future migration to `nix/iot/`.

## Background

Migrated from TrueNAS SCALE (was stuck on k8s 1.26) to NixOS.
The machine runs a ZFS NAS + Kubernetes workloads via k3s + ArgoCD.

The boot disk (dedicated SSD) was wiped and replaced with NixOS.
Data drives (ZFS pool) were untouched — imported with `zpool import -f <poolname>` after install.

## Hardware

- Dedicated boot SSD (to be wiped)
- Separate data drives running a ZFS pool (untouched during migration)
- x86_64 machine

## Stack Decisions

| Concern | Choice | Notes |
|---|---|---|
| OS | NixOS 25.11 | Flakes from day one |
| Kubernetes | k3s | Via `services.k3s` |
| GitOps | ArgoCD | Redeployed via TrueCharts Helm repo |
| Storage (k8s) | openEBS ZFS + hostPath | Node-local, no CSI dependency on NAS |
| Secrets | sops-nix | Age key derived from SSH host key |
| Snapshots | sanoid | Declarative dataset policies |
| Alerting | Telegram bot | Direct webhook, no mail server |
| SMB | Samba + fruit VFS | macOS compatibility (replaces AFP) |
| ZFS events | zed | Hooked into Telegram alert script |

## Repository Structure

All paths below are relative to `nix/` in the monorepo.

```
flake.nix
hosts/
  nas/
    configuration.nix
    hardware-configuration.nix
modules/
  shared/
    zsh.nix          # zsh + starship + fzf + neovim (reusable across machines)
    telegram.nix     # telegram-alert script; host must set services.telegram-alert.sopsFile
    k3s.nix          # single-node k3s; host must set services.k3s-node.disabledComponents
  nas/
    zfs.nix          # pool import, scrub, sanoid snapshots
    nfs.nix          # NFS exports
    smb.nix          # Samba with macOS fruit module
    ftp.nix          # FTP service
    k3s.nix          # k3s single-node
    telegram-bot.nix # Telegram bot systemd service
    telegram-bot.py  # Telegram bot Python script
    smart.nix        # smartd + telegram alerting
    monitoring.nix   # Netdata (port 19999) + Scrutiny (port 8080) + Homepage (port 3000)
secrets/
  nas.yaml           # sops-encrypted NAS secrets
.sops.yaml           # age key config
CLAUDE.md            # this file
CLAUDE-PHASE0.md     # concrete values from TrueNAS (pool names, disk IDs, exports...)
```

## Flake Inputs

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  sops-nix = {
    url = "github:mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

## Key NixOS Configuration Patterns

### ZFS
```nix
networking.hostId = "<8 hex chars>";  # required by ZFS, generate once and hardcode
boot.supportedFilesystems = [ "zfs" ];
boot.zfs.forceImportRoot = false;
boot.zfs.extraPools = [ "<data-pool-name>" ];
services.zfs.autoScrub.enable = true;
services.zfs.trim.enable = true;
```

### Sanoid snapshots
```nix
services.sanoid = {
  enable = true;
  datasets."tank/data" = {
    hourly = 24; daily = 30; weekly = 8; monthly = 6;
    autosnap = true; autoprune = true;
  };
};
```

### Samba (macOS)
Critical: `fruit` VFS module must be enabled for macOS compatibility.
```nix
services.samba.settings.global = {
  "vfs objects" = "catia fruit streams_xattr";
  "fruit:metadata" = "stream";
};
services.samba-wsdd.enable = true;  # network discovery
```

### Telegram alerting
Shared script at `/run/telegram-alert`, consumed by smartd, zed, and systemd units.
Token + chat_id injected via sops-nix secrets as EnvironmentFile.

### sops-nix
Age key derived from SSH host key (machine can decrypt on boot without intervention):
```bash
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

Secrets in use (all in `secrets/nas.yaml`):
- `telegram_token`
- `telegram_chat_id`
- `smb_nmaupu_password`
- `smb_bicou_password`
- `printer_user_password`
- `nmaupu_user_password`
- `bicou_user_password`

## Services Summary

- **NFS** — file shares + backup targets
- **FTP** — legacy access
- **SMB** — macOS file sharing (Samba + fruit)
- **k3s** — single-node Kubernetes
- **ArgoCD** — deployed via k3s, pulls from TrueCharts Helm repo
- **openEBS** — ZFS + hostPath storage for k8s workloads
- **sanoid** — ZFS snapshots
- **smartd** — disk health monitoring → Telegram
- **zed** — ZFS event daemon → Telegram
- **sops-nix** — secrets management

## Migration Phases

- [x] Phase 0 — Document current state, snapshot ZFS, note disk IDs
- [x] Phase 1 — Install NixOS on boot SSD (data drives untouched)
- [x] Phase 2 — Write flake + modules, `nixos-install`
- [x] Phase 3 — First boot, `zpool import -f <poolname>`, validate datasets
- [x] Phase 4 — Restore NFS, FTP, SMB
- [x] Phase 5 — k3s up, deploy openEBS, deploy ArgoCD, redeploy apps

## Phase 0 Data

See `CLAUDE-PHASE0.md` for all concrete values collected from the current TrueNAS system:
- ZFS pool name(s) and vdev layout
- Dataset tree and mountpoints (`zfs list -r`)
- Pool properties (`zpool get all <poolname>`)
- Disk IDs (`/dev/disk/by-id/`)
- NFS exports (paths, subnets, options)
- FTP configuration
- SMB share names and dataset paths
- ArgoCD apps (chart names, Helm values summary)
- Network interface and IP

When writing any module, pull exact values from `CLAUDE-PHASE0.md` — no placeholders.

## Important Notes

- Do NOT use the OpenZFS NixOS root-on-ZFS guide — it's abandoned
- Use NixOS default LTS kernel (ZFS may not support latest)
- hostPath PV paths must match dataset mountpoints exactly before redeploying k8s apps
- openEBS ZFS driver needs `boot.supportedFilesystems = [ "zfs" ]` — handled by zfs.nix
- Never hardcode secrets in nix store (world-readable)
- ZFS `hostId` must be set before pool import

## Post-Migration Notes

### ZFS Pool Mountpoints
- `tank` — mounts at `/tank` (no altroot on NixOS, was `/mnt` on TrueNAS)
- `dls-tmp` — mounts at `/dls-tmp` (was `/mnt/dls-tmp` on TrueNAS)
- All k8s hostPath values must use the NixOS mountpoints (no `/mnt` prefix)

### ArgoCD
- Deployed via Makefile: `k8s/argocd/nas/Makefile`
- IOT cluster registered as `iot` destination — secret managed via SealedSecret in `k8s/argocd/iot/deploy/cluster/iot-sealed.yaml`
- ArgoCD runs in insecure mode (`server.insecure: true`) — Traefik handles TLS termination
- CMP jsonnet plugin: retry loop on `jb update` to handle race condition
- Gotomation uses `k8s-libsonnet/1.32` (not 1.30)

### Vault
- Using HashiCorp chart `0.32.0` (not Bitnami)
- Data restored from `tank/vault-nas` dataset (TrueNAS jail data directory)
- Auto-unseal via `vault-autounseal` app, service URL: `http://vault.vault.svc.cluster.local:8200`
- Label selector: `component=server`

### Sealed Secrets
- NAS cert stored at `k8s/argocd/nas/sealed-secrets.crt`
- IOT cluster has its own sealed-secrets controller in `sealed-secrets` namespace
- Re-seal with: `kubeseal --cert k8s/argocd/nas/sealed-secrets.crt --format yaml`

### Helm Charts Migrated from TrueCharts
- cert-manager → jetstack (`https://charts.jetstack.io`)
- traefik → official (`https://traefik.github.io/charts`) v39.0.6
- vault → HashiCorp (`https://helm.releases.hashicorp.com`) v0.32.0
- openebs → 4.4.0 (loki and minio disabled explicitly)

### Completed
- Timesheet data restored from old TrueNAS openEBS dataset
- SMB validated from macOS
- Time Machine subdirectories for `backup-pro-bicou` configured
