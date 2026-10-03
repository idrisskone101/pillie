#!/usr/bin/env python3
"""Turn screen-tour shots into a side-by-side gallery page.

Reads .qa-artifacts/flows/screen-tour-<lang>/NN-name.png for every locale
that has a complete tour, packs each locale into one WebP strip, and writes
index.html plus strips/<lang>.webp to the output folder.

    python3 Pillie/scripts/copy-rewrite/build-screen-gallery.py OUT_DIR

Needs Pillow (`pip install pillow`).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from importlib import import_module

from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
FLOWS = REPO_ROOT / ".qa-artifacts" / "flows"
LANGUAGE_SOURCE = REPO_ROOT / "Pillie" / "Pillie" / "Localization" / "AppLanguagePreference.swift"
TEMPLATE = SCRIPT_DIR / "screen-gallery.html.in"
SHOT_SIZE = (402, 874)

sys.path.insert(0, str(SCRIPT_DIR))
APP_LANGUAGE_CODES: list[str] = import_module("check-translated-copy").APP_LANGUAGE_CODES

ENGLISH_NAMES = {
    "en": "English", "ar": "Arabic", "bn": "Bengali", "ca": "Catalan", "cs": "Czech", "da": "Danish",
    "de": "German", "el": "Greek", "es": "Spanish", "fi": "Finnish", "fr": "French", "gu": "Gujarati",
    "he": "Hebrew", "hi": "Hindi", "hr": "Croatian", "hu": "Hungarian", "id": "Indonesian",
    "it": "Italian", "ja": "Japanese", "kn": "Kannada", "ko": "Korean", "ml": "Malayalam",
    "mr": "Marathi", "ms": "Malay", "nb": "Norwegian", "nl": "Dutch", "or": "Odia", "pa": "Punjabi",
    "pl": "Polish", "pt-BR": "Portuguese (Brazil)", "pt-PT": "Portuguese (Portugal)", "ro": "Romanian",
    "ru": "Russian", "sk": "Slovak", "sl": "Slovenian", "sv": "Swedish", "ta": "Tamil", "te": "Telugu",
    "th": "Thai", "tr": "Turkish", "uk": "Ukrainian", "ur": "Urdu", "vi": "Vietnamese",
    "zh-Hans": "Chinese (Simplified)", "zh-Hant": "Chinese (Traditional)",
}
RTL = {"ar", "he", "ur"}


def native_names() -> dict[str, str]:
    source = LANGUAGE_SOURCE.read_text()
    codes = dict(re.findall(r'case (\w+) = "([A-Za-z-]+)"', source))
    names = dict(re.findall(r'case \.(\w+): return "([^"]+)"', source))
    return {code: names[case] for case, code in codes.items() if case in names}


def shot_label(stem: str) -> str:
    name = re.sub(r"^\d+-", "", stem)
    name = re.sub(r"-\d+-", "-", name)
    return name.replace("-", " ").capitalize()


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 64
    out = Path(sys.argv[1])
    (out / "strips").mkdir(parents=True, exist_ok=True)

    reference = sorted((FLOWS / "screen-tour-en").glob("[0-9][0-9]-*.png"))
    stems = [p.stem for p in reference]
    if not stems:
        sys.exit("no English tour at .qa-artifacts/flows/screen-tour-en; run screen-tour.sh en first")

    natives = native_names()
    locales = []
    for code in ["en", *(c for c in APP_LANGUAGE_CODES if c != "en")]:
        folder = FLOWS / f"screen-tour-{code}"
        shots = [folder / f"{stem}.png" for stem in stems]
        missing = [s.name for s in shots if not s.exists()]
        if missing:
            print(f"skip {code}: {len(missing)} of {len(stems)} shots missing")
            continue
        strip = Image.new("RGB", (SHOT_SIZE[0] * len(shots), SHOT_SIZE[1]), "white")
        for index, shot in enumerate(shots):
            image = Image.open(shot).convert("RGB")
            if image.size != SHOT_SIZE:
                image = image.resize(SHOT_SIZE)
            strip.paste(image, (index * SHOT_SIZE[0], 0))
        strip.save(out / "strips" / f"{code}.webp", quality=85, method=6)
        report = json.loads((folder / "report.json").read_text()) if (folder / "report.json").exists() else {}
        locales.append({
            "code": code,
            "native": natives.get(code, code),
            "english": ENGLISH_NAMES.get(code, code),
            "rtl": code in RTL,
            "sha": str(report.get("app_sha", ""))[:7],
        })
        print(f"ok {code}")

    manifest = {"shots": [shot_label(s) for s in stems], "locales": locales, "size": SHOT_SIZE}
    page = TEMPLATE.read_text().replace(
        "__MANIFEST__", json.dumps(manifest, ensure_ascii=False).replace("</", "<\\/")
    )
    (out / "index.html").write_text(page)
    print(f"wrote {out / 'index.html'} with {len(locales)} locales and {len(stems)} screens")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
