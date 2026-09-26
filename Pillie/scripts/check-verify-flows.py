#!/usr/bin/env python3
"""Check verify-pillie flows and feature docs against the app source.

Usage: Pillie/scripts/check-verify-flows.py [--quiet]

Fails when a flow line does not parse, uses an unknown step, gives wait/gone/
expect the wrong arguments, gives a step fewer arguments than it reads, opens a pillie://debug path the app does not
handle, or names an id that is neither an accessibilityIdentifier literal nor
an SF Symbol name in app source;
when a flow is not named by any feature doc; or when a feature doc is missing
from features/README.md. Runs on Linux in about a second.
"""

import re
import shlex
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / ".agents/skills/verify-pillie"
FLOWS = SKILL / "flows"
FEATURES = SKILL / "features"
SWIFT_ROOT = ROOT / "Pillie"
APP = ROOT / "Pillie/Pillie/PillieApp.swift"
RUNNER = ROOT / "Pillie/scripts/sim-flow.sh"

# Steps whose runner branch reads positional args; fewer args crash it under set -u.
MIN_ARGS = {"shot": 1, "appearance": 1, "statusbar": 1, "openurl": 1, "push": 1,
            "record": 1, "log": 1, "privacy": 2, "defaults": 3}

AXE_STEPS = {"tap", "swipe", "gesture", "touch", "type", "button", "key", "key-sequence", "key-combo", "sleep"}


def runner_steps():
    text = RUNNER.read_text(encoding="utf-8")
    body = text.split("run_pseudo() {", 1)[1].split("\n}\n", 1)[0]
    return set(re.findall(r"^    ([a-z-]+)\)", body, re.M))


def swift_ids():
    # Ids axe can report: .accessibilityIdentifier("…") literals (and the literal
    # prefix of interpolated ones), plus SF Symbol names, which axe reports as ids.
    lits, prefixes = set(), set()
    for path in SWIFT_ROOT.rglob("*.swift"):
        if "Tests" in path.parts[-2]:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for arg in re.findall(r'accessibilityIdentifier\(\s*"((?:[^"\\]|\\.)*)"', text):
            head = arg.split("\\(", 1)[0]
            (prefixes if "\\(" in arg else lits).add(head)
        lits.update(re.findall(r'systemName:\s*"([^"]+)"', text))
    return lits, {p for p in prefixes if p}


def main():
    quiet = "--quiet" in sys.argv
    errors = []
    steps = runner_steps() | AXE_STEPS
    deep_links = set(re.findall(r'case "(/[\w-]+)"', APP.read_text(encoding="utf-8")))
    lits, prefixes = swift_ids()

    def known_id(value):
        return value in lits or any(value.startswith(p) and len(value) > len(p) for p in prefixes)

    flows = sorted(FLOWS.glob("*.flow"))
    for flow in flows:
        for n, raw in enumerate(flow.read_text(encoding="utf-8").splitlines(), 1):
            where = f"{flow.relative_to(ROOT)}:{n}"
            try:
                words = shlex.split(raw, comments=True)
            except ValueError as e:
                errors.append(f"{where}: cannot parse ({e})")
                continue
            if not words:
                continue
            verb, rest = words[0], words[1:]
            line = " ".join(words)
            if verb not in steps:
                errors.append(f"{where}: unknown step `{verb}`")
            if verb in ("wait", "gone", "expect", "expect-not"):
                most = 3 if verb in ("wait", "gone") else 2
                if len(rest) < 2 or len(rest) > most or rest[0] not in ("id", "label", "text"):
                    errors.append(f"{where}: `{verb} id|label|text VALUE{' [SECONDS]' if most == 3 else ''}`, got {len(rest)} args; quote multi-word text")
                elif len(rest) == 3 and not rest[2].isdigit():
                    errors.append(f"{where}: seconds must be a whole number, got `{rest[2]}`")
            if len(rest) < MIN_ARGS.get(verb, 0):
                errors.append(f"{where}: `{verb}` needs {MIN_ARGS[verb]} argument(s), got {len(rest)}")
            if verb == "tap":
                for i, w in enumerate(rest):
                    if w in ("--id", "--label", "--value", "--element-type") and (i + 1 >= len(rest) or rest[i + 1].startswith("--")):
                        errors.append(f"{where}: `tap {w}` needs a value")
            for path in re.findall(r"pillie://debug(/[\w-]+)", line):
                if path not in deep_links:
                    errors.append(f"{where}: PillieApp.swift has no deep link `{path}`")
            ids = [rest[1]] if verb in ("wait", "gone", "expect", "expect-not") and rest[:1] == ["id"] and len(rest) > 1 else []
            ids += [rest[i + 1] for i, w in enumerate(rest[:-1]) if w == "--id"]
            for ident in ids:
                if not known_id(ident):
                    errors.append(f"{where}: id `{ident}` is not an accessibilityIdentifier or SF Symbol in app source")

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
