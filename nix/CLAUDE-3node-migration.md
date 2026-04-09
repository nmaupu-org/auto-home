# 3-Node k3s Cluster Migration

## Goal

Merge the two standalone k3s single-node clusters (NAS + IoT) and a new N100 machine
into a single 3-node k3s cluster. Workloads that require local disks or USB devices
stay pinned to their node via labels/taints; everything else floats freely.

---

## Cluster Topology

| Node       | Role            | IP             | MAC               | Taint                    | Label        |
|------------|-----------------|----------------|-------------------|--------------------------|--------------|
| nas        | server + worker | 192.168.12.8   | (existing)        | `role=nas:NoSchedule`    | `role=nas`   |
| iot        | agent           | 192.168.12.40  | 68:1d:ef:33:f8:33 | `role=iot:NoSchedule`    | `role=iot`   |
| worker1   | agent           | 192.168.12.41  | TBD               | *(none)*                 | `role=worker`|

- NAS is the k3s server (control plane + etcd). It also runs workloads — it is NOT tainted as control-plane-only.
- IoT becomes a k3s agent. Its local openebs data and USB devices stay on-node.
- worker1 is a plain floating worker. No taint → general workloads land here by default.

---

## MetalLB — Unified Single Instance

Both current clusters use BGP mode peering with the OpenWrt home router (ASN 65000).
In the unified cluster a single MetalLB instance manages both IP pools.

### BGP ASN

**Unified cluster ASN: 65001** (NAS's current ASN — no NAS-side BGP change needed).
IoT currently uses ASN 66001 → this disappears when IoT becomes an agent.
OpenWrt must accept BGP sessions from **3 peers** (nas, iot, worker1) all using ASN 65001.

### IP Address Pools

| Pool name   | Range              | Used by              |
|-------------|--------------------|----------------------|
| `nas-pool`  | 192.168.99.0/24    | NAS workloads (existing) |
| `iot-pool`  | 192.168.100.0/24   | IoT workloads (existing) |

Keep both pools — zero renumbering needed. Services keep their existing IPs.
Pool assignment is controlled via `metallb.universe.tf/address-pool` annotation on Services,
or via `IPAddressPool.spec.serviceAllocation.serviceSelectors`.

### Target BGP config (replaces current NAS metallb bgp-config/)

```yaml
# cr-bgppeer.yaml — one peer entry, applies to all nodes
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: home-router
  namespace: metallb
spec:
  myASN: 65001
  peerASN: 65000
  peerAddress: 192.168.12.1
  peerPort: 179

# cr-ipaddresspool.yaml — two pools
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: nas-pool
  namespace: metallb
spec:
  addresses:
  - 192.168.99.0/24
  autoAssign: true
  avoidBuggyIPs: true
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: iot-pool
  namespace: metallb
spec:
  addresses:
  - 192.168.100.0/24
  autoAssign: false   # only assign when explicitly requested
  avoidBuggyIPs: true

# cr-bgpadvertisement.yaml
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: bgpadv
  namespace: metallb
spec:
  aggregationLength: 32
  ipAddressPools:
  - nas-pool
  - iot-pool
  peers:
  - home-router
```

### OpenWrt BGP changes required
Add `worker1` (192.168.12.41) as a new BGP neighbor with ASN 65001.
The existing `iot` neighbor (192.168.12.40) ASN must change from 66001 → 65001.
NAS (192.168.12.8) neighbor stays unchanged.

---

## NixOS k3s Module Changes

`modules/shared/k3s.nix` currently hardcodes `role = "server"`.
It needs to be extended to support agent nodes.

### New options to add

```nix
services.k3s-node.role          # "server" (default) or "agent"
services.k3s-node.serverUrl     # for agents: "https://192.168.12.8:6443"
services.k3s-node.tokenFile     # path to sops-managed token file (required for agents, optional for server)
services.k3s-node.nodeLabels    # [ "role=nas" ]
services.k3s-node.nodeTaints    # [ "role=nas:NoSchedule" ]
```

### Token strategy

k3s uses a shared cluster token for agent join auth. Approach:
- Add `k3s_cluster_token` to each node's sops secrets file (same plaintext value, encrypted per-node).
- Server: `services.k3s.tokenFile` → pre-sets the token (beats the auto-generated one).
- Agents: same `tokenFile` option pointing to their local sops secret.

To generate the token initially:
```bash
head -c 32 /dev/urandom | base64 | tr -d '=+/' | head -c 32
```

Add to secrets with:
```bash
sops secrets/nas.yaml       # add k3s_cluster_token
sops secrets/iot.yaml       # add k3s_cluster_token (same value)
sops secrets/worker1.yaml  # add k3s_cluster_token (same value)
```

### Node labels and taints via k3s flags

Labels and taints are passed to k3s at startup via `--node-label` and `--node-taint`.
They are applied on each start, so they are declarative.

```nix
# nas/configuration.nix
services.k3s-node = {
  role       = "server";
  tokenFile  = config.sops.secrets.k3s_cluster_token.path;
  nodeLabels = [ "role=nas" ];
  nodeTaints = [ "role=nas:NoSchedule" ];
  disabledComponents = [ "traefik" "servicelb" "local-storage" ];
};

# iot/configuration.nix
services.k3s-node = {
  role      = "agent";
  serverUrl = "https://192.168.12.8:6443";
  tokenFile = config.sops.secrets.k3s_cluster_token.path;
  nodeLabels = [ "role=iot" ];
  nodeTaints = [ "role=iot:NoSchedule" ];
};

# worker1/configuration.nix
services.k3s-node = {
  role      = "agent";
  serverUrl = "https://192.168.12.8:6443";
  tokenFile = config.sops.secrets.k3s_cluster_token.path;
  nodeLabels = [ "role=worker" ];
  # no taint — floating worker
};
```

---

## Workload Pinning Guide

### Must stay on iot (USB + local openebs data)

All IoT workloads that use local openebs PVCs or USB devices need:
```yaml
nodeSelector:
  role: iot
tolerations:
- key: role
  operator: Equal
  value: iot
  effect: NoSchedule
```

| App              | Reason                                      |
|------------------|---------------------------------------------|
| zigbee2mqtt-misc | /dev/zazah_coord_misc USB                   |
| zigbee2mqtt-xiaomi | /dev/sonoff_coord_xiaomi USB              |
| home-assistant   | openebs local PVCs (CNPG 100Gi + config)    |
| CNPG cluster     | openebs local PVCs (same node as HA)        |
| mosquitto        | openebs local PVC (mosquitto-data)          |

### Must stay on nas (ZFS datasets / openebs)

NAS workloads already have hostPath PVs pointing to ZFS mountpoints under `/tank`.
They need:
```yaml
nodeSelector:
  role: nas
tolerations:
- key: role
  operator: Equal
  value: nas
  effect: NoSchedule
```

### Can float freely (worker1 preferred)

No node selector needed. Will land on worker1 by default (only untainted node).
- cert-manager
- sealed-secrets (single controller — NAS cert)
- traefik
- metallb
- headlamp
- gotomation (git-backed config, no local data)
- monitoring (kube-prometheus-stack CRDs)
- ArgoCD itself (prefer worker1, but NAS is the bootstrap machine)

---

## ArgoCD Consolidation

Currently ArgoCD on NAS manages:
- NAS apps (destination: `in-cluster`)
- IoT apps (destination: `iot` — the `iot-cluster` sealed secret)

After migration: **single cluster, single ArgoCD**. All apps target `in-cluster` (or `https://kubernetes.default.svc`).

### Steps
1. Add `nodeSelector`/`tolerations` to all IoT ArgoCD app Helm values (see pinning table above).
2. Update IoT app `Application` CRs: change `spec.destination.name: iot` → `spec.destination.server: https://kubernetes.default.svc`.
3. Delete the `iot-cluster` sealed secret from argocd namespace on NAS.
4. Delete IoT's `iot-application-statics.yaml` AppProject/ApplicationSet (or repurpose it).
5. Migrate IoT app YAMLs from `k8s/argocd/iot/` into `k8s/argocd/nas/` (or a shared `k8s/argocd/cluster/` directory).

### IoT ArgoCD apps to migrate

- cert-manager (iot) → can merge with NAS cert-manager or keep separate namespace
- cloudnative-pg (iot)
- gotomation
- headlamp
- home-assistant + values.yaml
- matterbridge
- metallb (IoT pool merged into NAS metallb — this app disappears)
- mosquitto
- openebs (iot) — DaemonSet, already cluster-scoped on NAS
- sealed-secrets (iot controller) → decommission, single controller on NAS
- sshd
- monitoring/kube-prometheus-stack (iot)
- zigbee2mqtt (both instances)

---

## Sealed Secrets Consolidation

IoT currently has its own sealed-secrets controller (namespace `sealed-secrets` on iot cluster).
In the unified cluster: **single controller**, managed by the NAS ArgoCD, NAS cert.

### Re-sealing IoT secrets

All IoT SealedSecrets must be re-sealed with the NAS cert:
```bash
kubeseal --cert k8s/argocd/nas/sealed-secrets.crt --format yaml < secret.yaml > sealed.yaml
```

Secrets to re-seal (currently in `k8s/argocd/iot/`):
- `hass-secrets` (hass ns)
- `hass-passwords` (hass ns)
- `mosquitto-passwordfile` (mosquitto ns)
- `zigbee2mqtt` (zigbee2mqtt ns)
- `gotomation-extra-flags` (gotomation ns)
- `google-dns-issuer-prod`, `google-dns-issuer-staging`, `google-dns01-solver` (cert-manager ns)

The `iot-cluster` secret in the argocd namespace on NAS is deleted (not re-sealed).

---

## Sops — worker1 Setup

After NixOS install on worker1, get its age pubkey:
```bash
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

Add to `.sops.yaml` under a `worker1` creation rule and run `sops updatekeys secrets/worker1.yaml`.

`secrets/worker1.yaml` needs:
- `k3s_cluster_token`
- `nmaupu_user_password`
- `telegram_token`
- `telegram_chat_id`

---

## worker1 NixOS Config

Mirrors IoT structure: `hosts/worker1/configuration.nix` + `hardware-configuration.nix`.

Key differences from IoT:
- No udev rules (no USB devices)
- No `linuxPackages_latest` requirement (no container-churn issue) — use default LTS
- No ZFS (no `boot.supportedFilesystems = ["zfs"]` — already in k3s.nix for NFS client only)
- Role: `agent`, serverUrl: `https://192.168.12.8:6443`
- Static DHCP lease: 192.168.12.41 / MAC TBD (set in OpenWrt once MAC is known)

---

## Migration Phases

### Phase 0 — NixOS k3s module + worker1 NixOS config
- [ ] Update `modules/shared/k3s.nix` to support agent role, tokenFile, nodeLabels, nodeTaints
- [ ] Create `hosts/worker1/configuration.nix` (no hardware-configuration.nix yet — generated on install)
- [ ] Add `worker1` to `flake.nix`
- [ ] Add `k3s_cluster_token` to `secrets/nas.yaml` and `secrets/iot.yaml`
- [ ] Update `hosts/nas/configuration.nix` and `hosts/iot/configuration.nix` to use new k3s-node options
- [ ] `nixos-rebuild switch --flake .#nas` (adds tokenFile + labels/taints, server role stays)

### Phase 1 — Install worker1
- [ ] Boot NixOS ISO on worker1
- [ ] `nixos-generate-config` → copy `hardware-configuration.nix` to repo
- [ ] Get SSH host key age pubkey → add to `.sops.yaml`, create `secrets/worker1.yaml`
- [ ] `nixos-install --flake .#worker1`
- [ ] Verify node appears in `kubectl get nodes` as Ready

### Phase 2 — Add node selectors to NAS workloads (NAS pinning)
- [ ] Add `nodeSelector: {role: nas}` + tolerations to all NAS Helm values that use ZFS hostPath PVs
- [ ] Push → ArgoCD syncs → validate NAS pods stay on NAS node

### Phase 3 — Migrate IoT to agent
- [ ] Add `nodeSelector: {role: iot}` + tolerations to all IoT app Helm values
- [ ] Scale down IoT stateful workloads (HA, CNPG, mosquitto, zigbee2mqtt)
- [ ] `nixos-rebuild switch --flake .#iot` (changes k3s role from server → agent, joins NAS cluster)
- [ ] IoT node appears in cluster as Ready
- [ ] Re-seal all IoT secrets with NAS cert
- [ ] Push IoT apps to NAS ArgoCD (update destination → in-cluster)
- [ ] ArgoCD syncs → validate all IoT workloads running on iot node

### Phase 4 — Merge MetalLB
- [ ] Update `k8s/argocd/nas/deploy/metallb/bgp-config/` with two IPAddressPools + updated BGPAdvertisement
- [ ] Update OpenWrt: add worker1 BGP peer (ASN 65001), change iot peer ASN 66001 → 65001
- [ ] Push → ArgoCD syncs NAS MetalLB
- [ ] Delete IoT MetalLB ArgoCD app (IoT standalone MetalLB removed)
- [ ] Validate all existing LB IPs still reachable (both 99.x and 100.x)

### Phase 5 — ArgoCD consolidation + cleanup
- [ ] Delete `iot-cluster` sealed secret (iot ArgoCD destination no longer exists)
- [ ] Delete IoT's standalone `iot-application-statics.yaml` AppProject
- [ ] Delete IoT's sealed-secrets controller ArgoCD app
- [ ] Confirm single sealed-secrets controller active on NAS
- [ ] Move IoT app YAMLs from `k8s/argocd/iot/` → `k8s/argocd/nas/` (or shared dir)
- [ ] Update `CLAUDE-iot.md` and `CLAUDE-nas.md` to reflect unified cluster

### Phase 6 — Validation
- [ ] `kubectl get nodes` → 3 nodes Ready
- [ ] `kubectl get pods -A -o wide` → all pods on correct nodes
- [ ] MetalLB IPs: 99.x (NAS workloads) and 100.x (IoT workloads) all reachable
- [ ] MQTT: `mosquitto_sub -h 192.168.100.35 -t '#'`
- [ ] Zigbee2MQTT both instances connected
- [ ] Home Assistant up at https://hass.home.fossar.net
- [ ] NAS workloads unaffected
