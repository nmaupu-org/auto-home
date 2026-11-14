# Kubernetes resilience checks

Requirements: Python 3 with PyYAML, Bash, Git, rsync, GNU coreutils (including
`timeout`, `sha1sum`, `sort -z` and `stat -c`), Helm, Jsonnet, and shellcheck.
No Docker, Bazel, Kubernetes mutations, credentials, or real outage is needed.

The HA behavioral tests use real local Git repositories and isolated temporary
directories. Only external GitHub/download/Kubernetes boundaries are replaced
with controlled failures; they never contact GitHub or a cluster.

## Cache pinned deployment dependencies

The rendered-manifest tests use chart archives from `HELM_CHART_DIR` or
`~/.cache/helm/repository`. Missing chart archives are reported as skipped tests,
not as verified deployments. For a complete run, fetch all four archives first:

```bash
export HELM_CHART_DIR="$(mktemp -d)"
helm pull argo-cd --repo https://argoproj.github.io/argo-helm \
  --version 9.5.0 --destination "$HELM_CHART_DIR"
helm pull oci://oci.trueforge.org/truecharts/home-assistant \
  --version 30.0.4 --destination "$HELM_CHART_DIR"
helm pull vault --repo https://helm.releases.hashicorp.com \
  --version 0.32.0 --destination "$HELM_CHART_DIR"
helm pull openebs --repo https://openebs.github.io/openebs \
  --version 4.4.0 --destination "$HELM_CHART_DIR"
```

Matterbridge also needs its locked Jsonnet dependencies. They are ignored by Git;
if the `vendor` directory is absent, use jsonnet-bundler (`jb`):

```bash
(cd k8s/argocd/jsonnet/matterbridge && jb install)
```

Once these dependencies are cached, the tests run offline:

```bash
python3 -m unittest discover -s tests -v
git diff --check
```

Check that the complete run has **no skipped tests**.

## Check the actual embedded Bash

This extracts scripts from the same Helm values deployed to the cluster:

```bash
python3 - <<'PY'
from pathlib import Path
import subprocess
import tempfile
import yaml

values = yaml.safe_load(
    Path("k8s/argocd/home/iot/home-assistant/values.yaml").read_text()
)
scripts = values["configmap"]["init"]["data"]
with tempfile.TemporaryDirectory() as directory:
    paths = []
    for name, content in scripts.items():
        if name.endswith(".sh"):
            path = Path(directory) / name
            path.write_text(content)
            paths.append(path)
    for path in paths:
        subprocess.run(["bash", "-n", str(path)], check=True)
        subprocess.run(
            ["shellcheck", "-x", "-P", directory, str(path)], check=True
        )
PY
```

The tests verify script behavior and generated probe definitions, not a real
Pod replacement during a WAN outage. The safe operational validation procedure
and known limitations are in
[the audit](../docs/kubernetes-resilience.md).
