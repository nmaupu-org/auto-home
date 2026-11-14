# Kubernetes resilience audit

Read-only inspection of context `home`, 2026-11-14. No live workload was
modified or restarted as part of this audit.

## Results and scope

- 65 Deployment/StatefulSet/DaemonSet definitions, containing 87 regular-container
  definitions (not replica counts).
- At inspection time, all these workloads were running/ready.
- 47 container definitions had liveness probes; 40 did not.
- Repository changes add liveness to **7** definitions, leaving **33** explicit
  exceptions. This is a projected result after deployment, not the live state.
- Jobs, ordinary init containers, and operator-created standalone Pods are not
  covered by this controller-template inventory. In particular, Longhorn instance
  managers and any CNPG database Pods need their operator's health policy.
- Existing checks were inventoried, not fault-injected. TCP checks detect a closed
  listener, not every possible application deadlock. Even an HTTP endpoint cannot
  prove every heating automation is functioning.

An exited container is already restarted by the Pod's restart policy. A liveness
probe is for a process that remains running but is no longer responsive.
Readiness removes a Pod from Service endpoints; it does **not** restart it.

## Home Assistant: confirmed failure and fix

Previous config-reloader logs ended at:

```text
git fetch origin master
fatal: unable to access 'https://github.com/nmaupu/hass-config.git/':
Could not resolve host: github.com
```

The reloader had 8 restarts with the last exit code 128; the HA main container
had **0** restarts. A failing regular sidecar makes the whole Pod unready even if
the main HA process is still running. That removes Service routing and can break
Gotomation/Matterbridge connections to HA. The precise historical chain that
stopped heating was not established; no outage was deliberately induced.

The updated ConfigMap scripts:

1. Init uses the persistent source cache, or retains existing live configuration
   when the source cache is incomplete/missing. It downloads only for a first
   installation with neither configuration available.
2. A first install fails clearly without configuration; it never silently starts
   with a default/empty heating setup.
3. Init does not delete `.storage`, image metadata, or the mounted `init`
   ConfigMap. Copy errors are no longer ignored. Existing integration entries
   are preserved; onboarding and the managed password-provider file still come
   from their existing ConfigMap/Secret sources, as before.
4. Git fetch/clone failures are logged and retried every 60 seconds; they do not
   terminate the reloader. A missing tracked `configuration.yaml` is restored
   after a successful fetch.
5. Git attempts have a 30-second timeout plus a 5-second kill grace. Git
   interactive prompting is disabled. Kubernetes patch attempts have a 15-second
   timeout plus kill grace and a 10-second request timeout.
6. Init records the loaded source digest in `/config/.hass-config-sha1`.
   Sidecar restarts reuse that baseline instead of restarting HA for unchanged
   config. Failed rollout requests are retried rather than acknowledged.
7. Optional dashboard downloads run in a separate strict shell with an overall
   180-second timeout. Curl fails on HTTP errors and downloads to temporary files
   before publication. Completed downloads are reused; incomplete attempts retry.
   Assets are copied into live `www` without restarting HA.
8. A local progress heartbeat remains healthy during Internet outages. It fails
   if the sync loop has not advanced for 600 seconds. Startup/liveness check this
   heartbeat, not GitHub. There is no Git-dependent sidecar readiness probe.
9. Existing images are reused: init uses BusyBox-compatible `timeout -k`; the
   reloader uses its installed `tar`/`cp`, not `rsync` (which is absent there).
   Init still uses its existing `rsync`. The actual init image was also tested
   in a network-disabled local container against a local Git fixture.
10. Configuration changes, including managed Secret changes, can still request a
   deliberate HA rollout. Optional UI assets and Git metadata do not affect the
   automation-config digest. Reflog growth remains disabled.

The existing HA HTTP startup/liveness/readiness checks on port 8123 are retained.
The pinned chart includes `checksum/configmaps` on the Pod template, so script
ConfigMap edits trigger a normal GitOps rollout; no manual restart is required.

### Offline limits

- At least one usable persisted config and the required images cached on the
  scheduled node are necessary for offline restart. `IfNotPresent` does not
  supply an image to a node that has never pulled it.
- Working LAN DNS, MQTT, Kubernetes, and persistent storage remain dependencies.
  Cloud integrations cannot be made local merely by fixing this reloader.
- A first installation with empty/lost PVCs requires initial configuration
  provisioning. Optional dashboard cards may be absent until downloads finish.
- The scripts detect presence of the main config file, not full HA semantic
  validity. A bad Git commit can still require repair/rollback. Init copy/I/O
  failures deliberately block startup instead of running a partially copied
  config; PVC/cache repair can be necessary even if some old files remain.
- Deliberate HA rollouts still briefly interrupt automation, and the existing
  ephemeral SQLite recorder is wiped on Pod replacement, by current design.

## Other probe changes

| Component | Check | Evidence / safety |
| --- | --- | --- |
| Argo CD ApplicationSet | Chart-native TCP local listener on 8081; liveness/readiness | Pinned argo-cd 9.5.0 template supports these options; live HTTP response confirms the listener, though `/healthz` itself is 404. |
| Argo CD notifications | Chart-native TCP metrics listener on 9001; liveness/readiness | Live `/metrics` returned HTTP 200. No notification-provider dependency. |
| Argo CD Redis | Chart-native exec liveness/readiness scripts | Pinned chart mounts its own authenticated Redis health scripts at `/health`. |
| Vault | HTTP liveness on 8200 | `/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200` returned 200. A sealed/uninitialized server is alive but retains strict readiness. HashiCorp chart 0.32.0 render verified. |
| Matterbridge | Local frontend HTTP startup/liveness/readiness | `/` on 8283 returned 200. Five-minute startup budget; checks do not depend on HA's connection status. |
| OpenEBS Alloy | Local `/metrics` HTTP liveness on 12345 | Endpoint returned 200; OpenEBS 4.4.0 rendered with `alloy.alloy.livenessProbe`. Existing readiness retained. Only the repository-managed `openebs` release is changed. |

Probe responses were checked through temporary read-only localhost port forwards.
Those processes were terminated; the checks did not install resources or exec
commands in containers.

## Remaining liveness gaps: explicit exceptions

These are **not claimed fixed**. Blindly adding `kill -0 1`, checking
`/proc/self`, or testing file existence would not detect a stuck application.

| Components | Why unchanged / next step |
| --- | --- |
| Argo CD Dex | Live logs say `dex is not configured`; its wrapper idles without a health listener. Enabling HTTP probes now would cause a restart loop. If SSO is configured later, enable the chart's Dex probes then. |
| Argo CD application controller | Chart 9.5.0 supplies readiness but no native liveness option. Add a supported upstream health policy/overlay in a separate change rather than inventing a values key. |
| Argo CD CMP sidecar | Communicates via a Unix socket; socket existence alone is not responsiveness. Requires a real plugin RPC health check. |
| cert-manager cainjector | No directly configurable probe block in the installed chart. Needs an upstream-supported health endpoint/configuration, not a process-existence check. Controller/webhook liveness already exists. |
| Prometheus operator | Pinned kube-prometheus-stack 61.2.0's operator Deployment template does not render liveness options. Its separate admission-webhook deployment probe settings do not apply to this container. Grafana itself already has both probes. |
| Grafana dashboard/datasource sidecars; Prometheus and Alloy config reloaders | Helpers need their own verified health endpoints and chart-supported injection. Do not probe remote configuration sources or just the files they produce. |
| Gotomation Git refresher | Deployment is generated from a separate repository. Its nonfatal loop already preserves service during fetch errors; adding bounded Git operations and a progress heartbeat requires a change there. |
| Vault autounseal | Separate helper without a verified local health contract. Vault being sealed is not grounds for restarting a healthy helper indefinitely. |
| Longhorn CSI attacher/provisioner/resizer/snapshotter, driver deployer, UI, manager | Pinned integration does not expose an obvious chart-native probe override for these containers. CSI health endpoints and manager state must be handled by supported upstream policies/overlays; do not restart storage services based on storage/backend unavailability. |
| Longhorn node-driver registrar and liveness-probe helper | CSI helpers are not the CSI driver itself; the driver already has startup/liveness. Health must check the intended process, not self-probe the health helper blindly. |
| Longhorn pre-pull-share-manager-image | Intentional `sleep infinity` after image pre-pull; not a serving application. |
| NFS external provisioner | No verified local application-health contract. A filesystem test could block on unavailable NFS or succeed despite a deadlocked provisioner. Upstream health support is needed. |
| OpenEBS ZFS controller/node containers | CSI/plugin health integration needs supported upstream configuration. Do not replace it with a generic shell/proc check; many sidecar images may not include a shell. |
| Legacy `iot-openebs-alloy` | Separate live release without a matching application definition here. No live patch was applied; mirror the supported Alloy liveness values when its owning release is managed. |
| MetalLB FRR reloader/metrics helpers | Their health/lifecycle differs from the main speaker/FRR processes, which already have liveness. Requires verified upstream helper checks. |

## Gotomation assessment

The live init script checks for `/config/gotomation.yaml` and exits successfully
without touching Git when it already exists on the persistent NFS PVC. Its
refresher does not use `set -e`; fetch/reset/sync are chained with `&&` and
failures return to the retry loop. The main container already has `/health`
liveness and `/health-ex` readiness on 6265.

Therefore the same Internet/GitHub-induced sidecar crash is **not present** in
the inspected Gotomation deployment. First bootstrap still needs the config repo;
unbounded Git calls and a missing refresher heartbeat are follow-ups in that
repository. It can still lose access to HA if the HA Pod is unready.

An unrelated live GitOps issue was also observed: `iot-gotomation` is Healthy
but Sync Unknown, with a ComparisonError for a missing
`k8s-libsonnet/1.32/main.libsonnet` import. The running workload is unaffected
at inspection time, but desired-state changes may not render until the dependency
problem is repaired in the upstream deployment source/plugin dependency handling.

### Jsonnet dependency fix

The CMP logs confirmed that `jb update` fetched a newer `k8s-libsonnet` main
revision whose archive no longer contains `1.32`. The download returned HTTP 200,
then installation panicked; the shell retry loop nevertheless returned success
and allowed generation to continue with missing dependencies. Gotomation's
committed lockfile pins a revision that still contains the required directory.

The plugin init script now requires a nonempty committed lockfile and runs
`timeout -k 5 40 jb install` under strict Bash error handling. Installation
failures and timeouts are propagated rather than hidden. Dependency updates
belong in a reviewed lockfile change, not in Argo CD manifest generation.
No Gotomation import changes or image rebuild are required.

After deploying the Argo CD configuration, ensure repo-server/CMP has rolled out
(the plugin file is mounted with `subPath`), then hard-refresh `iot-gotomation`
to clear any cached generation error. This repository edit has not been deployed.
Fresh dependency installation still needs GitHub; fully offline rendering would
require vendored libraries or a versioned image containing the locked dependencies.

## Verification and deployment

See [tests/README.md](../tests/README.md) for reproducible local checks and
[the full inventory](kubernetes-probe-inventory.md) for all 87 container definitions.
The Python suite runs extracted deployment scripts against isolated directories,
real local Git repositories, and controlled failures at the GitHub/Kubernetes
boundaries. It also renders the pinned Helm/Jsonnet deployment sources.

The automated suite is not a real cluster outage drill. After reviewing and
deploying through the normal GitOps workflow, validate during a safe maintenance
window with alternative heating control available:

1. Wait for Argo CD sync/health, HA probes and both HA containers to be ready.
2. Check HA Service endpoints, local UI/API access, MQTT/device behavior, and the
   actual heating control loop, not just the Pod status.
3. Confirm repeated Git/DNS failures produce warnings without reloader restarts,
   missing Service endpoints, or unnecessary HA rollouts.
4. Separately validate a Pod replacement while WAN access is unavailable, with
   its PVCs accessible and images already cached on the destination node.
5. Restore WAN access and confirm configuration updates resume and cause only
   intentional rollouts. Never remove PVCs to simulate a network outage.

Independent review was followed by runtime compatibility checks and regression
fixes. Init-before-sidecar ordering is guaranteed by Kubernetes, and the digest
comes from the trusted `sha1sum` binary rather than external JSON input. Timeouts
are hard total budgets: slow GitHub responses are retried without making the Pod
unready. Semantic heating checks and unverified upstream helper probes remain
explicit follow-ups, not guarantees of this patch.

Nonblocking follow-ups: per-container non-root hardening for the existing
reloader security context, and optional exponential backoff for its already
rate-limited one-minute Kubernetes patch retries.

No deployment, cluster-side outage simulation, commit, or push was performed.
