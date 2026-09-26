#!/usr/bin/env python3
"""Check verify-pillie flows and feature docs against the app source.

Usage: Pillie/scripts/check-verify-flows.py [--quiet]

Fails when a flow uses an unknown step, a pillie://debug path the app does
not handle, or an id that is not a string literal anywhere in Swift source;
when a flow is not named by any feature doc; or when a feature doc is missing
from features/README.md. Runs on Linux in about a second.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / ".agents/skills/verify-pillie"
FLOWS = SKILL / "flows"
FEATURES = SKILL / "features"
SWIFT_ROOT = ROOT / "Pillie"
APP = ROOT / "Pillie/Pillie/PillieApp.swift"
RUNNER = ROOT / "Pillie/scripts/sim-flow.sh"

AXE_STEPS = {"tap", "swipe", "gesture", "touch", "type", "button", "key", "key-sequence", "key-combo", "sleep"}


def runner_steps():
    text = RUNNER.read_text(encoding="utf-8")
    body = text.split("run_pseudo() {", 1)[1].split("\n}\n", 1)[0]
    return set(re.findall(r"^    ([a-z-]+)\)", body, re.M))


def swift_literals():
    lits, prefixes = set(), set()
    for path in SWIFT_ROOT.rglob("*.swift"):
        text = path.read_text(encoding="utf-8", errors="replace")
        lits.update(re.findall(r'"([^"\\\n]+)"', text))
        # accessibilityIdentifier("historyEditableDay.\(month).\(day)") -> historyEditableDay.
        prefixes.update(re.findall(r'"([A-Za-z][\w.-]*?)\\\(', text))
    return lits, prefixes


def main():
    quiet = "--quiet" in sys.argv
    errors = []
    steps = runner_steps() | AXE_STEPS
    deep_links = set(re.findall(r'case "(/[\w-]+)"', APP.read_text(encoding="utf-8")))
    lits, prefixes = swift_literals()

    def known_id(value):
        return value in lits or any(value.startswith(p) and len(value) > len(p) for p in prefixes)

    flows = sorted(FLOWS.glob("*.flow"))
    for flow in flows:
        for n, raw in enumerate(flow.read_text(encoding="utf-8").splitlines(), 1):
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            where = f"{flow.relative_to(ROOT)}:{n}"
            verb = line.split()[0]
            if verb not in steps:
                errors.append(f"{where}: unknown step `{verb}`")
            for path in re.findall(r"pillie://debug(/[\w-]+)", line):
                if path not in deep_links:
                    errors.append(f"{where}: PillieApp.swift has no deep link `{path}`")
            ids = re.findall(r"^(?:wait|gone|expect|expect-not) id (\S+)", line)
            ids += re.findall(r"--id (\S+)", line)
            for ident in ids:
                ident = ident.strip("'\"")
                if not known_id(ident):
                    errors.append(f"{where}: id `{ident}` is not a string literal in Swift source")

    docs = sorted(p for p in FEATURES.glob("*.md") if p.name != "README.md")
    doc_text = "\n".join(p.read_text(encoding="utf-8") for p in docs)
    for flow in flows:
        if flow.name not in doc_text and flow.stem not in ("smoke", "perf"):
            errors.append(f"{flow.relative_to(ROOT)}: no feature doc names this flow")
    readme = (FEATURES / "README.md").read_text(encoding="utf-8")
    for doc in docs:
        if f"({doc.name})" not in readme and f"(./{doc.name})" not in readme:
            errors.append(f"{doc.relative_to(ROOT)}: missing from features/README.md")
    for ref in re.findall(r"flows/([\w-]+\.flow)", doc_text):
        if not (FLOWS / ref).exists():
            errors.append(f"features: names missing flow `{ref}`")

    for e in errors:
        print(f"error: {e}")
    if not quiet or errors:
        print(f"{'FAIL' if errors else 'ok'}: {len(flows)} flows, {len(docs)} feature docs, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
