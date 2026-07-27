"""Expose the single public archive boundary document."""

from __future__ import annotations

import sys
from pathlib import Path


def archive_index(root: Path) -> Path:
    """Return the single public archive index retained in release documentation."""
    return root / "archive" / "README.md"


def archive_set_targets(root: Path) -> tuple[str, ...]:
    """Return no archive set directories because public history is index-only."""
    del root
    return ()


def archive_doc_patterns(root: Path) -> tuple[str, ...]:
    """Expose the public archive index to the documentation inventory."""
    del root
    return ("archive/README.md",)


def archive_roots(root: Path) -> tuple[str, ...]:
    """Return no traversable archive roots for the public documentation corpus."""
    del root
    return ()


def main(argv: list[str]) -> int:
    """Print archive document patterns or roots for the requesting verification script."""
    root = Path.cwd()
    mode = argv[1] if len(argv) > 1 else "docs"
    if mode == "docs":
        values = archive_doc_patterns(root)
    elif mode == "roots":
        values = archive_roots(root)
    else:
        print(
            "usage: python3 -m scripts.verify_docs.archive_inventory [docs|roots]",
            file=sys.stderr,
        )
        return 2

    for value in values:
        print(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
