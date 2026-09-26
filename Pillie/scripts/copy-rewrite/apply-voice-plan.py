#!/usr/bin/env python3
"""Apply the voice rewrite in voice-plan/ to every catalog, test, and flow.

voice-plan/<lang>.json maps "Table:key" to the new value for that locale.
Table is Localizable, Commerce, Notifications, Shield, or InfoPlist.

    python3 Pillie/scripts/copy-rewrite/apply-voice-plan.py check    # validate plans, write nothing
    python3 Pillie/scripts/copy-rewrite/apply-voice-plan.py apply    # write catalogs, locked copy, tests, flows
    python3 Pillie/scripts/copy-rewrite/apply-voice-plan.py prune    # delete keys no Swift code reads

`apply` and `prune` are safe to rerun. A second run changes nothing.
"""

from __future__ import annotations

import argparse
import unicodedata
import json
import plistlib
import re
import sys
from collections import defaultdict
from importlib import import_module
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
APP_ROOT = REPO_ROOT / "Pillie"
PLAN_DIR = SCRIPT_DIR / "voice-plan"
LOCKED_PATH = SCRIPT_DIR / "locked-copy.json"
HONEST_PATH = SCRIPT_DIR / "honest-paywall-locales.json"
LOCKED_LANGS = ("en", "de", "it")
INFO_PLIST = APP_ROOT / "Pillie" / "Info.plist"
CATALOG_FILES = {
    "Localizable": [APP_ROOT / "Pillie" / "Localizable.xcstrings"],
    "Commerce": [APP_ROOT / "Pillie" / "Commerce.xcstrings"],
    "Notifications": [APP_ROOT / "Pillie" / "Notifications.xcstrings"],
    "Shield": [
        APP_ROOT / "PillieShieldConfiguration" / "Shield.xcstrings",
        APP_ROOT / "PillieDeviceActivityMonitor" / "Shield.xcstrings",
    ],
}
LITERAL_GLOBS = [
    (APP_ROOT / "PillieTests", "*.swift"),
    (REPO_ROOT / ".agents" / "skills" / "verify-pillie" / "flows", "*.flow"),
    (REPO_ROOT / ".agents" / "skills" / "verify-pillie" / "features", "*.md"),
]
SCRIPTS = {
    "hi": "DEVANAGARI", "mr": "DEVANAGARI", "bn": "BENGALI", "gu": "GUJARATI", "pa": "GURMUKHI",
    "or": "ORIYA", "ta": "TAMIL", "te": "TELUGU", "kn": "KANNADA", "ml": "MALAYALAM",
    "ar": "ARABIC", "ur": "ARABIC", "he": "HEBREW", "th": "THAI", "el": "GREEK",
    "ru": "CYRILLIC", "uk": "CYRILLIC",
}
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(?:lld|ld|d|@|%)")

sys.path.insert(0, str(SCRIPT_DIR))
inventory = import_module("copy-inventory")
lint = import_module("copy-voice-lint")
APP_LANGUAGE_CODES = inventory.APP_LANGUAGE_CODES


def read_json(path: Path) -> dict:
    return json.loads(path.read_text())


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def load_plans() -> dict[str, dict[str, str]]:
    plans = {path.stem: read_json(path) for path in sorted(PLAN_DIR.glob("*.json"))}
    unknown = sorted(set(plans) - set(APP_LANGUAGE_CODES))
    if unknown:
        raise SystemExit(f"plan files for unknown locales: {unknown}")
    return plans


class Catalogs:
    def __init__(self) -> None:
        self.data = {table: read_json(paths[0]) for table, paths in CATALOG_FILES.items()}
        self.info_plist_text = INFO_PLIST.read_text()
        self.info_plist = plistlib.loads(self.info_plist_text.encode())
        self.info_strings = {
            path.parent.stem: path.read_text()
            for path in (APP_ROOT / "Pillie").glob("*.lproj/InfoPlist.strings")
        }

    def keys(self) -> set[str]:
        refs = {f"{t}:{k}" for t, d in self.data.items() for k in d["strings"]}
        return refs | {f"InfoPlist:{k}" for k in self.info_plist if k.endswith("UsageDescription")}

    def get(self, ref: str, lang: str) -> str | None:
        table, key = ref.split(":", 1)
        if table == "InfoPlist":
            if lang == "en":
                return self.info_plist.get(key)
            match = re.search(rf'^"{key}"\s*=\s*"((?:[^"\\]|\\.)*)";', self.info_strings.get(lang, ""), re.M)
            return match and match.group(1).replace('\\"', '"')
        entry = self.data[table]["strings"].get(key) or {}
        return inventory.value_of(entry, lang)

    def set(self, ref: str, lang: str, value: str) -> None:
        table, key = ref.split(":", 1)
        if table == "InfoPlist":
            if lang == "en":
                self.info_plist[key] = value
                escaped = value.replace("&", "&amp;").replace("<", "&lt;")
                self.info_plist_text = re.sub(
                    rf"(<key>{key}</key>\s*<string>).*?(</string>)",
                    lambda m: m.group(1) + escaped + m.group(2),
                    self.info_plist_text,
                    flags=re.S,
                )
                return
            escaped = value.replace("\\", "\\\\").replace('"', '\\"')
            self.info_strings[lang] = re.sub(
                rf'^"{key}"\s*=\s*".*";$',
                lambda _: f'"{key}" = "{escaped}";',
                self.info_strings[lang],
                flags=re.M,
            )
            return
        unit = self.data[table]["strings"][key].setdefault("localizations", {}).setdefault(lang, {})
        unit["stringUnit"] = {"state": "translated", "value": value}

    def delete(self, ref: str) -> None:
        table, key = ref.split(":", 1)
        self.data[table]["strings"].pop(key, None)

    def save(self) -> None:
        for table, paths in CATALOG_FILES.items():
            for path in paths:
                write_json(path, self.data[table])
        INFO_PLIST.write_text(self.info_plist_text)
        for lang, text in self.info_strings.items():
            (APP_ROOT / "Pillie" / f"{lang}.lproj" / "InfoPlist.strings").write_text(text)


def foreign_script(lang: str, value: str) -> str | None:
    """Name a non-Latin script that doesn't belong to this locale, e.g. Telugu letters in Kannada."""
    own = SCRIPTS.get(lang)
    for char in value:
        block = unicodedata.name(char, "").split(" ")[0] if char.isalpha() else ""
        if block in SCRIPTS.values() and block != own:
            return block
    return None


def is_all_caps(value: str) -> bool:
    letters = [c for c in PLACEHOLDER.sub("", value) if c.isalpha() and c.lower() != c.upper()]
    return len(letters) >= 3 and all(c.isupper() for c in letters)


def placeholders(value: str) -> list[str]:
    """Argument types in argument order, so `%2$@ %1$lld` reads as ["lld", "@"]."""
    args, literal_percents, position = {}, 0, 0
    for match in PLACEHOLDER.finditer(value):
        token = match.group(0)
        if token == "%%":
            literal_percents += 1
            continue
        index = re.match(r"%(\d+)\$", token)
        position = int(index.group(1)) if index else position + 1
        args[position] = re.sub(r"^%(\d+\$)?", "", token)
    return [args[i] for i in sorted(args)] + ["%"] * literal_percents


def check(plans: dict[str, dict[str, str]], catalogs: Catalogs) -> list[str]:
    errors = []
    known = catalogs.keys()
    english = {ref: plans.get("en", {}).get(ref) or catalogs.get(ref, "en") or "" for ref in known}
    live = {f"{r['table']}:{r['key']}" for r in inventory.rows() if r["swift_ref"] != "none"}
    for lang, plan in plans.items():
        if lang != "en":
            errors += [f"{lang} {ref}: missing from plan" for ref in sorted(live - set(plan))]
        for ref, value in plan.items():
            if ref not in known:
                errors.append(f"{lang} {ref}: no such key")
                continue
            if placeholders(value) != placeholders(english[ref]):
                errors.append(f"{lang} {ref}: placeholders {placeholders(value)} != English {placeholders(english[ref])}")
            if "—" in value:
                errors.append(f"{lang} {ref}: em dash")
            if lang != "en" and (block := foreign_script(lang, value)):
                errors.append(f"{lang} {ref}: {block} letters in a {lang} string")
            if is_all_caps(value) and not is_all_caps(english[ref]):
                errors.append(f"{lang} {ref}: all caps, let SwiftUI uppercase it")
            if lang == "en":
                errors += [f"en {ref}: {hit}" for hit in lint.findings(value)]
    return errors


def swift_literal(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def rewrite_literals(changes: list[tuple[str, str, str, str]], catalogs: Catalogs) -> list[str]:
    """Swap pinned old values for new ones in tests and flows, when the swap is unambiguous."""
    targets: dict[str, set[str]] = defaultdict(set)
    for _lang, _ref, old, new in changes:
        targets[old].add(new)
    kept = {
        catalogs.get(ref, lang)
        for ref in catalogs.keys()
        for lang in APP_LANGUAGE_CODES
    }
    notes = []
    files = [p for root, pattern in LITERAL_GLOBS for p in root.glob(pattern)]
    for path in files:
        text = path.read_text()
        original = text
        for old, news in targets.items():
            literal = swift_literal(old)
            if literal not in text:
                continue
            if len(news) > 1 or old in kept:
                notes.append(f"{path.relative_to(REPO_ROOT)}: {literal} is ambiguous, fix by hand")
                continue
            text = text.replace(literal, swift_literal(next(iter(news))))
        if text != original:
            path.write_text(text)
            notes.append(f"{path.relative_to(REPO_ROOT)}: rewrote pinned copy")
    return notes


def sync_locked(plans: dict[str, dict[str, str]]) -> None:
    locked = read_json(LOCKED_PATH)
    for item in locked["entries"]:
        ref = f"{item['table']}:{item['key']}"
        for lang in LOCKED_LANGS:
            if ref in plans.get(lang, {}):
                item[lang] = plans[lang][ref]
    write_json(LOCKED_PATH, locked)
    honest = read_json(HONEST_PATH)
    for lang, table in honest.items():
        for key in table:
            ref = f"Commerce:{key}"
            if ref in plans.get(lang, {}):
                table[key] = plans[lang][ref]
    write_json(HONEST_PATH, honest)


def apply(plans: dict[str, dict[str, str]], catalogs: Catalogs) -> None:
    changes = []
    for lang, plan in plans.items():
        for ref, value in plan.items():
            old = catalogs.get(ref, lang)
            if old != value:
                changes.append((lang, ref, old, value))
                catalogs.set(ref, lang, value)
    catalogs.save()
    sync_locked(plans)
    for note in rewrite_literals([c for c in changes if c[2]], catalogs):
        print(note)
    print(f"applied {len(changes)} values across {len(plans)} locales")


def prune(catalogs: Catalogs) -> None:
    dead = [f"{r['table']}:{r['key']}" for r in inventory.rows() if r["swift_ref"] == "none"]
    for ref in dead:
        catalogs.delete(ref)
    catalogs.save()
    dead_keys = {tuple(ref.split(":", 1)) for ref in dead}
    locked = read_json(LOCKED_PATH)
    live = catalogs.keys()
    locked["entries"] = [e for e in locked["entries"] if f"{e['table']}:{e['key']}" in live]
    write_json(LOCKED_PATH, locked)
    honest = read_json(HONEST_PATH)
    for table in honest.values():
        for table_name, key in dead_keys:
            if table_name == "Commerce":
                table.pop(key, None)
    write_json(HONEST_PATH, honest)
    print(f"pruned {len(dead)} keys no Swift code reads")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["check", "apply", "prune"])
    parser.add_argument("--only", help="comma-separated locales to load, plus en")
    args = parser.parse_args()
    catalogs = Catalogs()
    if args.command == "prune":
        prune(catalogs)
        return 0
    plans = load_plans()
    if args.only:
        keep = {"en", *args.only.split(",")}
        plans = {lang: plan for lang, plan in plans.items() if lang in keep}
    errors = check(plans, catalogs)
    if errors:
        print("\n".join(errors))
        return 1
    if args.command == "apply":
        apply(plans, catalogs)
    else:
        print(f"ok: {sum(len(p) for p in plans.values())} values in {len(plans)} locales")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
