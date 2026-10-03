#!/usr/bin/env python3
"""Summarize PILLIE_FRAMES windows from a flow's app.log, per label.

Usage: Pillie/scripts/onboarding-frames.py APP_LOG [APP_LOG ...]
Several logs (repeat runs) pool into one table.
"""
import re
import sys
from collections import defaultdict

LINE = re.compile(r"PILLIE_FRAMES (\S+) frames=\d+ dropped=(\d+) worst=([\d.]+)ms")


def main(paths):
    if not paths:
        print(__doc__, file=sys.stderr)
        return 2
    table = defaultdict(lambda: {"dropped": 0, "worst": []})
    for path in paths:
        for match in map(LINE.search, open(path, errors="replace")):
            if match:
                label, dropped, worst = match.groups()
                table[label]["dropped"] += int(dropped)
                table[label]["worst"].append(float(worst))
    print(f"{'label':34} {'win':>4} {'dropped':>8} {'worst':>8} {'median':>8}")
    for label, row in sorted(table.items()):
        worst = sorted(row["worst"])
        print(f"{label:34} {len(worst):>4} {row['dropped']:>8} {worst[-1]:>7.1f}ms {worst[len(worst) // 2]:>7.1f}ms")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
