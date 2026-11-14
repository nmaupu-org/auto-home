"""Execute the deployed HA scripts with real local Git and isolated PVC fixtures."""
import os
import re
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
VALUES = ROOT / "k8s/argocd/home/iot/home-assistant/values.yaml"
GIT: str = shutil.which("git") or "git"


class HomeAssistantResilienceTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cache = self.root / "conf-reloader/hass-config"
        self.config = self.root / "config"
        self.init = self.root / "init"
        self.bin = self.root / "bin"
        for path in [self.cache.parent, self.init, self.bin,
                     self.root / "secrets", self.root / "passwords"]:
            path.mkdir(parents=True, exist_ok=True)
        self.remote = self.root / "remote"
        self.remote.mkdir()
        self.git("init", "-q", "-b", "master", str(self.remote))
        self.git("-C", str(self.remote), "config", "user.email", "test@example.invalid")
        self.git("-C", str(self.remote), "config", "user.name", "Test")
        (self.remote / "configuration.yaml").write_text("automation: !include automations.yaml\n")
        (self.remote / "automations.yaml").write_text("[]\n")
        self.commit("initial")
        self.git("clone", "-q", str(self.remote), str(self.cache))
        (self.cache / "www").mkdir()
        (self.cache / "www/.download-complete").touch()
        (self.cache / ".storage").mkdir()
        (self.root / "secrets/secret.yaml").write_text("test_secret: cached\n")
        (self.root / "passwords/hass-passwords.json").write_text('{"users": []}\n')
        values = yaml.safe_load(VALUES.read_text())
        scripts = values["configmap"]["init"]["data"]
        for name, content in scripts.items():
            (self.init / name).write_text(content)
        # Before the refactor the reloader is an inline command; run that too.
        command = values["workload"]["main"]["podSpec"]["containers"]["conf-reloader"]["command"]
        if "sync.sh" not in scripts:
            (self.init / "sync.sh").write_text(command[-1])
        # Remap old absolute paths as well, so the regression runs on old code.
        replacements = {
            "/config/init": str(self.init),
            "/conf-reloader": str(self.cache.parent),
            "/config": str(self.config),
            "/hass-secrets": str(self.root / "secrets"),
            "/hass-passwords": str(self.root / "passwords"),
        }
        for path in self.init.iterdir():
            content = path.read_text()
            for old, new in replacements.items():
                content = re.sub(re.escape(old) + r'(?=/|["\s}])', new, content)
            path.write_text(content)
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        CACHE_DIR=str(self.cache), CONFIG_DIR=str(self.config),
                        INIT_DIR=str(self.init), SECRETS_DIR=str(self.root / "secrets"),
                        PASSWORDS_DIR=str(self.root / "passwords"),
                        PROGRESS_FILE=str(self.root / "progress"),
                        NAMESPACE="hass", REPO_URL=str(self.remote),
                        TEST_ROOT=str(self.root), REAL_GIT=GIT,
                        REAL_SLEEP=shutil.which("sleep") or "sleep",
                        GIT_TIMEOUT="1", ASSET_TIMEOUT="1", PATCH_TIMEOUT="1",
                        TEST_CYCLES="2")
        self.executable("git", '''#!/bin/bash
case " $* " in
  *" fetch "*|*" clone "*)
    if [ "${GIT_HANG:-0}" = 1 ]; then "$REAL_SLEEP" 10; fi
    if [ "${GIT_FAIL:-0}" = 1 ]; then echo "GitHub unavailable" >&2; exit 128; fi ;;
esac
# Never contact GitHub in tests, even when optional downloads run.
for arg in "$@"; do
  case "$arg" in https://*) exit 128 ;; esac
done
exec "$REAL_GIT" "$@"
''')
        self.executable("curl", "#!/bin/bash\nexit 22\n")
        self.executable("kubectl", '''#!/bin/bash
python3 -c 'import json,sys; json.loads(sys.argv[1])' "${@: -1}" || exit 1
count=0
if [ -f "$TEST_ROOT/patch-attempts" ]; then count=$(wc -l < "$TEST_ROOT/patch-attempts"); fi
echo attempt >> "$TEST_ROOT/patch-attempts"
if [ "${PATCH_FAIL_FIRST:-0}" = 1 ] && [ "$count" = 0 ]; then exit 1; fi
printf '%s\\n' "$*" >> "$TEST_ROOT/patches"
''')
        # End a real infinite script deterministically at its retry boundary.
        self.executable("sleep", '''#!/bin/bash
n=0
if [ -f "$TEST_ROOT/cycles" ]; then read -r n < "$TEST_ROOT/cycles"; fi
n=$((n + 1)); echo "$n" > "$TEST_ROOT/cycles"
if [ "$n" -ge "$TEST_CYCLES" ]; then exit 42; fi
''')

    def git(self, *args: str):
        return subprocess.run([GIT, *args], check=True,
                              capture_output=True, text=True)

    def commit(self, message):
        self.git("-C", str(self.remote), "add", ".")
        self.git("-C", str(self.remote), "commit", "-qm", message)

    def executable(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def run_script(self, name: str, **env: str):
        return subprocess.run(["bash", str(self.init / name)], env=dict(self.env, **env),
                              capture_output=True, text=True, timeout=8)

    def initialize(self):
        result = self.run_script("init.sh", GIT_FAIL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.config / "configuration.yaml").is_file())

    def assert_loop_survived(self, result):
        self.assertEqual(result.returncode, 42, result.stderr[-3000:])

    def patches(self):
        path = self.root / "patches"
        return path.read_text().splitlines() if path.exists() else []

    def test_first_bootstrap_supports_busybox_timeout_options(self):
        shutil.rmtree(self.cache)
        self.env["REAL_TIMEOUT"] = shutil.which("timeout") or "timeout"
        self.executable("timeout", '''#!/bin/bash
case "$1" in
  --*) echo "BusyBox: unsupported long option" >&2; exit 1 ;;
esac
exec "$REAL_TIMEOUT" "$@"
''')
        result = self.run_script("init.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.config / "configuration.yaml").is_file())

    def test_reloader_can_clone_without_rsync_in_its_image(self):
        self.initialize()
        shutil.rmtree(self.cache)
        self.executable("rsync", "#!/bin/bash\nexit 127\n")
        self.assert_loop_survived(self.run_script("sync.sh"))
        self.assertTrue((self.cache / "configuration.yaml").is_file())
        self.assertEqual(self.patches(), [])

    def test_optional_asset_retry_replaces_partial_clone_directory(self):
        for tag in ["1.12.1", "1.3.2", "2.4.4", "c246a4f"]:
            self.git("-C", str(self.remote), "tag", tag)
        partial = self.cache / "www/auto-entities"
        partial.mkdir()
        (partial / "incomplete").touch()
        self.executable("git", '''#!/usr/bin/env python3
import os,sys
args = [os.environ["REPO_URL"] if a.startswith("https://github.com/") else a
        for a in sys.argv[1:]]
os.execv(os.environ["REAL_GIT"], [os.environ["REAL_GIT"], *args])
''')
        # All four real local clones succeed; the first external curl fails.
        result = self.run_script("assets.sh")
        self.assertEqual(result.returncode, 22, result.stderr)
        self.assertTrue((partial / ".git").is_dir())
        self.assertFalse((partial / "incomplete").exists())
        self.assertFalse((partial / "auto-entities.tmp").exists())

    def test_optional_assets_publish_without_rsync_in_reloader_image(self):
        self.initialize()
        (self.cache / "www/.download-complete").unlink()
        (self.cache / "www/local-card.js").write_text("// cached card\n")
        self.executable("rsync", "#!/bin/bash\nexit 127\n")
        self.assert_loop_survived(self.run_script("sync.sh"))
        self.assertEqual((self.config / "www/local-card.js").read_text(),
                         "// cached card\n")

    def test_heartbeat_accepts_progress_and_rejects_missing_or_stale_loop(self):
        self.assertNotEqual(self.run_script("health.sh").returncode, 0)
        progress = self.root / "progress"
        progress.touch()
        self.assertEqual(self.run_script("health.sh").returncode, 0)
        stale = time.time() - 660
        os.utime(progress, (stale, stale))
        self.assertNotEqual(self.run_script("health.sh").returncode, 0)

    def test_secret_updates_still_roll_when_github_is_unavailable(self):
        self.initialize()
        (self.root / "secrets/secret.yaml").write_text("test_secret: changed\n")
        self.assert_loop_survived(self.run_script("sync.sh", GIT_FAIL="1"))
        self.assertEqual(len(self.patches()), 1)
        self.assertEqual((self.cache / "secrets.yaml").read_text(),
                         "test_secret: changed\n")

    def test_fetch_failure_keeps_cached_config_and_retries(self):
        self.initialize()
        result = self.run_script("sync.sh", GIT_FAIL="1")
        self.assert_loop_survived(result)
        self.assertEqual((self.config / "automations.yaml").read_text(), "[]\n")
        self.assertEqual(self.patches(), [])
        self.assertTrue((self.root / "progress").exists())

    def test_hung_fetch_is_bounded_and_retried(self):
        self.initialize()
        result = self.run_script("sync.sh", GIT_HANG="1")
        self.assert_loop_survived(result)
        self.assertEqual(self.patches(), [])

    def test_sidecar_restart_does_not_roll_unchanged_home_assistant(self):
        self.initialize()
        result = self.run_script("sync.sh")
        self.assert_loop_survived(result)
        self.assertEqual(self.patches(), [], "Unchanged config must not trigger a rollout")

    def test_changed_config_rolls_once(self):
        self.initialize()
        (self.remote / "automations.yaml").write_text("- id: heating\n")
        self.commit("change")
        self.assert_loop_survived(self.run_script("sync.sh"))
        self.assertEqual(len(self.patches()), 1)
        self.assertEqual((self.cache / "automations.yaml").read_text(), "- id: heating\n")
        # Only a new Pod's init container should replace the running config.
        self.assertEqual((self.config / "automations.yaml").read_text(), "[]\n")

    def test_failed_patch_retries_without_crashing(self):
        self.initialize()
        (self.remote / "automations.yaml").write_text("- id: heating\n")
        self.commit("change")
        self.assert_loop_survived(self.run_script("sync.sh", PATCH_FAIL_FIRST="1"))
        self.assertEqual(len(self.patches()), 1)

    def test_offline_init_preserves_existing_live_config_when_cache_missing(self):
        self.initialize()
        shutil.rmtree(self.cache)
        self.assertEqual(self.run_script("init.sh", GIT_FAIL="1").returncode, 0)
        self.assertEqual((self.config / "automations.yaml").read_text(), "[]\n")

    def test_partial_cache_never_deletes_live_configuration(self):
        self.initialize()
        (self.cache / "configuration.yaml").unlink()
        (self.cache / "automations.yaml").unlink()
        result = self.run_script("init.sh", GIT_FAIL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.config / "configuration.yaml").is_file())
        self.assertTrue((self.config / "automations.yaml").is_file())

    def test_online_refresh_repairs_incomplete_cache_after_offline_fallback(self):
        self.initialize()
        (self.cache / "configuration.yaml").unlink()
        result = self.run_script("init.sh", GIT_FAIL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_loop_survived(self.run_script("sync.sh"))
        self.assertTrue((self.cache / "configuration.yaml").is_file())
        self.assertTrue((self.config / "configuration.yaml").is_file())

    def test_no_configuration_fails_clearly_instead_of_starting_empty(self):
        shutil.rmtree(self.cache)
        result = self.run_script("init.sh", GIT_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.config / "configuration.yaml").exists())

    def test_first_online_bootstrap_populates_config_before_home_assistant(self):
        shutil.rmtree(self.cache)
        result = self.run_script("init.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.config / "automations.yaml").read_text(), "[]\n")

    def test_integration_storage_is_preserved_on_restart(self):
        self.initialize()
        integration = self.config / ".storage/core.config_entries"
        integration.write_text('{"heating": "local"}')
        self.initialize()
        self.assertEqual(integration.read_text(), '{"heating": "local"}')

    def test_optional_asset_failure_does_not_block_config_update(self):
        self.initialize()
        shutil.rmtree(self.cache / "www")
        (self.remote / "automations.yaml").write_text("- id: heating\n")
        self.commit("change")
        self.assert_loop_survived(self.run_script("sync.sh"))
        self.assertEqual(len(self.patches()), 1)
        self.assertFalse((self.cache / "www/.download-complete").exists())


if __name__ == "__main__":
    unittest.main()
