#!/usr/bin/env python3
"""Insert hormone-active day wording into remaining Commerce locales.

Locked catalogs (en, de, it) stay in locked-copy.json. Latin and CJK catalogs
already name active days. This patches Indic, Arabic, Hebrew, and a few
leftover European strings, then mirrors the paywall stamp into
honest-paywall-locales.json.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
COMMERCE_PATH = REPO_ROOT / "Pillie" / "Pillie" / "Commerce.xcstrings"
HONEST_PATH = SCRIPT_DIR / "honest-paywall-locales.json"

KEYS = [
    "trial.status.indicator.active",
    "trial.status.indicator.setup",
    "paywall.story.trial_active.stamp",
    "trial.granted.badge",
    "trial.granted.disclosure",
    "trial.granted.disclosure.hard_paywall",
    "trial.end.kicker",
    "trial.end.subtitle.hard",
    "trial.end.subtitle.reminders",
    "trial.end.legacy.subtitle",
    "trial.end.legacy.record",
    "trial.end.record",
    "trial.end.hard.blocker",
    "trial.end.hard.reminders",
]

STAMP = "paywall.story.trial_active.stamp"

# If `marker` is already in the string, leave it. Otherwise replace each
# generic day noun with the pack-regimen active-day phrase.
WORD_SWAPS: dict[str, tuple[str, list[tuple[str, str]]]] = {
    "hi": ("सक्रिय", [("दिन", "सक्रिय दिन")]),
    "bn": ("সক্রিয়", [("দিন", "সক্রিয় দিন")]),
    "ur": ("فعال", [("دن", "فعال دن")]),
    "gu": ("સક્રિય", [("દિવસ", "સક્રિય દિવસ"), ("દિન", "સક્રિય દિન")]),
    "pa": ("ਸਕ੍ਰਿਯ", [("ਦਿਨ", "ਸਕ੍ਰਿਯ ਦਿਨ")]),
    "ta": ("செயல்", [
        ("நாட்களாக", "செயல் நாட்களாக"),
        ("நாட்கள்", "செயல் நாட்கள்"),
        ("14-நாள்", "14-செயல் நாள்"),
        ("நாள் Pillie Plus", "செயல் நாள் Pillie Plus"),
    ]),
    "te": ("యాక్టివ్", [
        ("రోజులు", "యాక్టివ్ రోజులు"),
        ("రోజుల", "యాక్టివ్ రోజుల"),
    ]),
    "kn": ("ಸಕ್ರಿಯ", [
        ("ರೋಜುಲು", "ಸಕ್ರಿಯ ದಿನಗಳು"),
        ("ರೋಜುಲ", "ಸಕ್ರಿಯ ದಿನಗಳ"),
        ("ದಿನಗಳು", "ಸಕ್ರಿಯ ದಿನಗಳು"),
    ]),
    "ml": ("സജീവ", [("ദിവസങ്ങൾ", "സജീവ ദിവസങ്ങൾ"), ("ദിവസം", "സജീവ ദിവസം")]),
    "mr": ("सक्रिय", [("दिवस", "सक्रिय दिवस"), ("दिन", "सक्रिय दिन")]),
    "or": ("ସକ୍ରିୟ", [("ଦିନ", "ସକ୍ରିୟ ଦିନ")]),
    "ar": ("نشط", [
        ("أيامك الـ 14", "أيامك الـ 14 النشطة"),
        ("يومًا", "يومًا نشطًا"),
        ("أيام", "أيام نشطة"),
    ]),
    "he": ("פעיל", [
        ("14 הימים שלך", "14 הימים הפעילים שלך"),
        ("ל-14 יום", "ל-14 ימים פעילים"),
        ("ימים", "ימים פעילים"),
    ]),
}

# Leftover doubled or calendar-only fragments after the first pass.
FIXUPS: dict[str, list[tuple[str, str]]] = {
    "el": [("ενεργές ηενεργές μέρες", "ενεργές μέρες")],
    "hu": [("aktiv aktív nap", "aktív nap")],
    "fi": [("14 päivän ajan", "14 aktiivisen päivän ajan")],
    "nb": [("De 14 dagene dine", "De 14 aktive dagene dine")],
}


def apply_swaps(text: str, marker: str, pairs: list[tuple[str, str]]) -> str:
    if marker in text:
        return text
    updated = text
    tokens: list[str] = []
    for index, (old, _new) in enumerate(pairs):
        token = f"\x00{index}\x00"
        tokens.append(token)
        updated = updated.replace(old, token)
    for index, (_old, new) in enumerate(pairs):
        updated = updated.replace(tokens[index], new)
    return updated


def apply_fixups(text: str, pairs: list[tuple[str, str]]) -> str:
    updated = text
    for old, new in pairs:
        updated = updated.replace(old, new)
    return updated


def set_localization(entry: dict, lang: str, value: str) -> None:
    locs = entry.setdefault("localizations", {})
    loc = locs.setdefault(lang, {})
    unit = loc.setdefault("stringUnit", {})
    unit["state"] = "translated"
    unit["value"] = value


def apply(dry_run: bool) -> int:
    catalog = json.loads(COMMERCE_PATH.read_text())
    strings = catalog.setdefault("strings", {})
    honest = json.loads(HONEST_PATH.read_text())
    errors: list[str] = []
    changed = 0
    stamp_changed = 0
    langs = sorted(set(WORD_SWAPS) | set(FIXUPS))

    for lang in langs:
        for key in KEYS:
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
            if not isinstance(current, str):
                errors.append(f"{lang} missing {key}")
                continue
            updated = current
            if lang in WORD_SWAPS:
                marker, pairs = WORD_SWAPS[lang]
                updated = apply_swaps(updated, marker, pairs)
            if lang in FIXUPS:
                updated = apply_fixups(updated, FIXUPS[lang])
            if updated != current:
                set_localization(entry, lang, updated)
                changed += 1
            if key == STAMP and honest.get(lang, {}).get(STAMP) != updated:
                honest.setdefault(lang, {})[STAMP] = updated
                stamp_changed += 1

    if errors:
        print("\n".join(errors))
        return 1
    if not dry_run:
        if changed:
            COMMERCE_PATH.write_text(
                json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
            )
        if stamp_changed:
            HONEST_PATH.write_text(
                json.dumps(honest, ensure_ascii=False, indent=2) + "\n"
            )
    action = "would update" if dry_run else "updated"
    print(f"{action} {changed} Commerce entries and {stamp_changed} honest-paywall stamps")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    return apply(parser.parse_args().dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
