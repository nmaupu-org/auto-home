"""Check rendered manifests, rather than assuming Helm accepts a values key."""
import os
import subprocess
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CACHE = Path.home() / ".cache/helm/repository"
CHARTS = Path(os.environ.get("HELM_CHART_DIR", CACHE))


def render(chart: str, version: str, release: str, namespace: str, values: str):
    archive = next((p for p in [CHARTS / f"{chart}-{version}.tgz",
                               CACHE / f"{chart}-{version}.tgz"] if p.exists()), None)
    if archive is None:
        raise unittest.SkipTest(f"Cache {chart}-{version}.tgz in HELM_CHART_DIR; see tests/README.md")
    result = subprocess.run(["helm", "template", release, str(archive),
                             "--namespace", namespace, "--kube-version", "1.34.0",
                             "-f", str(ROOT / values)],
                            check=True, capture_output=True, text=True)
    return {doc["metadata"]["name"]: doc for doc in yaml.safe_load_all(result.stdout)
            if doc and doc.get("kind") in ["Deployment", "StatefulSet", "DaemonSet"]}


def containers(workload):
    return {c["name"]: c for c in workload["spec"]["template"]["spec"]["containers"]}


class KubernetesProbeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.argo = render("argo-cd", "9.5.0", "argocd", "argocd",
                          "k8s/argocd/home/infra/argocd/argocd-values.yaml")
        cls.hass = render("home-assistant", "30.0.4", "home-assistant", "hass",
                          "k8s/argocd/home/iot/home-assistant/values.yaml")

    def test_argocd_supported_components_have_local_probes(self):
        for workload in ["argocd-applicationset-controller",
                         "argocd-notifications-controller", "argocd-redis"]:
            with self.subTest(workload=workload):
                container = next(iter(containers(self.argo[workload]).values()))
                for probe in ["livenessProbe", "readinessProbe"]:
                    self.assertIn(probe, container)
                    self.assertTrue("tcpSocket" in container[probe] or "exec" in container[probe])

    def test_home_assistant_keeps_http_probes(self):
        c = containers(self.hass["home-assistant"])["home-assistant"]
        for probe in ["startupProbe", "livenessProbe", "readinessProbe"]:
            self.assertEqual(c[probe]["httpGet"]["port"], 8123)

    def test_reloader_checks_progress_not_network_readiness(self):
        c = containers(self.hass["home-assistant"])["home-assistant-conf-reloader"]
        self.assertEqual(c["livenessProbe"]["exec"]["command"],
                         ["bash", "/config/init/health.sh"])
        self.assertEqual(c["startupProbe"]["exec"]["command"],
                         ["bash", "/config/init/health.sh"])
        self.assertNotIn("readinessProbe", c)

    def test_matterbridge_has_local_frontend_probes_and_startup_grace(self):
        directory = ROOT / "k8s/argocd/jsonnet/matterbridge"
        result = subprocess.run(["jsonnet", "-J", str(directory / "vendor"),
                                 "-J", str(directory),
                                 str(directory / "manifests/deploy.jsonnet")],
                                check=True, capture_output=True, text=True)
        c = containers(yaml.safe_load(result.stdout))["matterbridge"]
        for probe in ["startupProbe", "livenessProbe", "readinessProbe"]:
            self.assertIn(probe, c)
            self.assertEqual(c[probe]["httpGet"], {"path": "/", "port": 8283})
        startup = c["startupProbe"]
        self.assertGreaterEqual(startup["failureThreshold"] * startup["periodSeconds"], 180)


class OpenEBSProbeTest(unittest.TestCase):
    def test_alloy_liveness_checks_local_metrics_not_loki(self):
        archive = CACHE / "openebs-4.4.0.tgz"
        if not archive.exists():
            archive = CHARTS / "openebs-4.4.0.tgz"
        if not archive.exists():
            self.skipTest("Cache openebs-4.4.0.tgz; see tests/README.md")
        app = yaml.safe_load((ROOT / "k8s/argocd/home/infra/openebs/application.yaml").read_text())
        values = app["spec"]["source"]["helm"]["valuesObject"]
        result = subprocess.run(["helm", "template", "openebs", str(archive),
                                 "--namespace", "openebs", "-f", "-"],
                                input=yaml.safe_dump(values), capture_output=True,
                                text=True, check=True)
        workload = next(doc for doc in yaml.safe_load_all(result.stdout)
                        if doc and doc.get("kind") == "DaemonSet"
                        and doc["metadata"]["name"] == "openebs-alloy")
        c = containers(workload)["alloy"]
        self.assertIn("livenessProbe", c)
        self.assertEqual(c["livenessProbe"]["httpGet"],
                         {"path": "/metrics", "port": 12345})


class VaultProbeTest(unittest.TestCase):
    def test_liveness_accepts_sealed_and_uninitialized_but_readiness_does_not(self):
        workloads = render("vault", "0.32.0", "vault", "vault",
                           "k8s/argocd/home/infra/vault/vault/values.yaml")
        c = containers(workloads["vault"])["vault"]
        self.assertIn("livenessProbe", c)
        path = c["livenessProbe"]["httpGet"]["path"]
        self.assertIn("sealedcode=200", path)
        self.assertIn("uninitcode=200", path)
        self.assertIn("standbyok=true", path)
        self.assertEqual(c["readinessProbe"]["httpGet"]["path"], "/v1/sys/health")


if __name__ == "__main__":
    unittest.main()
