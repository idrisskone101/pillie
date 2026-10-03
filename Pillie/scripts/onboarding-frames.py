#!/usr/bin/env python3
"""Summarize PILLIE_FRAMES windows from a flow's app.log, per label.

Usage: Pillie/scripts/onboarding-frames.py APP_LOG [APP_LOG ...]
Several logs (repeat runs) pool into one table. Prints JSON with --json.
"""
import json
import re
import sys
from collections import defaultdict

LINE = re.compile(r"PILLIE_FRAMES (\S+) frames=(\d+) dropped=(\d+) worst=([\d.]+)ms")


def windows(paths):
    seen = set()
    for path in paths:
        for line in open(path, errors="replace"):
            match = LINE.search(line)
            # The probe prints and logs each line, so the stream can carry it twice.
            if not match or (path, line.split(" PILLIE_FRAMES")[0][-15:], match.group(0)) in seen:
                continue
            seen.add((path, line.split(" PILLIE_FRAMES")[0][-15:], match.group(0)))
            label, frames, dropped, worst = match.groups()
            yield label, int(frames), int(dropped), float(worst)


def summarize(paths):
    table = defaultdict(lambda: {"windows": 0, "dropped": 0, "worst_ms": []})
    for label, _, dropped, worst in windows(paths):
        row = table[label]
        row["windows"] += 1
        row["dropped"] += dropped
        row["worst_ms"].append(worst)
    return {
        label: {
            "windows": row["windows"],
            "dropped": row["dropped"],
            "worst_ms": max(row["worst_ms"]),
            "median_worst_ms": sorted(row["worst_ms"])[len(row["worst_ms"]) // 2],
        }
        for label, row in sorted(table.items())
    }


def main(argv):
    as_json = "--json" in argv
    paths = [a for a in argv if a != "--json"]
    if not paths:
        print(__doc__, file=sys.stderr)
        return 2
    summary = summarize(paths)
    if as_json:
        print(json.dumps(summary, indent=2))
        return 0
    print(f"{'label':34} {'win':>4} {'dropped':>8} {'worst':>8} {'median':>8}")
    for label, row in summary.items():
        print(f"{label:34} {row['windows']:>4} {row['dropped']:>8} {row['worst_ms']:>7.1f}ms {row['median_worst_ms']:>7.1f}ms")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
