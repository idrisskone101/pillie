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


if __name__ == "__main__":
    unittest.main()
