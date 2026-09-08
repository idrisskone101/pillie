#!/usr/bin/env python3
"""Apply A10 Screen Time empty-state copy to every catalog locale."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
CATALOG = REPO_ROOT / "Pillie" / "Pillie" / "Localizable.xcstrings"
SOURCE = SCRIPT_DIR / "blocking-setup-a10.json"
APP_LANGUAGE = REPO_ROOT / "Pillie" / "Pillie" / "Localization" / "AppLanguagePreference.swift"

A10_KEYS = (
    "onboarding.blocking_setup.title",
    "onboarding.blocking_setup.subtitle",
    "onboarding.blocking_setup.empty_detail",
    "onboarding.blocking_setup.skip",
    "onboarding.blocking_setup.allow_pausing",
    "onboarding.blocking_setup.paused_app",
    "onboarding.blocking_setup.unlock_hint",
    "onboarding.blocking_setup.mark_taken",
)

REPL = "\ufffd"


def unit_value(entry: dict, lang: str) -> str | None:
    unit = (entry.get("localizations") or {}).get(lang, {}).get("stringUnit") or {}
    value = unit.get("value")
    return value if isinstance(value, str) else None


def set_value(entry: dict, lang: str, value: str) -> bool:
    locs = entry.setdefault("localizations", {})
    loc = locs.setdefault(lang, {})
    unit = loc.setdefault("stringUnit", {})
    if unit.get("value") == value and unit.get("state") == "translated":
        return False
    unit["state"] = "translated"
    unit["value"] = value
    return True


def shipped_catalogs() -> set[str]:
    text = APP_LANGUAGE.read_text()
    catalogs = set(re.findall(r'case \w+ = "([a-z]{2}(?:-[A-Z][A-Za-z]+)?)"', text))
    if "en" not in catalogs or len(catalogs) < 40:
        raise SystemExit(f"failed to parse AppLanguage catalogs from {APP_LANGUAGE}")
    return catalogs


def source_keys() -> dict[str, dict[str, str]]:
    data = json.loads(SOURCE.read_text())["keys"]
    mapped: dict[str, dict[str, str]] = {}
    for key in A10_KEYS:
        values = data[key]["values"]
        mapped[key] = dict(values)
        for lang, value in values.items():
            if REPL in value:
                raise SystemExit(f"{key} {lang} has a replacement character")
            if key == "onboarding.blocking_setup.unlock_hint" and value.count("%@") != 1:
                raise SystemExit(f"{key} {lang} must contain exactly one %@")
    return mapped


def apply() -> int:
    data = json.loads(CATALOG.read_text())
    strings = data.setdefault("strings", {})
    changed = 0
    for key, langs in source_keys().items():
        entry = strings.get(key)
        if entry is None:
            entry = {
                "comment": json.loads(SOURCE.read_text())["keys"][key].get("comment", ""),
                "localizations": {},
            }
            strings[key] = entry
        for lang, value in langs.items():
            if set_value(entry, lang, value):
                changed += 1
    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return changed


def verify() -> list[str]:
    data = json.loads(CATALOG.read_text())
    strings = data.get("strings") or {}
    errors: list[str] = []
    planned = source_keys()
    required = shipped_catalogs()
    for key in A10_KEYS:
        entry = strings.get(key)
        if entry is None:
            errors.append(f"missing {key}")
            continue
        present = set((entry.get("localizations") or {}).keys())
        for lang in sorted(required - present):
            errors.append(f"{key} {lang}: missing shipped catalog")
        en = unit_value(entry, "en")
        if not en:
            errors.append(f"{key} en missing")
            continue
        for lang, payload in (entry.get("localizations") or {}).items():
            value = (payload.get("stringUnit") or {}).get("value")
            if not isinstance(value, str) or not value.strip():
                errors.append(f"{key} {lang}: empty")
                continue
            if REPL in value:
                errors.append(f"{key} {lang}: replacement character")
            if lang != "en" and value == en:
                errors.append(f"{key} {lang}: still English")
            if key == "onboarding.blocking_setup.unlock_hint" and value.count("%@") != 1:
                errors.append(f"{key} {lang}: expected one %@")
        for lang, expected in planned[key].items():
            actual = unit_value(entry, lang)
            if actual != expected:
                errors.append(f"{key} {lang}: {actual!r} != {expected!r}")
    return errors


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "apply"
    if command == "apply":
        changed = apply()
        errors = verify()
        if errors:
            sys.stderr.write("\n".join(errors) + "\n")
            return 1
        print(f"applied {changed} locale writes")
        return 0
    if command == "verify":
        errors = verify()
        if errors:
            sys.stderr.write("\n".join(errors) + "\n")
            print(f"verify failed: {len(errors)} mismatches")
            return 1
        print("verify passed")
        return 0
    raise SystemExit(f"unknown command {command}")


if __name__ == "__main__":
    raise SystemExit(main())
