#!/usr/bin/env python3
"""Flag English copy that breaks the Pillie voice guide.

Checks live keys only. Keys no Swift code reads are listed by
copy-inventory.py and should be deleted, not rewritten.

    python3 Pillie/scripts/copy-rewrite/copy-voice-lint.py            # report
    python3 Pillie/scripts/copy-rewrite/copy-voice-lint.py --counts   # totals per rule
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from importlib import import_module
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
inventory = import_module("copy-inventory")

PROPER_NOUNS = {
    "Pillie", "Plus", "Apple", "iPhone", "Screen", "Time", "App", "Store", "Lock",
    "Instagram", "TikTok", "YouTube", "Reddit", "Messages", "Settings", "Today",
    "History", "Continue", "I",
}

GLOSSARY = [
    (r"\bpings?\b|\bpinging\b", "say reminder, not ping"),
    (r"\bblock(list|s intercepted)\b|\bintercept", "apps pause, they are not intercepted or blocklisted"),
    (r"\bprotect(ed|ion)\b", "no protection wording, it reads as a contraceptive claim"),
    (r"\b(today.s|the|log the|pillie) action\b|\baction logged\b|\bstill open\b", "name the real step (take your pill, check in), not an action"),
    (r"\bdetected\b|\bcalculated\b", "system-speak, say what Pillie did in plain words"),
    (r"\bsimulator\b", "developer word in shipped copy"),
    (r"^hey\b", "no Hey opener, lead with the step"),
    (r"\btwo weeks\b", "the trial counts active days, say 14 active days"),
    (r"\bmay be running low\b|\bwhen convenient\b", "hedged and cold, say what to check"),
]


def title_case(segment: str) -> bool:
    words = re.findall(r"[A-Za-z][A-Za-z’']*", segment)
    if len(words) < 2:
        return False
    capped = [w for w in words[1:] if w[0].isupper() and w not in PROPER_NOUNS and not w.isupper()]
    return len(capped) >= 1 and len(capped) >= (len(words) - 1) / 2


def findings(text: str) -> list[str]:
    out = []
    for pattern, message in GLOSSARY:
        if re.search(pattern, text, re.IGNORECASE):
            out.append(f"glossary: {message}")
    if "—" in text or re.search(r"(?<!\d)–|–(?!\d)", text):
        out.append("no em or en dash in prose (ranges like 23–28 are fine)")
    if any(title_case(part) for part in text.split(" · ")):
        out.append("sentence case, not Title Case")
    letters = re.sub(r"%\S+|[^A-Za-z]", "", text)
    if len(letters) >= 3 and letters.isupper():
        out.append("write sentence case and uppercase in SwiftUI with .textCase(.uppercase)")
    if re.search(r"[A-Za-z]'[A-Za-z]", text):
        out.append("use the typographic apostrophe ’")
    if ". " in text and not re.search(r"[.!?…:)]$", text.strip()):
        out.append("a multi-sentence line ends with punctuation")
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--counts", action="store_true")
    args = parser.parse_args()
    live = [r for r in inventory.rows() if r["swift_ref"] != "none"]
    counts: Counter[str] = Counter()
    flagged = 0
    for row in live:
        hits = findings(row["en"])
        if not hits:
            continue
        flagged += 1
        counts.update(hits)
        if not args.counts:
            print(f"{row['table']}:{row['key']}\t{row['en']}\t{'; '.join(hits)}")
    print(f"{flagged} of {len(live)} live keys break the voice guide", file=sys.stderr)
    if args.counts:
        for rule, n in counts.most_common():
            print(f"{n}\t{rule}")
    return 1 if flagged else 0


if __name__ == "__main__":
    raise SystemExit(main())
