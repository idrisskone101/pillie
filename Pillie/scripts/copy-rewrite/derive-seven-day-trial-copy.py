#!/usr/bin/env python3
"""Write the trial_length_v1 `.seven_days` copy from the 14-day copy.

A 7-day install must never read "14". Each `.seven_days` key starts from the
calendar-day (14) string in every AppLanguage catalog, swaps the number, then
applies the hand-checked grammar fixes in FIXES. It writes Commerce.xcstrings
and keeps locked-copy.json (en/de/it) and honest-paywall-locales.json in sync.

    python3 Pillie/scripts/copy-rewrite/derive-seven-day-trial-copy.py          # write
    python3 Pillie/scripts/copy-rewrite/derive-seven-day-trial-copy.py --check  # verify

Rerun it after editing any of the 14-day strings below.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
COMMERCE_PATH = REPO_ROOT / "Pillie" / "Pillie" / "Commerce.xcstrings"
LOCKED_PATH = SCRIPT_DIR / "locked-copy.json"
HONEST_PATH = SCRIPT_DIR / "honest-paywall-locales.json"
SUFFIX = ".seven_days"
ISSUE = "trial_length_v1"
LOCKED_LANGS = ("en", "de", "it")

# Base key -> {old number: new number}. The timeline labels name the last day
# (14 -> 7) and the heads-up two days before it (12 -> 5).
KEYS: dict[str, dict[str, str]] = {
    "trial.granted.badge": {"14": "7"},
    "trial.granted.headline": {"14": "7"},
    "trial.granted.disclosure": {"14": "7"},
    "trial.granted.disclosure.hard_paywall": {"14": "7"},
    "trial.granted.choice.label": {"14": "7"},
    "trial.granted.warning.label": {"12": "5"},
    "trial.end.kicker": {"14": "7"},
    "trial.end.hard.blocker": {"14": "7"},
    "trial.end.hard.reminders": {"14": "7"},
    "trial.end.legacy.subtitle": {"14": "7"},
    "trial.end.legacy.record": {"14": "7"},
    "paywall.board.during_trial.subtitle": {"14": "7"},
}

# Grammar the number swap breaks, per locale: (after swap, fixed).
FIXES: dict[str, list[tuple[str, str]]] = {
    # 11-99 take the singular accusative (14 يومًا); 3-10 take the plural (7 أيام).
    "ar": [("7 يومًا", "7 أيام")],
    # Numeric ordinals: 14তম but 7ম (সপ্তম).
    "bn": [("7তম", "7ম")],
    # Numeric ordinals: 14ତମ but 7ମ (ସପ୍ତମ).
    "or": [("7ତମ", "7ମ")],
}

COMMENT_NOTE = "7-day install (trial_length_v1): the trial runs 7 calendar days."


def swap(text: str, numbers: dict[str, str], lang: str) -> str:
    for old, new in numbers.items():
        text = re.sub(rf"(?<!\d){old}(?!\d)", new, text)
    for wrong, right in FIXES.get(lang, []):
        text = text.replace(wrong, right)
    return text


def derive_localization(localization: dict, numbers: dict[str, str], lang: str) -> dict:
    """Same shape (plain or plural) with every value derived."""
    if "stringUnit" in localization:
        return {"stringUnit": {"state": "translated", "value": swap(localization["stringUnit"]["value"], numbers, lang)}}
    plural = localization["variations"]["plural"]
    return {
        "variations": {
            "plural": {
                case: {"stringUnit": {"state": "translated", "value": swap(unit["stringUnit"]["value"], numbers, lang)}}
                for case, unit in plural.items()
            }
        }
    }


def plain(localization: dict) -> str | dict[str, str]:
    if "stringUnit" in localization:
        return localization["stringUnit"]["value"]
    return {case: unit["stringUnit"]["value"] for case, unit in localization["variations"]["plural"].items()}


def insert_after(mapping: dict, anchor: str, key: str, value) -> dict:
    items = [(k, v) for k, v in mapping.items() if k != key]
    index = next(i for i, (k, _) in enumerate(items) if k == anchor) + 1
    items.insert(index, (key, value))
    return dict(items)


def anchor_for(keys, base: str) -> str:
    active = base + ".active_days"
    return active if active in keys else base


def derive_catalog(catalog: dict) -> dict:
    strings = catalog["strings"]
    for base, numbers in KEYS.items():
        source = strings[base]
        entry = {
            "comment": f"{swap(source.get('comment', ''), numbers, '').strip()} {COMMENT_NOTE}".strip(),
            "localizations": {
                lang: derive_localization(localization, numbers, lang)
                for lang, localization in sorted(source["localizations"].items())
            },
        }
        strings = insert_after(strings, anchor_for(strings, base), base + SUFFIX, entry)
    catalog["strings"] = strings
    return catalog


def derive_locked(locked: dict, strings: dict) -> dict:
    entries = [item for item in locked["entries"] if not item["key"].endswith(SUFFIX)]
    for base in KEYS:
        base_item = next((item for item in entries if item["key"] == base and item["table"] == "Commerce"), None)
        if base_item is None:
            continue
        item = {
            "issue": ISSUE,
            "table": "Commerce",
            "key": base + SUFFIX,
            "create": True,
            "comment": f"7-day install: {swap(base_item.get('comment', ''), KEYS[base], '')}".strip(),
        }
        for lang in LOCKED_LANGS:
            item[lang] = plain(strings[base + SUFFIX]["localizations"][lang])
        anchor = anchor_for({e["key"] for e in entries}, base)
        index = next(i for i, e in enumerate(entries) if e["key"] == anchor) + 1
        entries.insert(index, item)
    locked["entries"] = entries
    return locked


def derive_honest(honest: dict, strings: dict) -> dict:
    for lang, translations in honest.items():
        for base in KEYS:
            if base not in translations:
                continue
            value = plain(strings[base + SUFFIX]["localizations"][lang])
            honest[lang] = translations = insert_after(
                translations, anchor_for(translations, base), base + SUFFIX, value
            )
    return honest


def render(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="fail if any file differs from the derivation")
    args = parser.parse_args()

    catalog = derive_catalog(json.loads(COMMERCE_PATH.read_text()))
    strings = catalog["strings"]
    outputs = {
        COMMERCE_PATH: render(catalog),
        LOCKED_PATH: render(derive_locked(json.loads(LOCKED_PATH.read_text()), strings)),
        HONEST_PATH: render(derive_honest(json.loads(HONEST_PATH.read_text()), strings)),
    }

    stale = [path for path, text in outputs.items() if path.read_text() != text]
    if args.check:
        for path in stale:
            print(f"stale: {path.relative_to(REPO_ROOT)}")
        if stale:
            return 1
        print(f"ok: {len(KEYS)} .seven_days keys match their 14-day source")
        return 0
    for path in stale:
        path.write_text(outputs[path])
        print(f"wrote {path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
