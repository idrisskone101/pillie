#!/usr/bin/env python3
"""Fail if a locale holds a sibling language written in its script.

Kannada and Telugu share a parallel Unicode layout, as do Gurmukhi, Gujarati,
and Devanagari, so a bad translation pass can emit Telugu in Kannada letters or
Hindi in Gurmukhi or Gujarati letters. Marathi shares Devanagari with Hindi, so
there the leak is Hindi words and grammar. check-translated-copy.py cannot see
any of that.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
CATALOGS = sorted((REPO_ROOT / "Pillie").glob("*/*.xcstrings"))

KN = "\u0C80-\u0CFF"
PA = "\u0A00-\u0A7F"
GU = "\u0A80-\u0AFF"
MR = "\u0900-\u097F"


def word(script: str, text: str) -> str:
    return rf"(?<![{script}]){text}(?![{script}])"


# Telugu morphology that Kannada does not use.
KN_TELUGU = re.compile("|".join([
    "ಡಾನಿಕಿ", "ನುಂಚಿ", "ಲೇದು", "ಕಾವಾಲಿ", "ಮಳ್ಲೀ", "ರೋಜು", rf"[ುಿ]ಂದಿ(?![{KN}])", "ವಚ್ಚು",
    "ಉನ್ನಾ", "ಉಂಟ", "ಚೇಯ", "ಚೇಸ", "ಚೂಡು", "ಚೂಸ", "ಿಂಚು", "ಿಂಚಿ", "ಿಂಚಡ",
    "ಪ್ಪುಡು", "ತರ್ವಾತ", "ನೀಕು", "ಮಾಕು", "ನಾಕು",
    word(KN, "ಒಕ"), word(KN, "ಏದಿ"), word(KN, "ಏಮಿ"), word(KN, "ಉಂದಿ"),
    rf"[{KN}]ಲೋ(?![{KN}-])",
    # Telugu nouns end in -ಂ (ಸಮಯಂ); Kannada nouns end in a vowel (ಸಮಯ).
    rf"[\u0C95-\u0CB9][\u0CBE-\u0CCC]?\u0C82(?![{KN}])",
]))

# Hindi words and Devanagari spelling that Punjabi does not use.
PA_HINDI = re.compile("|".join([
    "ਅਪਨ", "ਸਮਯ", "ਰਹਤ", "ਸਕਤ", "ਕਰਤ", "ਗਯਾ", "ਲਿਯਾ", "ਨਯਾ", "ਹੁਏ",
    "ਸਬਸੇ", "ਇਸਸੇ", "ਕਿਸਸੇ",
    *(word(PA, w) for w in ["ਏਕ", "ਸੇ", "ਕੋ", "ਭੀ", "ਅਭੀ", "ਕਭੀ", "ਯਾ", "ਯਹ", "ਵਹ", "ਤਬ", "ਜਬ", "ਕਾਮ"]),
    # Devanagari candrabindu, mapped one-to-one into Gurmukhi.
    "\u0A01",
    # Bindi after a short vowel or bare consonant, where Gurmukhi writes tippi.
    "[\u0A05\u0A07\u0A3F\u0A41\u0A15-\u0A39]\u0A02",
    # A virama conjunct other than pairin ra, ha, or va.
    "\u0A4D(?![\u0A30\u0A39\u0A35])",
]))

# Hindi words and Devanagari habits that Gujarati does not use.
GU_HINDI = re.compile("|".join([
    # Nukta and danda: Gujarati writes neither (ફ not ફ઼, a full stop not ।).
    "\u0ABC", "\u0964",
    # Hindi nasal plural and subjunctive endings (દિનોં, રુકેં).
    rf"[\u0ACB\u0AC7]\u0A82(?![{GU}])",
    "રહત", "સકત", "ચાહત", "ચાહિ", "કરને", "કરના", "હોને", "હોના", "હોત", "જાતા", "જાતી",
    *(word(GU, w) for w in [
        "મેં", "સે", "કા", "કી", "કો", "કિ", "યા", "ફિર", "અગર", "હર", "દિન", "ભી",
        "ઔર", "લેકિન", "અભી", "કભી", "ક્યા", "યહ", "વહ", "ઇસ", "ઉસ", "હૈ", "હુએ", "હુઆ",
        "હુઈ", "કિએ", "ગએ", "દો", "રખો", "ચુનો", "બંદ", "છોટા", "છોટી", "છોટે", "રુક",
        "પહલે", "ચાલૂ", "શુરૂ", "લગાઓ", "મૈનેજ", "કમ", "તક", "લિએ", "મિલા", "શામિલ",
        "લિખો", "દિખાતા", "કૈસા", "ટૈપ",
    ]),
]))

# Hindi words and grammar that Marathi does not use. Marathi is written in
# Devanagari too, so only the vocabulary gives a leak away.
MR_HINDI = re.compile("|".join([
    # Nukta and danda: Marathi writes neither.
    "\u093C", "\u0964",
    # Hindi future and subjunctive endings (चलेगा, थांबलें).
    rf"\u0947(?:गा|गी|ंगे)(?![{MR}])", rf"\u0947\u0902(?![{MR}])",
    "रहत", "सकत", "चाहत", "चाहि", "करने", "करना", "होने", "होना",
    *(word(MR, w) for w in [
        "है", "हैं", "में", "के", "से", "को", "भी", "और", "लेकिन", "अगर", "हर", "पर",
        "कि", "यह", "वह", "इस", "दिन", "दिनों", "कुछ", "कभी", "अभी", "कोई", "रहा", "रही",
        "हुआ", "हुए", "हुई", "गया", "गए", "गई", "लिए", "तक", "बार", "नहीं", "करें",
        "करो", "चुने", "चुनें", "चुनो", "शुरू", "पूरा", "बाद", "रोक", "खत्म", "मुफ्त",
        "टैप", "किया", "किए", "कम", "सुबह", "दोपहर", "शाम", "लिखो", "दिखाता",
    ]),
]))

CHECKS = {"kn": KN_TELUGU, "pa": PA_HINDI, "gu": GU_HINDI, "mr": MR_HINDI}


def values(localization: dict, path: str = ""):
    unit = localization.get("stringUnit")
    if unit:
        yield path, unit["value"]
    for kind, cases in sorted((localization.get("variations") or {}).items()):
        for case, nested in cases.items():
            yield from values(nested, f"{path}/{kind}/{case}")


def leaks(lang: str, value: str) -> list[str]:
    return [m.group(0) for m in CHECKS[lang].finditer(value)]


def main() -> int:
    errors: list[str] = []
    checked = 0
    for catalog_path in CATALOGS:
        catalog = json.loads(catalog_path.read_text())
        label = catalog_path.relative_to(REPO_ROOT)
        for key, entry in (catalog.get("strings") or {}).items():
            for lang in CHECKS:
                localization = (entry.get("localizations") or {}).get(lang)
                if not localization:
                    continue
                for path, value in values(localization):
                    checked += 1
                    found = leaks(lang, value)
                    if found:
                        errors.append(f"{label}:{key}{path} [{lang}] {found}: {value!r}")
    if errors:
        print("\n".join(errors))
        print(f"{len(errors)} of {checked} kn/pa/gu/mr values read as Telugu or Hindi")
        return 1
    print(f"ok: {checked} kn/pa/gu/mr values are in their own language")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
