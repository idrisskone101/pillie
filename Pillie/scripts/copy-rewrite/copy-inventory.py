#!/usr/bin/env python3
"""Dump every user-facing string Pillie ships, with locale coverage.

One row per catalog key. Use it to audit copy before a rewrite and to
diff the English after one:

    python3 Pillie/scripts/copy-rewrite/copy-inventory.py --tsv out.tsv
    python3 Pillie/scripts/copy-rewrite/copy-inventory.py --summary
"""

from __future__ import annotations

import argparse
import csv
import json
import plistlib
import re
import sys
from collections import Counter
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
APP_ROOT = REPO_ROOT / "Pillie"
CATALOGS = {
    "Localizable": APP_ROOT / "Pillie" / "Localizable.xcstrings",
    "Commerce": APP_ROOT / "Pillie" / "Commerce.xcstrings",
    "Notifications": APP_ROOT / "Pillie" / "Notifications.xcstrings",
    "Shield": APP_ROOT / "PillieShieldConfiguration" / "Shield.xcstrings",
}
SOURCE_DIRS = [
    APP_ROOT / "Pillie",
    APP_ROOT / "PillieShieldConfiguration",
    APP_ROOT / "PillieDeviceActivityMonitor",
    APP_ROOT / "PillieShieldAction",
]

sys.path.insert(0, str(SCRIPT_DIR))
from importlib import import_module  # noqa: E402

APP_LANGUAGE_CODES: list[str] = import_module("check-translated-copy").APP_LANGUAGE_CODES

SURFACES = [
    ("paywall", "Paywall"),
    ("trial", "Trial"),
    ("onboarding", "Onboarding"),
    ("today", "Home"),
    ("home", "Home"),
    ("history", "History"),
    ("calendar", "History"),
    ("settings", "Settings"),
    ("notification", "Notifications"),
    ("reminder", "Notifications"),
    ("shield", "Shield"),
    ("blocking", "App blocking"),
    ("review", "Review prompt"),
]


def value_of(entry: dict, lang: str) -> str | None:
    unit = (entry.get("localizations") or {}).get(lang, {}).get("stringUnit") or {}
    value = unit.get("value")
    return value if isinstance(value, str) else None


def surface_of(table: str, key: str) -> str:
    if table in ("Notifications", "Shield"):
        return table
    head = key.split(".", 1)[0].lower()
    for prefix, name in SURFACES:
        if head.startswith(prefix):
            return name
    return "Other"


def swift_sources() -> str:
    chunks = []
    for root in SOURCE_DIRS:
        if root.exists():
            chunks.extend(p.read_text(errors="ignore") for p in root.rglob("*.swift"))
    return "\n".join(chunks)


def swift_ref(key: str, sources: str) -> str:
    if f'"{key}"' in sources:
        return "literal"
    parts = key.split(".")
    for end in range(len(parts) - 1, 0, -1):
        prefix = ".".join(parts[:end])
        if f'"{prefix}.\\(' in sources or (end > 1 and f'"{prefix}"' in sources):
            return "interpolated"
    return "none"


def info_plist_rows() -> list[dict]:
    plist = plistlib.loads((APP_ROOT / "Pillie" / "Info.plist").read_bytes())
    translated: dict[str, set[str]] = {}
    for strings in (APP_ROOT / "Pillie").glob("*.lproj/InfoPlist.strings"):
        lang = strings.parent.stem
        for key in re.findall(r'^"(\w+)"\s*=', strings.read_text(), re.MULTILINE):
            translated.setdefault(key, set()).add(lang)
    out = []
    for key, english in sorted(plist.items()):
        if not key.endswith("UsageDescription"):
            continue
        present = {"en"} | translated.get(key, set())
        out.append({
            "table": "InfoPlist",
            "surface": "Permission prompts",
            "key": key,
            "en": english,
            "words": len(english.split()),
            "comment": "iOS system permission prompt",
            "locales": len(present & set(APP_LANGUAGE_CODES)),
            "missing": " ".join(l for l in APP_LANGUAGE_CODES if l not in present),
            "same_as_en": "",
            "swift_ref": "literal",
        })
    return out


def rows() -> list[dict]:
    sources = swift_sources()
    out = info_plist_rows()
    for table, path in CATALOGS.items():
        catalog = json.loads(path.read_text())
        for key, entry in sorted((catalog.get("strings") or {}).items()):
            english = value_of(entry, "en") or key
            present = [lang for lang in APP_LANGUAGE_CODES if value_of(entry, lang)]
            missing = [lang for lang in APP_LANGUAGE_CODES if lang not in present]
            same_as_en = [
                lang for lang in present
                if lang != "en" and value_of(entry, lang) == english and re.search(r"[A-Za-z]{3}", english)
            ]
            out.append({
                "table": table,
                "surface": surface_of(table, key),
                "key": key,
                "en": english,
                "words": len(english.split()),
                "comment": (entry.get("comment") or "").replace("\n", " "),
                "locales": len(present),
                "missing": " ".join(missing),
                "same_as_en": " ".join(same_as_en),
                "swift_ref": swift_ref(key, sources),
            })
    return out


def summary(data: list[dict]) -> str:
    lines = [f"{len(data)} keys, {sum(r['words'] for r in data)} English words, {len(APP_LANGUAGE_CODES)} locales"]
    by_surface = Counter(r["surface"] for r in data)
    words = Counter()
    for r in data:
        words[r["surface"]] += r["words"]
    lines.append("surface\tkeys\twords")
    lines += [f"{s}\t{n}\t{words[s]}" for s, n in by_surface.most_common()]
    incomplete = [r for r in data if r["missing"]]
    lines.append(f"keys missing a locale: {len(incomplete)}")
    refs = Counter(r["swift_ref"] for r in data)
    lines.append("swift references: " + ", ".join(f"{k} {v}" for k, v in refs.most_common()))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tsv", type=Path)
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    data = rows()
    if args.tsv:
        with args.tsv.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(data[0]), delimiter="\t")
            writer.writeheader()
            writer.writerows(data)
    if args.summary or not args.tsv:
        print(summary(data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
