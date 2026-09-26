#!/usr/bin/env python3
"""Flatten an `axe describe-ui` JSON dump into one line per labeled element.

Usage:
  Pillie/scripts/ax-outline.py DUMP.json            # print the outline
  Pillie/scripts/ax-outline.py DUMP.json --has id X # exit 0 if AXUniqueId X exists
  Pillie/scripts/ax-outline.py DUMP.json --has label X
  Pillie/scripts/ax-outline.py DUMP.json --has text X  # substring of any label/value
  Pillie/scripts/ax-outline.py DUMP.json --center id|label|value X [--type Button]
                                  # print "x y" of the first on-screen match, exit 1 if none

Outline line: `Type  #id  "label"  =value  @x,y wxh` (points, top-left origin).
Narrow and no-break spaces print as \u202f etc.; --has and --center fold them to
plain spaces, so flows can type ordinary spaces.
Elements with no id, label, or value are skipped. SF Symbol names that axe
reports as ids (`arrow.right`) are kept, since some buttons only have those.
"""

import json
import sys

# iOS formats times and dates with narrow/no-break spaces ("8:00\u202fAM").
# Flows type plain spaces, so every comparison folds them.
SPACES = {0x202F: " ", 0x00A0: " ", 0x2009: " ", 0x2007: " "}


def norm(value):
    return str(value or "").translate(SPACES)


def walk(nodes, depth=0):
    for node in nodes or []:
        yield depth, node
        yield from walk(node.get("children"), depth + 1)


def visible(value):
    # Show odd spaces so a flow author knows axe's own --label match needs them.
    text = json.dumps(value, ensure_ascii=False)
    return "".join(f"\\u{ord(c):04x}" if ord(c) in SPACES else c for c in text)


def fmt(node):
    parts = [node.get("type") or node.get("role") or "?"]
    if node.get("AXUniqueId"):
        parts.append(f"#{node['AXUniqueId']}")
    if node.get("AXLabel"):
        parts.append(visible(node["AXLabel"]))
    if node.get("AXValue") not in (None, ""):
        parts.append(f"={visible(node['AXValue'])}")
    f = node.get("frame") or {}
    if f:
        parts.append(f"@{f.get('x', 0):.0f},{f.get('y', 0):.0f} {f.get('width', 0):.0f}x{f.get('height', 0):.0f}")
    if node.get("enabled") is False:
        parts.append("disabled")
    return "  ".join(parts)


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    with open(sys.argv[1], encoding="utf-8") as fh:
        try:
            tree = json.load(fh)
        except json.JSONDecodeError:
            print("error: not an axe JSON dump", file=sys.stderr)
            return 2
    nodes = [n for _, n in walk(tree)]
    if len(sys.argv) >= 5 and sys.argv[2] == "--center":
        kind, want = sys.argv[3], sys.argv[4]
        etype = sys.argv[6] if len(sys.argv) >= 7 and sys.argv[5] == "--type" else None
        key = {"id": "AXUniqueId", "label": "AXLabel", "value": "AXValue"}[kind]
        screen = (tree[0].get("frame") or {}) if tree else {}
        width, height = screen.get("width", 10000), screen.get("height", 10000)
        for n in nodes:
            f = n.get("frame") or {}
            if norm(n.get(key)) != norm(want) or (etype and n.get("type") != etype):
                continue
            x, y = f.get("x", 0) + f.get("width", 0) / 2, f.get("y", 0) + f.get("height", 0) / 2
            if 0 <= x <= width and 0 <= y <= height:
                print(f"{x:.0f} {y:.0f}")
                return 0
        return 1
    if len(sys.argv) >= 5 and sys.argv[2] == "--has":
        kind, want = sys.argv[3], sys.argv[4]
        for n in nodes:
            if kind == "id" and n.get("AXUniqueId") == want:
                return 0
            if kind == "label" and norm(n.get("AXLabel")) == norm(want):
                return 0
            if kind == "text" and any(norm(want) in norm(n.get(k)) for k in ("AXLabel", "AXValue")):
                return 0
        return 1
    for depth, n in walk(tree):
        if n.get("AXUniqueId") or n.get("AXLabel") or n.get("AXValue") not in (None, ""):
            print("  " * min(depth, 8) + fmt(n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
