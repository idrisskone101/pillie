#!/usr/bin/env python3
"""Unit tests for namespace-mac idle helpers. No live Namespace calls."""

from __future__ import annotations

import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import unittest
import unittest.mock
from pathlib import Path

API_PATH = Path(__file__).resolve().parent / "namespace-mac-api.py"
SCRIPT = Path(__file__).resolve().parent / "namespace-mac.sh"
SIM_QA = Path(__file__).resolve().parent / "sim-qa.sh"
ENSURE_TOOLS = Path(__file__).resolve().parent / "ensure-qa-tools.sh"
MAKEFILE = Path(__file__).resolve().parents[2] / "Makefile"
REPO_ROOT = Path(__file__).resolve().parents[2]
VERIFY_SKILL = REPO_ROOT / ".agents" / "skills" / "verify-pillie" / "SKILL.md"
POTETO_RULE = REPO_ROOT / ".cursor" / "rules" / "poteto-verify-pillie.mdc"


def load_api():
    spec = importlib.util.spec_from_file_location("namespace_mac_api", API_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class IdleHelpersTest(unittest.TestCase):
    def setUp(self) -> None:
        self.api = load_api()

    def test_normalize_idle_maps_15m_to_900s(self) -> None:
        self.assertEqual(self.api.normalize_idle("15m"), "900s")
        self.assertEqual(self.api.normalize_idle("900s"), "900s")
        self.assertEqual(self.api.normalize_idle(""), "900s")

    def test_idle_matches_spec(self) -> None:
        self.assertTrue(self.api.idle_matches_spec("900s", "15m"))
        self.assertTrue(self.api.idle_matches_spec("15m", "900s"))
        self.assertFalse(self.api.idle_matches_spec("14400s", "900s"))

    def test_apply_idle_skips_update_when_already_900s(self) -> None:
        with unittest.mock.patch.object(self.api, "devbox_rpc") as rpc:
            out = self.api.apply_idle({"busyEnsureMinimumDuration": "900s"})
        rpc.assert_not_called()
        self.assertEqual(out["busyEnsureMinimumDuration"], "900s")

    def test_apply_idle_updates_four_hour_idle(self) -> None:
        with unittest.mock.patch.object(
            self.api,
            "devbox_rpc",
            return_value={"busyEnsureMinimumDuration": "900s"},
        ) as rpc:
            out = self.api.apply_idle({"busyEnsureMinimumDuration": "14400s"})
        rpc.assert_called_once_with(
            "Update",
            {"name": "pillie-ios", "busyEnsureMinimumDuration": "900s"},
        )
        self.assertEqual(out["busyEnsureMinimumDuration"], "900s")


class HydrateAuthTest(unittest.TestCase):
    def test_nsc_token_overwrites_existing_token_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "token.json"
            dest.write_text(json.dumps({"bearer_token": "nsrt_" + "a" * 80}), encoding="utf-8")
            env = os.environ.copy()
            env["NSC_TOKEN"] = "nsrt_" + "b" * 80
            env["NSC_TOKEN_FILE"] = str(dest)
            env.pop("NAMESPACE_TOKEN", None)
            proc = subprocess.run(
                ["bash", str(SCRIPT), "hydrate-auth"],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertIn("from NSC_TOKEN", proc.stdout)
            data = json.loads(dest.read_text(encoding="utf-8"))
            self.assertEqual(data["bearer_token"], env["NSC_TOKEN"])
            self.assertEqual(stat.S_IMODE(dest.stat().st_mode), 0o600)


def _git(cwd: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=check,
        capture_output=True,
        text=True,
    )


def _init_repo(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    _git(path, "init")
    _git(path, "config", "user.email", "qa@example.com")
    _git(path, "config", "user.name", "QA")
    (path / "README").write_text("ok\n", encoding="utf-8")
    _git(path, "add", "README")
    _git(path, "commit", "-m", "init")


class WriteSshConfigTest(unittest.TestCase):
    def test_control_persist_is_thirty_minutes(self) -> None:
        api = load_api()
        with tempfile.TemporaryDirectory() as tmp:
            api.SSH_DIR = Path(tmp)
            api.SSH_HOST = "pillie-ios"
            key = b"-----BEGIN OPENSSH PRIVATE KEY-----\nAAA\n-----END OPENSSH PRIVATE KEY-----\n"
            path = api.write_ssh_files("inst-1", "ssh.iad4.namespace.so", key)
            text = path.read_text(encoding="utf-8")
        self.assertIn("ControlPersist 1800", text)
        self.assertIn("User inst-1", text)
        self.assertNotIn("ControlPersist 60", text)


class CheckSyncTest(unittest.TestCase):
    def test_rejects_dirty_head(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "app"
            _init_repo(repo)
            (repo / "README").write_text("dirty\n", encoding="utf-8")
            env = os.environ.copy()
            env["PILLIE_NS_REPO_ROOT"] = str(repo)
            proc = subprocess.run(
                ["bash", str(SCRIPT), "check-sync"],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("uncommitted changes", proc.stderr)

    def test_rejects_unpushed_head(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp) / "app"
            _init_repo(repo)
            env = os.environ.copy()
            env["PILLIE_NS_REPO_ROOT"] = str(repo)
            proc = subprocess.run(
                ["bash", str(SCRIPT), "check-sync"],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(proc.returncode, 0)
            self.assertIn("not on a remote", proc.stderr)

    def test_accepts_pushed_head(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            remote = Path(tmp) / "remote.git"
            repo = Path(tmp) / "app"
            _git(Path(tmp), "init", "--bare", str(remote))
            _init_repo(repo)
            _git(repo, "remote", "add", "origin", str(remote))
            _git(repo, "push", "-u", "origin", "HEAD")
            env = os.environ.copy()
            env["PILLIE_NS_REPO_ROOT"] = str(repo)
            proc = subprocess.run(
                ["bash", str(SCRIPT), "check-sync"],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertIn("is on a remote", proc.stdout)


class ScriptContractTest(unittest.TestCase):
    def test_scripts_parse(self) -> None:
        for path in (SCRIPT, SIM_QA, ENSURE_TOOLS, Path(__file__).resolve().parent / "build-and-run.sh"):
            subprocess.run(["bash", "-n", str(path)], check=True)

    def test_ensure_qa_tools_check_ok_when_stubs_on_path(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            bindir = Path(tmp) / "bin"
            bindir.mkdir()
            for name in ("axe", "magick"):
                stub = bindir / name
                stub.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
                stub.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bindir}:/usr/bin:/bin"
            proc = subprocess.run(
                ["bash", str(ENSURE_TOOLS), "--check"],
                check=True,
                capture_output=True,
                text=True,
                env=env,
            )
            self.assertIn("already on PATH", proc.stdout)
            self.assertNotIn("install:", proc.stdout)

    def test_ensure_qa_tools_check_fails_when_missing(self) -> None:
        env = os.environ.copy()
        env["PATH"] = "/usr/bin:/bin"
        proc = subprocess.run(
            ["bash", str(ENSURE_TOOLS), "--check"],
            capture_output=True,
            text=True,
            env=env,
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("missing:", proc.stdout)

    def test_sim_qa_sips_uses_1x_height(self) -> None:
        text = SIM_QA.read_text(encoding="utf-8")
        self.assertIn("sips -Z 874", text)
        self.assertNotIn("sips -Z 402", text)

    def test_build_and_run_boots_simulator(self) -> None:
        text = (Path(__file__).resolve().parent / "build-and-run.sh").read_text(encoding="utf-8")
        self.assertIn("pillie_boot_simulator", text)

    def test_xcode_env_defines_boot(self) -> None:
        text = (Path(__file__).resolve().parent / "xcode-env.sh").read_text(encoding="utf-8")
        self.assertIn("pillie_boot_simulator()", text)

    def test_makefile_has_qa_targets(self) -> None:
        text = MAKEFILE.read_text(encoding="utf-8")
        self.assertIn("ns-mac-qa", text)
        self.assertIn("ns-mac-check-sync", text)
        self.assertIn("ns-mac-ensure-tools", text)
        self.assertIn("sim-qa.sh --capture-only", text)

    def test_namespace_mac_prefers_qa(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("check_sync", text)
        self.assertIn("git reset --hard", text)
        self.assertIn("sim-qa.sh", text)
        self.assertIn("ensure-qa-tools.sh", text)
        self.assertIn("bash --login -s", text)
        self.assertNotIn("git checkout --detach", text)

    def test_sim_qa_ensures_tools(self) -> None:
        text = SIM_QA.read_text(encoding="utf-8")
        self.assertIn("ensure-qa-tools.sh", text)

    def test_verify_pillie_skill_points_at_ns_mac_qa(self) -> None:
        text = VERIFY_SKILL.read_text(encoding="utf-8")
        self.assertIn("name: verify-pillie", text)
        self.assertIn("make ns-mac-qa", text)
        self.assertIn("/poteto-mode", text)
        for name in ("today.md", "history.md", "settings.md", "soft-paywall.md"):
            self.assertTrue((VERIFY_SKILL.parent / "features" / name).is_file())

    def test_poteto_rule_loads_verify_pillie(self) -> None:
        text = POTETO_RULE.read_text(encoding="utf-8")
        self.assertIn("alwaysApply: true", text)
        self.assertIn("verify-pillie", text)
        self.assertIn("make ns-mac-qa", text)


if __name__ == "__main__":
    unittest.main()

