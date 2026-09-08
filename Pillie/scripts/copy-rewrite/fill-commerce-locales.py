#!/usr/bin/env python3
"""Copy English Commerce strings into non-locked AppLanguage locales for listed keys."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
COMMERCE_PATH = REPO_ROOT / "Pillie" / "Pillie" / "Commerce.xcstrings"
LOCKED_PATH = SCRIPT_DIR / "locked-copy.json"

LOCKED_LANGS = frozenset({"en", "de", "it"})

# AppLanguage catalog identifiers except system.
APP_LANGUAGE_CODES = [
    "ar", "bn", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr", "gu", "he",
    "hi", "hr", "hu", "id", "it", "ja", "kn", "ko", "ml", "mr", "ms", "nb", "nl",
    "or", "pa", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sl", "sv", "ta", "te",
    "th", "tr", "uk", "ur", "vi", "zh-Hans", "zh-Hant",
]

FILL_LANGS = [code for code in APP_LANGUAGE_CODES if code not in LOCKED_LANGS]


def load_honest_paywall_keys() -> list[str]:
    data = json.loads(LOCKED_PATH.read_text())
    entries = data["entries"] if isinstance(data, dict) else data
    keys: list[str] = []
    for item in entries:
        if item.get("table") != "Commerce":
            continue
        if item.get("issue") != "honest-paywall":
            continue
        keys.append(item["key"])
    if not keys:
        raise SystemExit("no honest-paywall Commerce keys in locked-copy.json")
    return keys


def localization_value(entry: dict, lang: str) -> str | None:
    unit = (entry.get("localizations") or {}).get(lang, {}).get("stringUnit") or {}
    value = unit.get("value")
    return value if isinstance(value, str) else None


def set_localization(entry: dict, lang: str, value: str) -> None:
    locs = entry.setdefault("localizations", {})
    loc = locs.setdefault(lang, {})
    unit = loc.setdefault("stringUnit", {})
    unit["state"] = "translated"
    unit["value"] = value


def fill_catalog(keys: list[str], dry_run: bool) -> int:
    catalog = json.loads(COMMERCE_PATH.read_text())
    strings = catalog.setdefault("strings", {})
    changed = 0

    for key in keys:
        entry = strings.get(key)
        if entry is None:
            print(f"missing key in Commerce.xcstrings: {key}", file=sys.stderr)
            continue
        english = localization_value(entry, "en")
        if english is None:
            print(f"missing English for {key}", file=sys.stderr)
            continue
        for lang in FILL_LANGS:
            current = localization_value(entry, lang)
            if current == english:
                continue
            set_localization(entry, lang, english)
            changed += 1

    if changed and not dry_run:
        COMMERCE_PATH.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
        )
    return changed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    keys = load_honest_paywall_keys()
    changed = fill_catalog(keys, dry_run=args.dry_run)
    action = "would update" if args.dry_run else "updated"
    print(f"{action} {changed} locale entries across {len(keys)} keys")


if __name__ == "__main__":
    main()
