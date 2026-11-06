#!/usr/bin/env python3
"""Bring the classic paywall's Commerce copy back from 2c8062a.

The paywall_design_v1 test (PostHog flag `paywall-design`) shows the paywall
main had before PR #383 as its `classic` arm. Each Commerce key that design
read is reused when today's catalog still holds it with the same value in
every locale. Otherwise it is added as `paywall.classic.<old key>` with the
old values, and mirrored into locked-copy.json (en, de, it) and
honest-paywall-locales.json (every other locale).

Prints the reused and added keys as JSON. Safe to rerun.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
COMMERCE_REL = "Pillie/Pillie/Commerce.xcstrings"
COMMERCE_PATH = REPO_ROOT / COMMERCE_REL
LOCKED_PATH = SCRIPT_DIR / "locked-copy.json"
LOCALES_PATH = SCRIPT_DIR / "honest-paywall-locales.json"
SOURCE_REF = "2c8062a"
PREFIX = "paywall.classic."
LOCKED_LANGS = ("en", "de", "it")
APP_LANGUAGE_CODES = (
    "ar", "bn", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr", "gu", "he",
    "hi", "hr", "hu", "id", "it", "ja", "kn", "ko", "ml", "mr", "ms", "nb", "nl",
    "or", "pa", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sl", "sv", "ta", "te",
    "th", "tr", "uk", "ur", "vi", "zh-Hans", "zh-Hant",
)

CLASSIC_KEYS = (
    "paywall.story.trial_active.title",
    "paywall.story.trial_active.subtitle",
    "paywall.story.trial_active.stamp",
    "paywall.story.trial_active.chip.reminders",
    "paywall.story.trial_active.chip.blocking",
    "paywall.story.trial_active.chip.history",
    "paywall.story.trial_ended.title",
    "paywall.story.trial_ended.subtitle",
    "paywall.story.trial_ended.aside",
    "paywall.story.trial_ended.tile.doses",
    "paywall.story.trial_ended.tile.streak",
    "paywall.story.trial_ended.returning.legacy.title",
    "paywall.story.trial_ended.returning.legacy.subtitle",
    "paywall.story.trial_ended.returning.hard.title",
    "paywall.story.trial_ended.returning.hard.subtitle",
    "paywall.story.trial_ended.returning.hard.aside",
    "paywall.story.trial_ended.returning.hard.chip.blocking",
    "paywall.story.trial_ended.returning.hard.chip.reminders",
    "paywall.story.trial_ended.returning.hard.chip.history",
    "paywall.story.settings_free.title",
    "paywall.story.settings_free.subtitle",
    "paywall.story.settings_free.plus_label",
    "paywall.feature.daily_reminders",
    "paywall.feature.smart_reminders",
    "paywall.feature.app_blocking.compact",
    "paywall.stack.save_badge",
    "paywall.stack.monthly_equivalent",
    "paywall.stack.year.title",
    "paywall.stack.year.primary_line",
    "paywall.stack.month.title",
    "paywall.stack.month.primary_line",
    "paywall.stack.lifetime.title",
    "paywall.stack.lifetime.primary_line",
    "paywall.stack.footer.cancel_anytime",
    "paywall.stack.footer.one_payment",
    "paywall.action.restore",
    "paywall.cta.keep_plus.billed_yearly",
    "paywall.cta.keep_plus.billed_monthly",
    "paywall.cta.keep_plus.once",
    "paywall.cta.get_plus.billed_yearly",
    "paywall.cta.get_plus.billed_monthly",
    "paywall.cta.get_plus.once",
    "trial.end.continue_free",
)


def localization_value(entry: dict, lang: str) -> str | dict[str, str] | None:
    loc = (entry.get("localizations") or {}).get(lang) or {}
    value = (loc.get("stringUnit") or {}).get("value")
    if isinstance(value, str):
        return value
    plural = (loc.get("variations") or {}).get("plural")
    if plural:
        return {case: nested["stringUnit"]["value"] for case, nested in plural.items()}
    return None


def same_everywhere(old: dict, current: dict | None) -> bool:
    if current is None:
        return False
    return all(
        localization_value(old, lang) == localization_value(current, lang)
        for lang in APP_LANGUAGE_CODES
    )


def old_catalog() -> dict:
    shown = subprocess.run(
        ["git", "show", f"{SOURCE_REF}:{COMMERCE_REL}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(shown.stdout)


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    old_strings = old_catalog()["strings"]
    catalog = json.loads(COMMERCE_PATH.read_text())
    strings = catalog["strings"]
    locked = json.loads(LOCKED_PATH.read_text())
    locales = json.loads(LOCALES_PATH.read_text())

    reused: list[str] = []
    added: list[str] = []
    errors: list[str] = []

    for key in CLASSIC_KEYS:
        old = old_strings.get(key)
        if old is None:
            errors.append(f"{SOURCE_REF} has no Commerce key {key}")
            continue
        missing = [lang for lang in APP_LANGUAGE_CODES if localization_value(old, lang) is None]
        if missing:
            errors.append(f"{key} has no {SOURCE_REF} value for {', '.join(missing)}")
            continue
        if same_everywhere(old, strings.get(key)):
            reused.append(key)
            continue

        new_key = PREFIX + key
        added.append(new_key)
        comment = old.get("comment") or ""
        strings[new_key] = {
            "comment": f"{comment} [paywall_design_v1 classic arm]".strip(),
            "localizations": {
                lang: old["localizations"][lang] for lang in APP_LANGUAGE_CODES
            },
        }

        entry = {
            "issue": "honest-paywall",
            "table": "Commerce",
            "key": new_key,
            "create": True,
            "comment": strings[new_key]["comment"],
        }
        entry.update({lang: localization_value(old, lang) for lang in LOCKED_LANGS})
        locked["entries"] = [
            item for item in locked["entries"]
            if not (item.get("table") == "Commerce" and item.get("key") == new_key)
        ] + [entry]

        for lang, translations in locales.items():
            translations[new_key] = localization_value(old, lang)

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    if not args.dry_run:
        write_json(COMMERCE_PATH, catalog)
        write_json(LOCKED_PATH, locked)
        write_json(LOCALES_PATH, locales)

    print(json.dumps({"reused": reused, "added": added}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
