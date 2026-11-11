#!/usr/bin/env python3
"""Fail if English copy that names active days is missing from a locale.

Also fail if calendar-day Reverse Trial copy names active days (ENG-242).
Only the `.active_days` variants, shown to installs from before ENG-242,
may say "active days".

Run this after any user-facing copy change. English-only is not done.
"""

from __future__ import annotations

import json
import re
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
    "ar", "bn", "ca", "cs", "da", "de", "el", "en", "es", "fi", "fr", "gu",
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

# Trial copy for an install that still counts hormone-active days (ENG-242).
ACTIVE_DAY_VARIANT_SUFFIX = ".active_days"

# A day noun next to an active-day adjective, per locale. Stems alone would
# also match "Plus is active" and "take your pill" in trial copy.
TRIAL_ACTIVE_DAY_PATTERNS: dict[str, str] = {
    "en": r"active[ -]days?",
    "de": r"aktive[nrs]? Tag",
    "it": r"giorn[oi] attiv",
    "fr": r"jours? actif",
    "es": r"días? activo",
    "pt-BR": r"dias? ativo",
    "pt-PT": r"dias? ativo",
    "ca": r"(dies|dia) actiu",
    "nl": r"actieve dag",
    "sv": r"aktiva? dag",
    "da": r"aktive? dag",
    "nb": r"aktive? dag",
    "fi": r"aktiivi\w* päiv",
    "pl": r"(dni|dzień|dnia) aktywn|aktywn\w* (dni|dzień|dnia)",
    "cs": r"aktivn\w* (dn|den)",
    "sk": r"aktívn\w* (dn|deň)",
    "hr": r"aktivn\w* dan",
    "sl": r"aktivn\w* (dn|dan)",
    "ru": r"активн\w* (дн|день)",
    "uk": r"активн\w* (дн|день)",
    "hu": r"aktív nap",
    "ro": r"(zile|zi) activ",
    "el": r"ενεργ\w* (ημέρ|μέρ)",
    "tr": r"aktif gün",
    "id": r"hari aktif",
    "ms": r"hari aktif",
    "vi": r"ngày uống",
    "th": r"วันกินยา",
    "ja": r"服用\s*(%lld|\d)|服用日",
    "ko": r"복용\s*(%lld|\d)|복용일",
    "zh-Hans": r"服药日",
    "zh-Hant": r"服藥日",
    "hi": r"सक्रिय दि",
    "mr": r"सक्रिय दि",
    "bn": r"সক্রিয় দিন",
    "ur": r"فعال دن",
    "gu": r"સક્રિય દિવસ",
    "pa": r"ਸਰਗਰਮ ਦਿਨ",
    "kn": r"ಸಕ್ರಿಯ ದಿನ",
    "ml": r"സജീവ ദി",
    "or": r"ସକ୍ରିୟ ଦିନ",
    "te": r"యాక్టివ్ రోజ",
    "ta": r"செயல் நா",
    "ar": r"(يوم|أيام)\w*[\u064B-\u0652]* (ال)?نشط",
}


def localization_value(entry: dict, lang: str) -> str | None:
    """The plain value, or a plural entry's "other" form. copy-inventory.py imports it."""
    localization = (entry.get("localizations") or {}).get(lang) or {}
    plural = (localization.get("variations") or {}).get("plural") or {}
    unit = localization.get("stringUnit") or (plural.get("other") or {}).get("stringUnit") or {}
    value = unit.get("value")
    return value if isinstance(value, str) else None


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

    trial_checked = 0
    for catalog_path in CATALOGS:
        catalog = json.loads(catalog_path.read_text())
        table = catalog_path.stem
        for key, entry in (catalog.get("strings") or {}).items():
            if "trial" not in key or key.endswith(ACTIVE_DAY_VARIANT_SUFFIX):
                continue
            trial_checked += 1
            for lang in APP_LANGUAGE_CODES:
                for value in localization_values(entry, lang):
                    if re.search(TRIAL_ACTIVE_DAY_PATTERNS[lang], value, re.IGNORECASE):
                        errors.append(
                            f"{table}:{key} [{lang}]: trial copy names active days, "
                            f"calendar-day installs count 14 calendar days: {value!r}"
                        )

    if errors:
        print(f"checked {checked} English active-day keys and {trial_checked} trial keys")
        print("\n".join(errors))
        return 1
    print(f"ok: {checked} English active-day keys have every locale", flush=True)
    print(f"ok: {trial_checked} trial keys count calendar days", flush=True)
    return subprocess.run([sys.executable, str(SCRIPT_DIR / "check-script-leaks.py")]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
