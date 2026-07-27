"""Command entry point for public documentation verification checks."""

from __future__ import annotations

import sys
from pathlib import Path

from .markdown_checks import (
    check_backticked_source_paths,
    check_links,
    check_public_planning_contract,
    check_required_topics,
    check_manual_input_markers,
    docs_from_patterns,
)

ALLOWED_NON_FILESYSTEM_LINK_PREFIXES = (
    "../../security",
)


def collect_documentation_errors(docs: list[Path]) -> list[str]:
    """Collect link, source-path, topic, planning, and manual-input failures."""
    errors: list[str] = []
    errors.extend(
        check_links(docs, missing_allowed_prefixes=ALLOWED_NON_FILESYSTEM_LINK_PREFIXES)
    )
    errors.extend(check_backticked_source_paths(docs))
    errors.extend(check_required_topics(docs))
    errors.extend(check_public_planning_contract())
    errors.extend(check_manual_input_markers(docs))
    return errors


def print_documentation_result(errors: list[str]) -> int:
    """Print every documentation failure to stderr and return the gate status."""
    if errors:
        print("Documentation verification failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Documentation verification passed.")
    return 0


def main() -> int:
    """Run every public-doc contract and emit a concise pass or failure list."""
    print("Documentation verifier checks public documentation only.")
    return print_documentation_result(collect_documentation_errors(docs_from_patterns()))


if __name__ == "__main__":
    raise SystemExit(main())
