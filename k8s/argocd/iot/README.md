# IoT Cluster Bootstrap

Single-node k3s cluster running on NixOS (Intel N100).
Managed by ArgoCD running on the NAS cluster.

## Prerequisites

- NixOS installed on the iot machine (see `nix/hosts/iot/`)
- ArgoCD running on NAS (`k8s/argocd/nas/`)
- `kubectl` contexts `home-nas` and `home-iot` configured
- `sops` and age key available for secrets
- Vault accessible (`vault token lookup`)

## Step 1 — NixOS install

Follow `nix/hosts/iot/README.md` or the two-pass install process:

1. First pass without sops (use `initialPassword` temporarily)
2. Get the age pubkey from the SSH host key:
   ```bash
   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
   ```
3. Add the age key to `nix/.sops.yaml` under the `iot` key group
4. Create `nix/secrets/iot.yaml` with sops:
   ```bash
   sops nix/secrets/iot.yaml
   # Add: nmaupu_user_password, telegram_bot_token, telegram_chat_id
   ```
5. Second pass: `nixos-rebuild switch --flake ./nix#iot`

## Step 2 — Register iot cluster in ArgoCD

The iot cluster must be registered as destination `iot` in ArgoCD on NAS.
The registration secret lives at `statics/cluster/iot-sealed.yaml`.

If re-installing from scratch, the k3s TLS certs change. Re-seal the cluster secret:
```bash
# Get new k3s certs from iot
SERVER=$(kubectl --context home-iot config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl --context home-iot config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
CERT=$(kubectl --context home-iot config view --minify --raw -o jsonpath='{.users[0].user.client-certificate-data}')
KEY=$(kubectl --context home-iot config view --minify --raw -o jsonpath='{.users[0].user.client-key-data}')

# Re-seal with NAS sealed-secrets cert
kubectl create secret generic cluster-iot \
  --namespace argocd \
  --from-literal=name=iot \
  --from-literal=server="$SERVER" \
  --from-literal=config="{\"tlsClientConfig\":{\"caData\":\"$CA\",\"certData\":\"$CERT\",\"keyData\":\"$KEY\"}}" \
  --dry-run=client -o yaml | \
  kubeseal --cert k8s/argocd/nas/sealed-secrets.crt --format yaml \
  > k8s/argocd/iot/deploy/cluster/iot-sealed.yaml
```

## Step 3 — Sealed secrets

All app secrets are in `statics/`. They are sealed with the iot sealed-secrets
controller key (`sealed-secrets.crt`).

**If the iot sealed-secrets controller key is lost** (e.g. fresh install):
```bash
# Fetch new cert
kubeseal --context home-iot \
  --controller-name sealed-secrets \
  --controller-namespace sealed-secrets \
  --fetch-cert > sealed-secrets.crt

# Re-seal all secrets (see each section below for plaintext sources)
```

Secrets and their plaintext sources:

| Secret | Namespace | Keys | Source |
|--------|-----------|------|--------|
| `google-dns01-solver` | cert-manager | `google-key.json` | `k8s/argocd/nas/google-key.json` |
| `hass-passwords` | hass | `hass-passwords.json` | HA `.storage/auth_provider.homeassistant` (PVC backup) |
| `hass-secrets` | hass | `secret.yaml` | HA `secrets.yaml` (PVC backup) — lat/lon, mqtt creds |
| `mosquitto-passwordfile` | mosquitto | `passwordfile` | Generate with `mosquitto_passwd` |
| `zigbee2mqtt` | zigbee2mqtt | `secret.yaml` | MQTT server/user/password |
| `gotomation-extra-flags` | gotomation | `HASS_TOKEN`, `OMG_MQTT_*`, `SENDER_CONFIGS` | Vault + new HA token |

The ACME key secrets (`google-dns-issuer-{prod,staging}`) are **not** sealed —
cert-manager creates them automatically on first use.

## Step 4 — cert-manager ClusterIssuers

ClusterIssuers are not managed by ArgoCD statics (they contain non-public values).
Deploy them via the NAS Makefile after ArgoCD is running:

```bash
cd k8s/argocd/nas
make cert-manager-iot GOOGLE_PROJECT_ID=<project> EMAIL_ADDRESS=<email>
```

This applies an ArgoCD Application (`cert-manager-iot-application.yaml`) that
deploys the ClusterIssuers from the shared Helm chart at `k8s/charts/cert-manager-issuers/`.

## Step 5 — Restore PVC data

After ArgoCD deploys all apps and PVCs are created, restore data from NAS backup:

```bash
# On iot — find new PVC UUIDs
ls /var/openebs/local/

# Identify which UUID corresponds to which app (check pod volume mounts)
kubectl --context home-iot get pvc -A

# Stop the app, rsync old data into new PVC dir, restart
kubectl scale deploy <app> -n <ns> --replicas=0
sudo rsync -aHAX /path/to/old-pvc-uuid/ /var/openebs/local/new-pvc-uuid/
kubectl scale deploy <app> -n <ns> --replicas=1
```

Critical PVCs to restore:
- **zigbee2mqtt** — device pairing database (avoid re-pairing all devices)
- **home-assistant config** — `.storage/` directory (integrations state)

The Home Assistant PostgreSQL database (CNPG) requires a separate restore procedure
if history needs to be preserved.

## Step 6 — HC Ping UUID

The auto-update healthcheck UUID is set in `nix/hosts/iot/configuration.nix`.
If reinstalling from scratch, create a new check at healthchecks.io and update the UUID in the `update-system` service script.

```

ArgoCD will then detect the resource as present and proceed.

## ArgoCD sync order (sync waves)

| Wave | Apps |
|------|------|
| 0 | openebs, metallb, sealed-secrets |
| 1 | cert-manager, cloudnative-pg |
| 2 | traefik |
| 3 | cluster registration |
| 4 | mosquitto, sshd |
| 5 | home-assistant, zigbee2mqtt, gotomation, monitoring |
