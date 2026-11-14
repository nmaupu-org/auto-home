# Kubernetes Resilience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep local home automation available during Internet/GitHub outages and improve safe Kubernetes failure detection.

**Architecture:** Home Assistant starts from persistent configuration; configuration refresh is best-effort, bounded, and independent of readiness. Local loop progress detects a stuck reloader without measuring Internet availability. Enable chart-native probes and Matterbridge frontend checks; record unsupported upstream gaps instead of inventing ineffective process-existence probes.

**Tech Stack:** Helm values, Kubernetes YAML, Bash scripts embedded in ConfigMaps, Jsonnet, Python unittest/PyYAML, shellcheck.

**Spec:** Approved scope in this session: repository edits plus read-only inspection of context `home`; no live changes or changes to the separate Gotomation repository.

## Global Constraints

- No deployment, commits, pushes, branch management, or local Bazel/Bazelisk execution.
- Preserve HA persistent configuration and `.storage` integration state.
- Failed clone/fetch/download must not stop a previously configured HA instance or trigger an unnecessary rollout.
- First installation with no usable configuration still needs an initial download; never silently run an empty/default heating configuration.
- Probes must check local process responsiveness, not GitHub, Internet, external integrations, or a healthy unsealed Vault state.
- Gotomation already starts from its persistent config and tolerates fetch errors; document external-source improvements without editing that repository.

## Review Focus

- GitHub/DNS outage while cached configuration exists: retain service and retry updates.
- Sidecar-only restart: do not issue a redundant HA rollout.
- Empty/partial source cache: do not delete a usable `/config` or start with missing config.
- Slow/hung Git/download/API requests: bounded attempts; heartbeat detects a genuinely stuck loop.
- Partial optional UI downloads, failed rollout patches, and preservation of `.storage`: retry safely without poisoning live configuration.

---

### Task 1: Make Home Assistant refresh outage-safe

**Files:** Modify `k8s/argocd/home/iot/home-assistant/values.yaml`; create `tests/test_home_assistant_resilience.py`.

**Interfaces:** Scripts stay in the existing `init` ConfigMap and use the existing images/PVCs. Tests extract and execute the embedded scripts with temporary directories, real local Git repositories, and controlled external-command failures. Provide path/interval overrides only where needed to run the same production scripts safely in tests.

- [x] Write regression tests for failed Git fetch, offline cached startup, missing source cache with existing live config, absent initial config, sidecar-only restart, changed config, failed Kubernetes patch retry, and optional asset download failure.
- [x] Run `python3 -m unittest discover -s tests -v`; observe the relevant behavioral failures against existing scripts.
- [x] Refactor reloader into ConfigMap script(s); catch expected external failures explicitly and bound Git/curl/kubectl calls. Preserve existing asset versions and reflog cleanup.
- [x] Persist or reconstruct the loaded-config baseline so a sidecar restart alone does not restart HA. Patch only when configuration differs; retry failed patches.
- [x] Harden init: copy only a complete cached config, preserve `.storage`, fall back to existing usable live config offline, and bootstrap only when no config exists.
- [x] Add a local-progress heartbeat liveness check with enough startup/loop allowance; no Git-dependent readiness check.
- [x] Run behavioral tests, extracted `bash -n`/shellcheck, and render the pinned `home-assistant` 30.0.4 chart.

### Task 2: Add verified local probes

**Files:** Modify `k8s/argocd/home/infra/argocd/argocd-values.yaml`, `k8s/argocd/home/infra/vault/vault/values.yaml`, `k8s/argocd/jsonnet/matterbridge/manifests/deploy.jsonnet`; conditionally modify monitoring/cert-manager values only when exact pinned chart support is verified. Create `tests/test_kubernetes_probes.py`.

**Interfaces:** Render existing pinned charts and Jsonnet. Tests assert health-check contracts in resulting Kubernetes container definitions, not source text.

- [x] Add failing rendered-manifest tests for missing Argo CD ApplicationSet, notifications, Redis probes; Matterbridge startup/liveness/readiness; and safe Vault liveness. Document unconfigured Dex instead of enabling harmful probes.
- [x] Enable existing chart-native Argo CD probe options (chart 9.5.0); retain existing repo/server probes. Do not add an unsupported controller values key.
- [x] Verify HashiCorp Vault chart 0.32.0 support, then add liveness using `/v1/sys/health` with sealed/uninitialized/standby response overrides; preserve strict readiness.
- [x] Add Matterbridge frontend probes using configured `frontendPort`, with generous startup allowance and no HA connection dependency.
- [x] Verify pinned monitoring/cert-manager chart probe options; add supported safe missing probes only, with rendered coverage, or record the limitation.
- [x] Run manifest tests and render all touched deployment sources.

### Task 3: Document and verify the audit

**Files:** Create `docs/kubernetes-resilience.md` and a sanitized probe-inventory table if appropriate.

**Interfaces:** Inventory covers all 65 audited Deployment/StatefulSet/DaemonSet definitions and their 87 regular-container definitions; operator-created standalone Pods and one-shot Jobs are explicitly separate.

- [x] Record original missing probes, changes, and all remaining exceptions by component; distinguish inactive helper processes from real health detection.
- [x] Document HA offline behavior, first-bootstrap/image-cache/storage limits, Gotomation findings, read-only live evidence, and how to validate rollout/outage behavior later.
- [x] Run active diagnostics for touched files where supported; report unavailable language-server coverage honestly.
- [x] Run the complete Python suite, shell checks, Helm/Jsonnet renders, and `git diff --check`.
- [x] Request a fresh independent diff review focused on offline restart behavior, heartbeat timing, state preservation, probe correctness, and accidental live/secret changes.
- [x] Resolve findings, repeat checks, and report edits plus remaining operational limits without deploying or committing.

## Execution record

- Implemented in the approved existing checkout; no branch/worktree management,
  commits, publishing, or deployment was performed.
- Added supported OpenEBS Alloy liveness after verifying the nested
  `alloy.alloy.livenessProbe` setting in the pinned chart and its live endpoint.
- Dex remains deliberately unprobed: live logs confirm it is unconfigured and
  has no health listener. Unverified upstream helper gaps are documented.
- Independent review completed. Verified image binaries rather than trusting
  assumptions: init uses BusyBox timeout; the reloader lacks rsync. Added failing
  compatibility tests, then used portable timeout flags and existing cp/tar.
- Added a failing regression for partial optional clones; repaired replacement
  and retained shallow tag clones. No image rebuild is needed.
- Dismissed speculative digest-injection/init-order races: digest output comes
  from the trusted binary and ordinary init finishes before regular containers.
  Confirmed script updates trigger the chart's checksum/configmaps rollout.
- Final verification: 24/24 Python tests with no skips; all 5 embedded scripts
  passed bash syntax/shellcheck; Helm/Jsonnet renders, jsonnetfmt and diff check
  passed. YAML lint has no errors and one pre-existing comment warning.
- Active LSP found only informational spelling suggestions for `hass`; coverage
  is incomplete for some YAML and unsupported for Jsonnet. Explicit renderers,
  formatters and script tests provide verification.
- Actual nmaupu/hass-init:1.0.3 successfully bootstrapped a local Git fixture with
  Docker networking disabled; live read-only checks verified reloader binaries.
- Deferred minors: per-container non-root hardening; optional exponential backoff
  for one-minute patch retries. A cluster outage drill and semantic heating
  validation remain operator-run maintenance-window checks.

