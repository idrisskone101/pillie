#!/usr/bin/env python3
"""Flatten an `axe describe-ui` JSON dump into one line per labeled element.

Usage:
  Pillie/scripts/ax-outline.py DUMP.json            # print the outline
  Pillie/scripts/ax-outline.py DUMP.json --has id X # exit 0 if AXUniqueId X exists
  Pillie/scripts/ax-outline.py DUMP.json --has label X
  Pillie/scripts/ax-outline.py DUMP.json --has text X  # substring of any label/value

Outline line: `Type  #id  "label"  =value  @x,y wxh` (points, top-left origin).
Elements with no id, label, or value are skipped. SF Symbol names that axe
reports as ids (`arrow.right`) are kept, since some buttons only have those.
"""

import json
import sys


def walk(nodes, depth=0):
    for node in nodes or []:
        yield depth, node
        yield from walk(node.get("children"), depth + 1)


def fmt(node):
    parts = [node.get("type") or node.get("role") or "?"]
    if node.get("AXUniqueId"):
        parts.append(f"#{node['AXUniqueId']}")
    if node.get("AXLabel"):
        parts.append(json.dumps(node["AXLabel"], ensure_ascii=False))
    if node.get("AXValue") not in (None, ""):
        parts.append(f"={json.dumps(node['AXValue'], ensure_ascii=False)}")
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
    if len(sys.argv) >= 5 and sys.argv[2] == "--has":
        kind, want = sys.argv[3], sys.argv[4]
        for n in nodes:
            if kind == "id" and n.get("AXUniqueId") == want:
                return 0
            if kind == "label" and n.get("AXLabel") == want:
                return 0
            if kind == "text" and any(want in str(n.get(k) or "") for k in ("AXLabel", "AXValue")):
                return 0
        return 1
    for depth, n in walk(tree):
        if n.get("AXUniqueId") or n.get("AXLabel") or n.get("AXValue") not in (None, ""):
            print("  " * min(depth, 8) + fmt(n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
