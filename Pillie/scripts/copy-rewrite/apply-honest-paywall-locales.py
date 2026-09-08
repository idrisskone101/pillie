#!/usr/bin/env python3
"""Write honest-paywall translations into Commerce.xcstrings.

Locked locales (en, de, it) stay with locked-copy.json. This fills every
other AppLanguage catalog from honest-paywall-locales.json.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
COMMERCE_PATH = REPO_ROOT / "Pillie" / "Pillie" / "Commerce.xcstrings"
LOCALES_PATH = SCRIPT_DIR / "honest-paywall-locales.json"
LOCKED_PATH = SCRIPT_DIR / "locked-copy.json"
LOCKED_LANGS = frozenset({"en", "de", "it"})
PLACEHOLDERS = ("%@", "%lld", "%ld", "%d", "%%")


def load_honest_keys() -> list[str]:
    data = json.loads(LOCKED_PATH.read_text())
    entries = data["entries"] if isinstance(data, dict) else data
    return [
        item["key"]
        for item in entries
        if item.get("table") == "Commerce" and item.get("issue") == "honest-paywall"
    ]


def english_for(key: str) -> str:
    data = json.loads(LOCKED_PATH.read_text())
    entries = data["entries"] if isinstance(data, dict) else data
    for item in entries:
        if item.get("key") == key and item.get("table") == "Commerce":
            return item["en"]
    raise SystemExit(f"missing English in locked-copy: {key}")


def placeholder_ok(expected: str, actual: str) -> bool:
    return all(expected.count(token) == actual.count(token) for token in PLACEHOLDERS)


def set_localization(entry: dict, lang: str, value: str) -> None:
    locs = entry.setdefault("localizations", {})
    loc = locs.setdefault(lang, {})
    unit = loc.setdefault("stringUnit", {})
    unit["state"] = "translated"
    unit["value"] = value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    keys = load_honest_keys()
    locales = json.loads(LOCALES_PATH.read_text())
    catalog = json.loads(COMMERCE_PATH.read_text())
    strings = catalog.setdefault("strings", {})
    errors: list[str] = []
    changed = 0

    for lang, translations in locales.items():
        if lang in LOCKED_LANGS:
            errors.append(f"{lang} is locked; remove it from {LOCALES_PATH.name}")
            continue
        for key in keys:
            value = translations.get(key)
            if value is None:
                errors.append(f"{lang} missing {key}")
                continue
            english = english_for(key)
            if not placeholder_ok(english, value):
                errors.append(f"{lang} {key}: placeholder mismatch {value!r}")
                continue
            entry = strings.get(key)
            if entry is None:
                errors.append(f"missing Commerce key {key}")
                continue
            current = (
                (entry.get("localizations") or {})
                .get(lang, {})
                .get("stringUnit", {})
                .get("value")
            )
            if current != value:
                set_localization(entry, lang, value)
                changed += 1

    extra_langs = set(locales) - LOCKED_LANGS
    expected_langs = {
        "ar", "bn", "ca", "cs", "da", "el", "es", "fi", "fr", "gu", "he", "hi",
        "hr", "hu", "id", "ja", "kn", "ko", "ml", "mr", "ms", "nb", "nl", "or",
        "pa", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sl", "sv", "ta", "te",
        "th", "tr", "uk", "ur", "vi", "zh-Hans", "zh-Hant",
    }
    missing_langs = sorted(expected_langs - extra_langs)
    if missing_langs:
        errors.append(f"missing languages: {', '.join(missing_langs)}")

    if errors:
        print("\n".join(errors))
        return 1
    if changed and not args.dry_run:
        COMMERCE_PATH.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
        )
    print(f"{'would update' if args.dry_run else 'updated'} {changed} locale entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
