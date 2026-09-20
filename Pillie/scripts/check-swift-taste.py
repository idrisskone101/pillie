#!/usr/bin/env python3
"""Fail on concrete Swift structure smells that can be detected statically.

This is the CI half of `.agents/skills/swift-taste`. It does not parse Swift
fully. Heuristics are documented in that skill and in --help.

Refresh the allowlist (debt payoff or heuristic change only):

    python3 Pillie/scripts/check-swift-taste.py --write-allowlist
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_ALLOWLIST = SCRIPT_DIR / "swift-taste-allowlist.txt"
DEFAULT_ROOTS = (
    REPO_ROOT / "Pillie" / "Pillie",
    REPO_ROOT / "Pillie" / "PillieShieldAction",
    REPO_ROOT / "Pillie" / "PillieDeviceActivityMonitor",
)
DUMP_DIR_NAMES = frozenset({"Views", "Helpers", "Utils", "Utilities"})
SKIP_DIR_NAMES = frozenset({".build", "DerivedData", "__pycache__"})

RULES = (
    "empty-catch",
    "deps-bag",
    "dump-folder",
    "view-exported-type",
)


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    signature: str
    message: str
    line: int

    @property
    def key(self) -> str:
        return f"{self.rule}\t{self.path}\t{self.signature}"

    def render(self) -> str:
        return f"{self.rule}\t{self.path}\t{self.signature}\t{self.message}"


def mask_swift(src: str) -> str:
    """Replace comments and string contents with spaces; keep newlines."""
    out: list[str] = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if ch == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if ch == "/" and nxt == "*":
            out.extend("  ")
            i += 2
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            if i < n:
                out.extend("  ")
                i += 2
            continue
        if ch == '"':
            i = _mask_string(src, i, out)
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _mask_string(src: str, start: int, out: list[str]) -> int:
    """Mask a Swift string starting at start (a quote). Returns index after it."""
    i = start
    n = len(src)
    hash_count = 0
    j = start
    while j > 0 and src[j - 1] == "#":
        hash_count += 1
        j -= 1
    if start + 2 < n and src[start : start + 3] == '"""':
        closer = '"""' + ("#" * hash_count)
        out.extend(" " * 3)
        i = start + 3
        while i < n:
            if src.startswith(closer, i):
                out.extend(" " * len(closer))
                return i + len(closer)
            out.append("\n" if src[i] == "\n" else " ")
            i += 1
        return i
    closer = '"' + ("#" * hash_count)
    out.append(" ")
    i = start + 1
    while i < n:
        if src[i] == "\\" and hash_count == 0:
            out.extend("  ")
            i += 2
            continue
        if src.startswith(closer, i):
            out.extend(" " * len(closer))
            return i + len(closer)
        out.append("\n" if src[i] == "\n" else " ")
        i += 1
    return i


def _matching_brace(src: str, open_idx: int) -> int | None:
    depth = 0
    i = open_idx
    n = len(src)
    while i < n:
        ch = src[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return None


def _line_at(src: str, index: int) -> int:
    return src[:index].count("\n") + 1


def _relpath(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def iter_swift_files(root: Path) -> list[Path]:
    files: list[Path] = []
    if not root.exists():
        return files
    for path in root.rglob("*.swift"):
        if any(part in SKIP_DIR_NAMES for part in path.parts):
            continue
        files.append(path)
    files.sort()
    return files


def find_empty_catches(masked: str, relpath: str) -> list[Finding]:
    findings: list[Finding] = []
    i = 0
    n = len(masked)
    while True:
        idx = masked.find("catch", i)
        if idx == -1:
            break
        i = idx + 5
        if idx > 0 and (masked[idx - 1].isalnum() or masked[idx - 1] == "_"):
            continue
        if i < n and (masked[i].isalnum() or masked[i] == "_"):
            continue
        j = i
        while j < n and masked[j] != "{":
            j += 1
        if j >= n:
            break
        close = _matching_brace(masked, j)
        if close is None:
            break
        body = masked[j + 1 : close]
        if body.strip() == "":
            line = _line_at(masked, idx)
            findings.append(
                Finding(
                    rule="empty-catch",
                    path=relpath,
                    signature=f"L{line}",
                    message="empty catch swallows the error",
                    line=line,
                )
            )
        i = close + 1
    return findings


def _function_property_count(body: str) -> int:
    count = 0
    i = 0
    n = len(body)
    while i < n:
        # Skip nested types so we only count this type's own properties.
        rest = body[i:]
        stripped = rest.lstrip()
        lead = len(rest) - len(stripped)
        i += lead
        if i >= n:
            break
        if stripped.startswith(("struct ", "class ", "enum ", "actor ", "protocol ")):
            brace = body.find("{", i)
            if brace == -1:
                break
            close = _matching_brace(body, brace)
            i = n if close is None else close + 1
            continue
        if stripped.startswith(("var ", "let ")) or _starts_with_property(stripped):
            line_end = body.find("\n", i)
            if line_end == -1:
                line_end = n
            header = body[i:line_end]
            if _is_instance_function_property(header):
                count += 1
            brace = body.find("{", i, line_end + 1)
            if brace != -1 and brace <= line_end:
                close = _matching_brace(body, brace)
                i = n if close is None else close + 1
            else:
                i = line_end + 1
            continue
        nl = body.find("\n", i)
        i = n if nl == -1 else nl + 1
    return count


def _starts_with_property(stripped: str) -> bool:
    keywords = (
        "public ",
        "private ",
        "internal ",
        "package ",
        "fileprivate ",
        "open ",
        "lazy ",
        "weak ",
        "unowned ",
    )
    s = stripped
    progressed = True
    while progressed:
        progressed = False
        for kw in keywords:
            if s.startswith(kw):
                s = s[len(kw) :]
                progressed = True
    return s.startswith("var ") or s.startswith("let ")


def _is_instance_function_property(header: str) -> bool:
    tokens = header.split()
    if "static" in tokens or "class" in tokens:
        return False
    if "var" not in tokens and "let" not in tokens:
        return False
    colon = header.find(":")
    if colon == -1:
        return False
    annot = header[colon + 1 :]
    cut = len(annot)
    for sep in ("=", "{"):
        pos = annot.find(sep)
        if pos != -1:
            cut = min(cut, pos)
    annot = annot[:cut]
    return "->" in annot


def find_deps_bags(masked: str, relpath: str) -> list[Finding]:
    findings: list[Finding] = []
    i = 0
    n = len(masked)
    while i < n:
        kind_idx = None
        for kind in ("struct ", "class ", "enum "):
            idx = masked.find(kind, i)
            if idx != -1 and (kind_idx is None or idx < kind_idx):
                kind_idx = idx
                kind_len = len(kind)
        if kind_idx is None:
            break
        if kind_idx > 0 and (masked[kind_idx - 1].isalnum() or masked[kind_idx - 1] == "_"):
            i = kind_idx + 1
            continue
        name_start = kind_idx + kind_len
        while name_start < n and masked[name_start].isspace():
            name_start += 1
        name_end = name_start
        while name_end < n and (masked[name_end].isalnum() or masked[name_end] == "_"):
            name_end += 1
        name = masked[name_start:name_end]
        brace = masked.find("{", name_end)
        if brace == -1:
            break
        close = _matching_brace(masked, brace)
        if close is None:
            break
        i = close + 1
        if name != "Dependencies" and not name.endswith("Dependencies"):
            continue
        body = masked[brace + 1 : close]
        fn_count = _function_property_count(body)
        if fn_count >= 2:
            line = _line_at(masked, kind_idx)
            findings.append(
                Finding(
                    rule="deps-bag",
                    path=relpath,
                    signature=name,
                    message=(
                        f"{name} stores {fn_count} function-typed properties; "
                        "use a protocol + default impl"
                    ),
                    line=line,
                )
            )
    return findings


def find_dump_folder(path: Path, relpath: str) -> list[Finding]:
    if path.parent.name not in DUMP_DIR_NAMES:
        return []
    return [
        Finding(
            rule="dump-folder",
            path=relpath,
            signature=path.name,
            message=(
                f"new Swift file dumped on {path.parent.name}/; "
                "put it in a feature folder"
            ),
            line=1,
        )
    ]


def find_view_exported_types(masked: str, path: Path, relpath: str) -> list[Finding]:
    if not path.name.endswith("View.swift"):
        return []
    stem = path.stem
    findings: list[Finding] = []
    i = 0
    n = len(masked)
    while i < n:
        vis_idx = None
        vis = None
        for keyword in ("public ", "package "):
            idx = masked.find(keyword, i)
            if idx != -1 and (vis_idx is None or idx < vis_idx):
                vis_idx = idx
                vis = keyword.strip()
        if vis_idx is None:
            break
        if vis_idx > 0 and (masked[vis_idx - 1].isalnum() or masked[vis_idx - 1] == "_"):
            i = vis_idx + 1
            continue
        after = masked[vis_idx + len(vis) :].lstrip()
        consumed = len(masked[vis_idx + len(vis) :]) - len(after)
        kind = None
        for candidate in ("struct ", "enum ", "class ", "actor "):
            if after.startswith(candidate):
                kind = candidate
                break
        if kind is None:
            i = vis_idx + 1
            continue
        name_start = vis_idx + len(vis) + consumed + len(kind)
        name_end = name_start
        while name_end < n and (masked[name_end].isalnum() or masked[name_end] == "_"):
            name_end += 1
        name = masked[name_start:name_end]
        i = name_end
        if not name or name == stem:
            continue
        line = _line_at(masked, vis_idx)
        findings.append(
            Finding(
                rule="view-exported-type",
                path=relpath,
                signature=name,
                message=(
                    f"{vis} {name} in {path.name}; move it to Types.swift "
                    f"beside the feature (file type is {stem})"
                ),
                line=line,
            )
        )
    return findings


def scan_file(path: Path, display_root: Path) -> list[Finding]:
    relpath = _relpath(path, display_root)
    text = path.read_text(encoding="utf-8")
    masked = mask_swift(text)
    findings: list[Finding] = []
    findings.extend(find_empty_catches(masked, relpath))
    findings.extend(find_deps_bags(masked, relpath))
    findings.extend(find_dump_folder(path, relpath))
    findings.extend(find_view_exported_types(masked, path, relpath))
    return findings


def scan_roots(roots: list[Path], display_root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for root in roots:
        for path in iter_swift_files(root):
            findings.extend(scan_file(path, display_root))
    findings.sort(key=lambda item: (item.rule, item.path, item.line, item.signature))
    return findings


def load_allowlist(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    keys: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            raise SystemExit(f"error: malformed allowlist line: {raw!r}")
        keys.add(f"{parts[0]}\t{parts[1]}\t{parts[2]}")
    return keys


ALLOWLIST_HEADER = """\
# Pre-existing Swift taste findings. New findings fail CI.
# Each data line is: rule<TAB>repo-relative-path<TAB>signature
#
# Refresh after paying down debt or changing a heuristic (own commit):
#   python3 Pillie/scripts/check-swift-taste.py --write-allowlist
#
# Do not add a new smell to this file to land a feature. Fix the smell
# or put the file in a feature folder instead.
#
# Rules: empty-catch, deps-bag, dump-folder, view-exported-type
"""


def write_allowlist(path: Path, findings: list[Finding]) -> None:
    lines = [ALLOWLIST_HEADER.rstrip(), ""]
    if findings:
        for item in findings:
            lines.append(item.key)
        lines.append("")
    else:
        lines.append("# (none — HEAD is clean for the static heuristics)")
        lines.append("")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fail on concrete Swift taste smells (empty catch, deps bags, dump folders)."
    )
    parser.add_argument(
        "--root",
        action="append",
        type=Path,
        dest="roots",
        help="Scan this tree instead of the app sources. Repeatable.",
    )
    parser.add_argument(
        "--allowlist",
        type=Path,
        default=DEFAULT_ALLOWLIST,
        help="Allowlist file (default: Pillie/scripts/swift-taste-allowlist.txt).",
    )
    parser.add_argument(
        "--no-allowlist",
        action="store_true",
        help="Treat every finding as new (used by the fixture selftest).",
    )
    parser.add_argument(
        "--write-allowlist",
        action="store_true",
        help="Rewrite the allowlist from current findings and exit 0.",
    )
    parser.add_argument(
        "--show-allowlisted",
        action="store_true",
        help="Print findings that the allowlist already covers.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.roots:
        roots = [path.resolve() for path in args.roots]
        display_root = roots[0] if len(roots) == 1 else REPO_ROOT
    else:
        roots = [path for path in DEFAULT_ROOTS if path.exists()]
        display_root = REPO_ROOT
        if not roots:
            print("error: no app Swift roots found", file=sys.stderr)
            return 2

    findings = scan_roots(roots, display_root)
    allowlist_path = args.allowlist
    if not allowlist_path.is_absolute():
        allowlist_path = (Path.cwd() / allowlist_path).resolve()

    if args.write_allowlist:
        write_allowlist(allowlist_path, findings)
        print(f"ok: wrote {len(findings)} allowlist entries to {allowlist_path}")
        return 0

    allowed = set() if args.no_allowlist else load_allowlist(allowlist_path)
    new = [item for item in findings if item.key not in allowed]
    allowlisted = [item for item in findings if item.key in allowed]
    found_keys = {item.key for item in findings}
    stale = sorted(allowed - found_keys)

    if args.show_allowlisted and allowlisted:
        print("allowlisted:")
        for item in allowlisted:
            print(f"  {item.render()}")

    if new:
        print(f"swift-taste: {len(new)} new finding(s), {len(stale)} stale allowlist")
        for item in new:
            print(f"NEW\t{item.render()}")
        if stale:
            print("stale allowlist entries (remove them):")
            for key in stale:
                print(f"STALE\t{key}")
        return 1

    if stale:
        print(f"swift-taste: 0 new findings, {len(stale)} stale allowlist")
        print("stale allowlist entries (remove them):")
        for key in stale:
            print(f"STALE\t{key}")
        return 1

    file_count = sum(len(iter_swift_files(root)) for root in roots)
    print(
        f"ok: 0 new findings ({len(allowlisted)} allowlisted, "
        f"{len(findings)} scanned matches, {file_count} swift files)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
