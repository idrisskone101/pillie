#!/usr/bin/env python3
"""Parse PILLIE_FRAMES / PILLIE_LAYOUT / PILLIE_FRAMES_JSON log lines."""

from __future__ import annotations

import json
import re
import sys
from typing import Any

FRAMES_LINE = re.compile(
    r"PILLIE_FRAMES (?P<label>\S+) frames=(?P<frames>\d+) dropped=(?P<dropped>\d+) worst=(?P<worst>[0-9.]+)ms"
)
SUMMARY_LINE = re.compile(
    r"PILLIE_FRAMES SUMMARY transitions=(?P<transitions>\d+) clean=(?P<clean>\d+) dropped=(?P<dropped>\d+) worst=(?P<worst>[0-9.]+)ms"
)
LAYOUT_LINE = re.compile(
    r"PILLIE_LAYOUT (?P<name>\S+) key=(?P<key>\S+) value=(?P<value>[0-9.]+)"
)
JSON_LINE = re.compile(r"PILLIE_FRAMES_JSON (?P<json>\{.*\})\s*$")


def parse_log(text: str) -> dict[str, Any]:
    payload: dict[str, Any] | None = None
    windows: list[dict[str, Any]] = []
    heights: list[float] = []
    summary: dict[str, Any] | None = None

    for raw in text.splitlines():
        line = raw.strip()
        json_match = JSON_LINE.search(line)
        if json_match:
            payload = json.loads(json_match.group("json"))
            continue
        summary_match = SUMMARY_LINE.search(line)
        if summary_match:
            summary = {
                "transitions": int(summary_match.group("transitions")),
                "clean": int(summary_match.group("clean")),
                "dropped": int(summary_match.group("dropped")),
                "worst_ms": float(summary_match.group("worst")),
            }
            continue
        frames_match = FRAMES_LINE.search(line)
        if frames_match:
            windows.append(
                {
                    "label": frames_match.group("label"),
                    "frames": int(frames_match.group("frames")),
                    "dropped": int(frames_match.group("dropped")),
                    "worst_ms": float(frames_match.group("worst")),
                }
            )
            continue
        layout_match = LAYOUT_LINE.search(line)
        if layout_match and layout_match.group("name") == "calendar":
            heights.append(float(layout_match.group("value")))

    if payload is not None:
        return payload

    shift = (max(heights) - min(heights)) if heights else 0.0
    if summary is None:
        summary = {
            "transitions": len(windows),
            "clean": sum(1 for window in windows if window["dropped"] == 0),
            "dropped": sum(window["dropped"] for window in windows),
            "worst_ms": max((window["worst_ms"] for window in windows), default=0.0),
        }
    return {
        **summary,
        "calendar_height_shift_pt": shift,
        "calendar_height_samples": heights,
        "windows": windows,
    }


def main() -> int:
    text = sys.stdin.read() if len(sys.argv) < 2 else open(sys.argv[1], encoding="utf-8").read()
    json.dump(parse_log(text), sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
