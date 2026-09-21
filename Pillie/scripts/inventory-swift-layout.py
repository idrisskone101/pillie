#!/usr/bin/env python3
"""Report Swift layout debt that the taste CI gate does not fail today.

This is the inventory lever for a taste refactor. It does not fail CI.
Re-run after each unit and keep the report next to the axe pin.

    python3 Pillie/scripts/inventory-swift-layout.py
    python3 Pillie/scripts/inventory-swift-layout.py --min-lines 400
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_ROOTS = (
    REPO_ROOT / "Pillie" / "Pillie",
    REPO_ROOT / "Pillie" / "PillieShieldAction",
    REPO_ROOT / "Pillie" / "PillieDeviceActivityMonitor",
)
SKIP_DIR_NAMES = frozenset({".build", "DerivedData", "__pycache__"})
DUMP_DIR_NAMES = frozenset({"Views", "Helpers", "Utils", "Utilities"})
TYPE_RE = re.compile(
    r"^(?P<indent>\s*)(?:(?:public|package|internal|private|fileprivate|open)\s+)*"
    r"(?:final\s+)?(?P<kind>struct|class|enum|actor)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)",
    re.MULTILINE,
)


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


def relpath(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def type_names(text: str) -> list[tuple[int, str, str]]:
    found: list[tuple[int, str, str]] = []
    for match in TYPE_RE.finditer(text):
        line = text[: match.start()].count("\n") + 1
        found.append((line, match.group("kind"), match.group("name")))
    return found


def first_type_after_imports(text: str) -> tuple[int, str, str] | None:
    for match in TYPE_RE.finditer(text):
        prefix = text[: match.start()]
        leftover = [
            line
            for line in prefix.splitlines()
            if line.strip()
            and not line.lstrip().startswith("//")
            and not line.lstrip().startswith("/*")
            and not line.lstrip().startswith("import ")
            and not line.lstrip().startswith("#")
            and not line.lstrip().startswith("@")
        ]
        if leftover:
            # Keep scanning; we still want the first type even if attributes
            # or leftover comments sit above it.
            pass
        return (
            text[: match.start()].count("\n") + 1,
            match.group("kind"),
            match.group("name"),
        )
    return None


def file_stem_type(path: Path) -> str:
    return path.stem


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Inventory Swift layout debt.")
    parser.add_argument("--min-lines", type=int, default=400)
    parser.add_argument(
        "--root",
        action="append",
        type=Path,
        dest="roots",
        help="Scan this tree. Repeatable. Defaults to app sources.",
    )
    args = parser.parse_args(argv)
    roots = [path.resolve() for path in args.roots] if args.roots else list(DEFAULT_ROOTS)

    files: list[Path] = []
    for root in roots:
        files.extend(iter_swift_files(root))
    files = sorted(set(files))

    large: list[tuple[int, str]] = []
    extra_types: list[str] = []
    dump_files: list[str] = []
    main_not_first: list[str] = []

    for path in files:
        text = path.read_text(encoding="utf-8")
        lines = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
        rel = relpath(path)
        if lines >= args.min_lines:
            large.append((lines, rel))
        if path.parent.name in DUMP_DIR_NAMES:
            dump_files.append(rel)
        types = type_names(text)
        stem = file_stem_type(path)
        if path.name.endswith("View.swift") or path.name.endswith("App.swift"):
            for line, kind, name in types:
                if name != stem:
                    extra_types.append(f"{rel}:{line}\t{kind} {name}")
            first = first_type_after_imports(text)
            if first and first[2] != stem:
                main_not_first.append(f"{rel}:{first[0]}\tfirst type is {first[1]} {first[2]}")

    print(f"swift-layout: {len(files)} files")
    print(f"large-files\t{len(large)}\tmin_lines={args.min_lines}")
    for lines, rel in sorted(large, reverse=True):
        print(f"LARGE\t{lines}\t{rel}")
    print(f"dump-folder\t{len(dump_files)}")
    for rel in dump_files:
        print(f"DUMP\t{rel}")
    print(f"extra-types-in-named-files\t{len(extra_types)}")
    for row in extra_types:
        print(f"EXTRA\t{row}")
    print(f"main-symbol-not-first\t{len(main_not_first)}")
    for row in main_not_first:
        print(f"ORDER\t{row}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
