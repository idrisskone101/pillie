#!/usr/bin/env python3
"""Extract and compare accessibility identifiers from an axe describe-ui dump.

Used as the behavior pin for Swift taste refactors. A missing identifier after
a structure move is a regression. Extra identifiers are reported, not fatal.

    python3 Pillie/scripts/pin-axe-identifiers.py extract dump.txt > ids.txt
    python3 Pillie/scripts/pin-axe-identifiers.py compare baseline.txt current.txt
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

IDENTIFIER_PATTERNS = (
    re.compile(r'identifier\s*[:=]\s*"([^"]+)"', re.IGNORECASE),
    re.compile(r'AXIdentifier\s*[:=]\s*"([^"]+)"', re.IGNORECASE),
    re.compile(r'"identifier"\s*:\s*"([^"]+)"', re.IGNORECASE),
    re.compile(r'"axIdentifier"\s*:\s*"([^"]+)"', re.IGNORECASE),
    re.compile(r'"AXUniqueId"\s*:\s*"([^"]+)"'),
)

LABEL_PATTERNS = (
    re.compile(r'\blabel\s*[:=]\s*"([^"]+)"', re.IGNORECASE),
    re.compile(r'"label"\s*:\s*"([^"]+)"', re.IGNORECASE),
    re.compile(r'"AXLabel"\s*:\s*"([^"]+)"'),
)

SKIP_IDENTIFIERS = frozenset(
    {
        "",
        "null",
        "nil",
    }
)
SF_SYMBOL = re.compile(r"^[a-z0-9]+(?:[._][a-z0-9]+)+$")


def extract_identifiers(text: str) -> list[str]:
    found: set[str] = set()
    for pattern in IDENTIFIER_PATTERNS:
        for match in pattern.finditer(text):
            value = match.group(1).strip()
            if value and value not in SKIP_IDENTIFIERS and not SF_SYMBOL.match(value):
                found.add(value)
    return sorted(found)


def extract_labels(text: str) -> list[str]:
    found: set[str] = set()
    for pattern in LABEL_PATTERNS:
        for match in pattern.finditer(text):
            value = match.group(1).strip()
            if value:
                found.add(value)
    return sorted(found)


def load_dump(path: Path) -> str:
    raw = path.read_text(encoding="utf-8")
    stripped = raw.lstrip()
    if stripped.startswith("{") or stripped.startswith("["):
        try:
            json.loads(stripped)
        except json.JSONDecodeError:
            return raw
    return raw


def write_lines(values: list[str], dest) -> None:
    for value in values:
        dest.write(f"{value}\n")


def cmd_extract(args: argparse.Namespace) -> int:
    text = load_dump(args.dump)
    identifiers = extract_identifiers(text)
    if args.include_labels:
        for label in extract_labels(text):
            identifiers.append(f"label:{label}")
        identifiers = sorted(set(identifiers))
    write_lines(identifiers, sys.stdout)
    return 0


def cmd_compare(args: argparse.Namespace) -> int:
    baseline = {
        line.strip()
        for line in args.baseline.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }
    current_text = load_dump(args.current)
    current_ids = set(extract_identifiers(current_text))
    if args.include_labels:
        current_ids.update(f"label:{label}" for label in extract_labels(current_text))

    missing = sorted(baseline - current_ids)
    extra = sorted(current_ids - baseline)
    print(
        f"ok: compared {len(baseline)} baseline ids, "
        f"{len(current_ids)} current ids, "
        f"{len(missing)} missing, {len(extra)} extra"
    )
    for item in missing:
        print(f"MISSING\t{item}")
    if args.show_extra:
        for item in extra:
            print(f"EXTRA\t{item}")
    if missing:
        return 1
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract or compare axe accessibility identifiers."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    extract = sub.add_parser("extract", help="Print sorted identifiers from a dump.")
    extract.add_argument("dump", type=Path)
    extract.add_argument(
        "--include-labels",
        action="store_true",
        help="Also emit label:<text> rows.",
    )

    compare = sub.add_parser(
        "compare", help="Fail if baseline identifiers are missing from a dump."
    )
    compare.add_argument("baseline", type=Path)
    compare.add_argument("current", type=Path)
    compare.add_argument("--include-labels", action="store_true")
    compare.add_argument(
        "--show-extra",
        action="store_true",
        help="Print identifiers present now but not in the baseline.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.command == "extract":
        return cmd_extract(args)
    if args.command == "compare":
        return cmd_compare(args)
    raise SystemExit(f"unknown command {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
