from __future__ import annotations

import re
import sys
from pathlib import Path


ARCHIVE_LINK_RE = re.compile(
    r"\| \[(?P<label>[0-9][^\]]*/)\]\((?P<target>[^)]+)\)"
)


def archive_index(root: Path) -> Path:
    return root / "archive" / "README.md"


def archive_set_targets(root: Path) -> tuple[str, ...]:
    index = archive_index(root)
    if not index.is_file():
        return ()

    targets: list[str] = []
    for match in ARCHIVE_LINK_RE.finditer(index.read_text(encoding="utf-8")):
        target = match.group("target").strip()
        if target.startswith(("http://", "https://")):
            continue
        targets.append(target)
    return tuple(dict.fromkeys(targets))


def archive_doc_patterns(root: Path) -> tuple[str, ...]:
    patterns = ["archive/README.md"]
    for target in archive_set_targets(root):
        if target.endswith("/"):
            patterns.append(f"archive/{target}README.md")
        elif target.endswith(".md"):
            patterns.append(f"archive/{target}")
    return tuple(dict.fromkeys(patterns))


def archive_roots(root: Path) -> tuple[str, ...]:
    roots: list[str] = []
    for target in archive_set_targets(root):
        first_part = target.split("/", 1)[0]
        if first_part:
            roots.append(f"archive/{first_part}")
    return tuple(dict.fromkeys(roots))


def main(argv: list[str]) -> int:
    root = Path.cwd()
    mode = argv[1] if len(argv) > 1 else "docs"
    if mode == "docs":
        values = archive_doc_patterns(root)
    elif mode == "roots":
        values = archive_roots(root)
    else:
        print("usage: python3 -m scripts.verify_docs.archive_inventory [docs|roots]", file=sys.stderr)
        return 2

    for value in values:
        print(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
