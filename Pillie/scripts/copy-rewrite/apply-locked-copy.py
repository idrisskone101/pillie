#!/usr/bin/env python3
"""Apply or verify locked ENG-57 copy against Pillie string catalogs."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
CATALOGS = {
    "Localizable": REPO_ROOT / "Pillie" / "Pillie" / "Localizable.xcstrings",
    "Commerce": REPO_ROOT / "Pillie" / "Pillie" / "Commerce.xcstrings",
    "Notifications": REPO_ROOT / "Pillie" / "Pillie" / "Notifications.xcstrings",
}
PLACEHOLDERS = ("%@", "%lld", "%ld", "%d", "%%")


def load_entries() -> list[dict]:
    path = SCRIPT_DIR / "locked-copy.json"
    data = json.loads(path.read_text())
    entries = data["entries"] if isinstance(data, dict) else data
    if not isinstance(entries, list) or not entries:
        raise SystemExit(f"no entries in {path}")
    return entries


def load_catalog(table: str) -> dict:
    path = CATALOGS[table]
    return json.loads(path.read_text())


def write_catalog(table: str, data: dict) -> None:
    path = CATALOGS[table]
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


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


def placeholder_ok(expected: str, actual: str) -> bool:
    for token in PLACEHOLDERS:
        if expected.count(token) != actual.count(token):
            return False
    return True


def apply_entries(entries: list[dict]) -> int:
    catalogs = {name: load_catalog(name) for name in CATALOGS}
    changed = 0
    for item in entries:
        table = item["table"]
        key = item["key"]
        strings = catalogs[table].setdefault("strings", {})
        entry = strings.get(key)
        if entry is None:
            if not item.get("create"):
                raise SystemExit(f"missing key {table}:{key} (set create true to add it)")
            entry = {
                "comment": item.get("comment") or f"Locked copy {item.get('issue', '')}".strip(),
                "localizations": {},
            }
            strings[key] = entry
        for lang in ("en", "de", "it"):
            if lang not in item:
                continue
            current = localization_value(entry, lang)
            if current != item[lang]:
                set_localization(entry, lang, item[lang])
                changed += 1
    for name, data in catalogs.items():
        write_catalog(name, data)
    return changed


def verify_entries(entries: list[dict]) -> list[str]:
    catalogs = {name: load_catalog(name) for name in CATALOGS}
    errors: list[str] = []
    seen: set[tuple[str, str]] = set()
    for item in entries:
        table = item["table"]
        key = item["key"]
        ident = f"{table}:{key}"
        pair = (table, key)
        if pair in seen:
            errors.append(f"duplicate {ident}")
        seen.add(pair)
        entry = catalogs[table].get("strings", {}).get(key)
        if entry is None:
            errors.append(f"missing {ident}")
            continue
        for lang in ("en", "de", "it"):
            if lang not in item:
                continue
            actual = localization_value(entry, lang)
            expected = item[lang]
            if actual != expected:
                errors.append(f"{ident} {lang}: {actual!r} != {expected!r}")
            elif not placeholder_ok(expected, actual):
                errors.append(f"{ident} {lang}: placeholder mismatch")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("apply", "verify"))
    args = parser.parse_args()
    entries = load_entries()
    if args.command == "apply":
        changed = apply_entries(entries)
        errors = verify_entries(entries)
        if errors:
            sys.stderr.write("\n".join(errors) + "\n")
            return 1
        print(f"applied {len(entries)} entries; {changed} value writes")
        return 0
    errors = verify_entries(entries)
    if errors:
        sys.stderr.write("\n".join(errors) + "\n")
        print(f"verify failed: {len(errors)} mismatches")
        return 1
    print(f"verify passed: {len(entries)} entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
