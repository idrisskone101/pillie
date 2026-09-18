#!/usr/bin/env python3
"""Unit tests for parse_frame_metrics.py. No simulator."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

PARSER = Path(__file__).resolve().parent / "parse_frame_metrics.py"


def load_parser():
    spec = importlib.util.spec_from_file_location("parse_frame_metrics", PARSER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ParseFrameMetricsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.parser = load_parser()

    def test_prefers_json_payload(self) -> None:
        log = (
            "PILLIE_FRAMES home->history frames=20 dropped=1 worst=33.0ms\n"
            'PILLIE_FRAMES_JSON {"transitions": 2, "clean": 1, "dropped": 1, "worst_ms": 33.0, '
            '"calendar_height_shift_pt": 0, "calendar_height_samples": [], "windows": []}\n'
        )
        parsed = self.parser.parse_log(log)
        self.assertEqual(parsed["transitions"], 2)
        self.assertEqual(parsed["dropped"], 1)

    def test_rebuilds_from_lines_when_json_missing(self) -> None:
        log = (
            "PILLIE_FRAMES month+1 frames=40 dropped=2 worst=48.2ms\n"
            "PILLIE_FRAMES month-1 frames=38 dropped=0 worst=16.7ms\n"
            "PILLIE_LAYOUT calendar key=2026-09 value=412.0\n"
            "PILLIE_LAYOUT calendar key=2026-10 value=380.0\n"
            "PILLIE_FRAMES SUMMARY transitions=2 clean=1 dropped=2 worst=48.2ms\n"
        )
        parsed = self.parser.parse_log(log)
        self.assertEqual(parsed["transitions"], 2)
        self.assertEqual(parsed["clean"], 1)
        self.assertEqual(parsed["dropped"], 2)
        self.assertAlmostEqual(parsed["worst_ms"], 48.2)
        self.assertAlmostEqual(parsed["calendar_height_shift_pt"], 32.0)
        self.assertEqual(parsed["windows"][0]["label"], "month+1")


if __name__ == "__main__":
    unittest.main()
