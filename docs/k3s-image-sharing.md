# K3s image sharing with Spegel

The shared module, `nix/modules/shared/k3s.nix`, configures K3s's embedded
Spegel mirror. This is a repository change, **not an applied rollout**.

## Configuration

- Servers start with `--embedded-registry`, enabling the cluster feature.
- Servers and agents get `/etc/rancher/k3s/registries.yaml` with
  `{"mirrors":{"*":{}}}`. JSON is valid YAML; the wildcard opts every registry
  into image sharing without inventing an external mirror endpoint.
- TCP **5001** (peer discovery) and **6443** (authenticated image transfers;
  also the server API) are allowed on every node. Existing ports are retained.
- The registry file is a K3s systemd restart trigger, so NixOS switches reload
  it on agents as well as servers.
- Default upstream registry fallback remains enabled. Unsupported sharing of
  `latest` tags is **not** enabled.

No additional registry Deployment, PVC, registry DNS name, or credentials are
needed. Existing server/agent roles, labels, taints, disabled components,
cluster-token paths, and Longhorn support are unchanged.

## What this does and does not guarantee

A node missing an image can pull it from a reachable peer that already has it
in K3s's containerd image store. This helps when rescheduling while the Internet
is unavailable, but **sharing is not automatic replication or durable storage**:

- An image absent from every reachable node still needs its upstream registry.
- Losing the only node with a cached image loses that offline source.
- Ordinary cached images can be garbage-collected. Deliberate pre-import/pinning
  of the full critical image set on multiple nodes remains a separate task.
  K3s supports pre-imported image archives and the NixOS module exposes
  `services.k3s.images`; neither is configured by this change.
- Use immutable digests where possible, or explicit version tags, with
  `imagePullPolicy: IfNotPresent`. Spegel does not share `latest` by default.
  Digest-based references also prevent a peer from substituting another image
  under the same mutable tag.
- All init containers and sidecars count, not just the HA application image.
  Gotomation, MQTT, Zigbee2MQTT, storage and other startup dependencies also need
  consideration. Persisted HA configuration, accessible storage and working LAN
  services remain necessary. USB/local-storage scheduling constraints do not
  disappear when images become available on another node.

## Trust and networking

Spegel assumes all cluster members are equally trusted. Wildcard sharing can
make a private image cached on one node available to other cluster members
without their having upstream registry credentials. Mirror API access is
protected by cluster certificates; discovery uses cluster authentication.

The module follows the existing host-wide firewall allowlist, **not a
source-CIDR restriction**. Keep 5001 and 6443 reachable between node internal
addresses, and do not expose them to untrusted networks or via router forwards.
Sharing is enabled for every registry; reassess that choice if nodes gain
unequal trust or registry access requirements.

## Rollout — operator action, not performed here

1. Schedule a maintenance window with alternate heating control available.
   Confirm the running K3s version supports Spegel and wildcard mirrors
   (the inspected cluster runs v1.34.5). Review/build each intended host's
   complete NixOS configuration before switching; the module tests below are
   not full host builds.
2. Apply the NAS server configuration first, using the normal NixOS deployment
   procedure. A switch restarts K3s; allow for temporary API/reconciliation
   disruption. Do not simultaneously restart other nodes.
3. Verify the server is Ready and inspect its K3s logs. Then apply agents one
   at a time, waiting for each to be healthy before proceeding. The configured
   hosts are `nas` (server), `worker1`, `worker2`, and legacy `iot` (agents);
   apply only to nodes actually present, not a decommissioned host.
4. On each participating host, inspect the rendered file and service:
   ```bash
   sudo systemctl status k3s --no-pager
   sudo systemctl show k3s -p ExecStart
   sudo journalctl -u k3s --since '10 minutes ago' --no-pager
   sudo ss -lntp '( sport = :5001 or sport = :6443 )'
   ```
   Check `/etc/rancher/k3s/registries.yaml` contains the wildcard mirror.
   Both ports must be reachable **between all nodes**, not only towards NAS.
   Check cluster readiness from the administration machine:
   ```bash
   kubectl --context home get nodes -o wide
   kubectl --context home get pods -A
   ```
5. For a controlled offline proof, use a disposable versioned image already
   pulled on a donor but absent on a receiving node. Verify the receiver's
   image inventory first (`sudo k3s crictl images`); do not remove heating or
   infrastructure images to manufacture a cache miss. Temporarily deny only
   the receiver's upstream registry access while preserving cluster/LAN access,
   then run `sudo k3s crictl pull <fully-qualified-versioned-image>` there.
   Confirm success, the new local image, and peer-transfer evidence in K3s logs.
   Local-cache success without a real cache miss does not prove peer sharing.
   Restore network access afterwards. Plan WAN-wide and node-loss tests
   separately; do not start by deleting/restarting the heating Pod.

If the rollout causes trouble, restore the previous NixOS generation on the
affected host using the normal rollback procedure (for example,
`sudo nixos-rebuild switch --rollback`). Verify readiness after each rollback;
this restores the prior registry file and K3s flags. Roll agents back before
the server if reverting the whole feature. No image deletion is required.

## Regression checks

See [`nix/tests/README.md`](../nix/tests/README.md). The checks evaluate the
shared module with the real, locked NixOS options and inspect generated service
commands, registry content, restart triggers, and firewall ports. They do not
start K3s or prove an actual offline transfer.

References:
- [K3s embedded registry mirror](https://docs.k3s.io/installation/registry-mirror)
- [K3s image pre-import](https://docs.k3s.io/import-images)
