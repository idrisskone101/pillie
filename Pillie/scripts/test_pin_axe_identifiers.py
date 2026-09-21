#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "pin-axe-identifiers.py"


def load_pin():
    spec = importlib.util.spec_from_file_location("pin_axe_identifiers", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PinAxeIdentifiersTest(unittest.TestCase):
    def setUp(self) -> None:
        self.pin = load_pin()

    def test_extracts_identifier_styles(self) -> None:
        dump = """
        Button label: "Today" identifier: "homeBlockingStatusCard"
        {"identifier": "settingsLanguageRow", "label": "Language"}
        AXIdentifier="commerceAccessRetryButton"
        """
        ids = self.pin.extract_identifiers(dump)
        self.assertEqual(
            ids,
            [
                "commerceAccessRetryButton",
                "homeBlockingStatusCard",
                "settingsLanguageRow",
            ],
        )

    def test_compare_fails_on_missing_baseline_id(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "baseline.txt"
            current = Path(tmp) / "current.txt"
            baseline.write_text("homeBlockingStatusCard\nsettingsLanguageRow\n")
            current.write_text('identifier: "homeBlockingStatusCard"\n')
            status = self.pin.main(["compare", str(baseline), str(current)])
            self.assertEqual(status, 1)

    def test_compare_passes_when_baseline_is_subset(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            baseline = Path(tmp) / "baseline.txt"
            current = Path(tmp) / "current.txt"
            baseline.write_text("homeBlockingStatusCard\n")
            current.write_text(
                'identifier: "homeBlockingStatusCard"\nidentifier: "settingsLanguageRow"\n'
            )
            status = self.pin.main(["compare", str(baseline), str(current)])
            self.assertEqual(status, 0)


if __name__ == "__main__":
    unittest.main()
