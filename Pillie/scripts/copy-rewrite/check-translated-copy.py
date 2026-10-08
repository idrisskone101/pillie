#!/usr/bin/env python3
"""Fail if English copy that names active days is missing from a locale.

Run this after any user-facing copy change. English-only is not done.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
CATALOGS = [
    REPO_ROOT / "Pillie" / "Pillie" / "Commerce.xcstrings",
    REPO_ROOT / "Pillie" / "Pillie" / "Localizable.xcstrings",
    REPO_ROOT / "Pillie" / "Pillie" / "Notifications.xcstrings",
]

APP_LANGUAGE_CODES = [
    "ar", "bn", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr", "gu", "he",
    "hi", "hr", "hu", "id", "it", "ja", "kn", "ko", "ml", "mr", "ms", "nb", "nl",
    "or", "pa", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk", "sl", "sv", "ta", "te",
    "th", "tr", "uk", "ur", "vi", "zh-Hans", "zh-Hant",
]

# Token that must appear when English names a hormone-active day.
# Match onboarding.regimen.21_7 / the trial remaining-count keys.
ACTIVE_DAY_TOKENS: dict[str, tuple[str, ...]] = {
    "en": ("active day",),
    "de": ("aktive",),
    "it": ("attiv",),
    "fr": ("actif",),
    "es": ("activ",),
    "pt-BR": ("ativ",),
    "pt-PT": ("ativ",),
    "nl": ("actieve",),
    "ca": ("actiu",),
    "pl": ("aktywn",),
    "cs": ("aktivn",),
    "sk": ("aktívn",),
    "da": ("aktiv",),
    "sv": ("aktiv",),
    "nb": ("aktiv",),
    "fi": ("aktiiv",),
    "hr": ("aktivn",),
    "sl": ("aktivn",),
    "hu": ("aktív",),
    "ro": ("activ",),
    "el": ("ενεργ",),
    "tr": ("aktif",),
    "ru": ("активн",),
    "uk": ("активн",),
    "id": ("aktif",),
    "ms": ("aktif",),
    "ar": ("نشط",),
    "he": ("פעיל",),
    "hi": ("सक्रिय",),
    "bn": ("সক্রিয়",),
    "gu": ("સક્રિય",),
    "kn": ("ಸಕ್ರಿಯ",),
    "ml": ("സജീവ",),
    "mr": ("सक्रिय",),
    "or": ("ସକ୍ରିୟ",),
    "pa": ("ਸਰਗਰਮ",),
    "ta": ("செயல்",),
    "te": ("యాక్టివ్",),
    "ur": ("فعال",),
    "ja": ("服用",),
    "ko": ("복용",),
    "zh-Hans": ("服药",),
    "zh-Hant": ("服藥",),
    "vi": ("ngày uống",),
    "th": ("กิน",),
}

ENGLISH_NEEDLE = "active day"


def variant_values(localization: dict) -> list[str]:
    """The plain value, or every plural variant's value."""
    unit = localization.get("stringUnit") or {}
    if isinstance(unit.get("value"), str):
        return [unit["value"]]
    values: list[str] = []
    for cases in (localization.get("variations") or {}).values():
        for nested in cases.values():
            values.extend(variant_values(nested))
    return values


def localization_values(entry: dict, lang: str) -> list[str]:
    return variant_values((entry.get("localizations") or {}).get(lang) or {})


def has_token(value: str, tokens: tuple[str, ...]) -> bool:
    folded = value.casefold()
    return any(token.casefold() in folded or token in value for token in tokens)


def main() -> int:
    errors: list[str] = []
    checked = 0

    for catalog_path in CATALOGS:
        catalog = json.loads(catalog_path.read_text())
        table = catalog_path.stem
        for key, entry in (catalog.get("strings") or {}).items():
            english = localization_values(entry, "en")
            if not any(ENGLISH_NEEDLE in value.casefold() for value in english):
                continue
            checked += 1
            for lang in APP_LANGUAGE_CODES:
                if lang == "en":
                    continue
                values = localization_values(entry, lang)
                label = f"{table}:{key} [{lang}]"
                if not values:
                    errors.append(f"{label}: missing translation")
                    continue
                tokens = ACTIVE_DAY_TOKENS[lang]
                for value in values:
                    if not has_token(value, tokens):
                        errors.append(f"{label}: missing active-day wording: {value!r}")

    if errors:
        print(f"checked {checked} English active-day keys")
        print("\n".join(errors))
        return 1
    print(f"ok: {checked} English active-day keys have every locale", flush=True)
    return subprocess.run([sys.executable, str(SCRIPT_DIR / "check-script-leaks.py")]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
