"""Markdown-specific documentation verification checks."""

from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import unquote

from .constants import (
    DOC_IGNORE_PREFIXES,
    DOC_PATTERNS,
    PUBLIC_ACTIVE_STALE_REFERENCES,
    PUBLIC_ARCHITECTURE_DOCS,
    PUBLIC_EVIDENCE_LABEL_HEADING,
    PUBLIC_EVIDENCE_LABELS,
    PUBLIC_PLANNING_DOCS,
    PUBLIC_PLANNING_FORBIDDEN_TOKENS,
    PUBLIC_PLANNING_REQUIRED_TOKENS,
    REQUIRED_TOPICS,
    ROOT,
)


def has_ignored_doc_prefix(parts: tuple[str, ...]) -> bool:
    """Return whether a repository-relative path belongs to an excluded tree."""
    return any(parts[:len(prefix)] == prefix for prefix in DOC_IGNORE_PREFIXES)


def is_plan_document(name: str) -> bool:
    """Recognize active and suffixed planning-document naming conventions."""
    return name == "plan.md" or name.startswith("plan-") or "-plan." in name or "-plan-" in name


def is_non_public_doc_name(parts: tuple[str, ...], name: str) -> bool:
    """Recognize local instructions, plans, audits, and working records."""
    if len(parts) == 1 and name in {"agents.md", "claude.md", "gemini.md"}:
        return True
    return any(token in name for token in ("audit", "remediation", "ledger")) or is_plan_document(name)


def is_ignored_doc(path: Path) -> bool:
    """Exclude local, archived, and planning-only Markdown from public checks."""
    try:
        parts = path.relative_to(ROOT).parts
    except ValueError:
        return True
    if has_ignored_doc_prefix(parts):
        return True
    if not parts or (len(parts) != 1 and parts[0] != "docs"):
        return False
    return is_non_public_doc_name(parts, path.name.lower())


def docs_from_patterns() -> list[Path]:
    """Expand configured documentation patterns into the active public Markdown set."""
    docs: set[Path] = set()
    for pattern in DOC_PATTERNS:
        if any(char in pattern for char in "*?["):
            docs.update(ROOT.glob(pattern))
        else:
            docs.add(ROOT / pattern)
    return sorted(path for path in docs if path.is_file() and not is_ignored_doc(path))


def remove_fenced_code(text: str) -> str:
    """Remove fenced examples so path-like snippets are not validated as prose links."""
    visible_lines: list[str] = []
    in_fence = False
    for line in text.splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            visible_lines.append(line)
    return "\n".join(visible_lines)


def markdown_links(text: str) -> list[str]:
    """Extract inline Markdown link targets from non-fenced documentation text."""
    link_re = re.compile(r"\[[^\]\n]+\]\(([^)\n]+)\)")
    return [match.group(1).strip() for match in link_re.finditer(text)]


def is_external_target(target: str) -> bool:
    """Return whether a link target uses an explicit URI scheme."""
    return bool(re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target))


def normalize_link_target(target: str) -> str:
    """Strip Markdown angle brackets and optional link titles from a target."""
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    return target.split()[0].strip("'\"")


def check_links(
    docs: list[Path],
    missing_allowed_prefixes: tuple[str, ...] = (),
) -> list[str]:
    """Evaluate links and return precise contract violations."""
    errors: list[str] = []
    for doc in docs:
        text = remove_fenced_code(doc.read_text(encoding="utf-8"))
        for raw_target in markdown_links(text):
            if error := broken_relative_link_error(doc, raw_target, missing_allowed_prefixes):
                errors.append(error)
    return errors


def broken_relative_link_error(
    doc: Path,
    raw_target: str,
    missing_allowed_prefixes: tuple[str, ...],
) -> str | None:
    """Describe one relative Markdown target that does not resolve."""
    target = normalize_link_target(raw_target)
    if not target or target.startswith("#") or is_external_target(target):
        return None

    path_part = target.split("#", 1)[0].split("?", 1)[0]
    if not path_part or path_part.startswith(missing_allowed_prefixes):
        return None

    candidate = doc.parent / unquote(path_part)
    if candidate.exists():
        return None

    rel_doc = doc.relative_to(ROOT)
    return f"{rel_doc}: broken relative link: {target}"


def check_backticked_source_paths(docs: list[Path]) -> list[str]:
    """Evaluate backticked source paths and return precise contract violations."""
    errors: list[str] = []
    checked_roots = (
        "Sources/",
        "Tests/",
        "scripts/",
        "linux_connector/",
        ".github/",
    )
    root_files = {
        ".gitignore",
        "GOAL.md",
        "LICENSE",
        "Package.swift",
        "README.md",
        "THIRD_PARTY_NOTICES.md",
        "pyproject.toml",
    }
    generated_residue_names = {
        "__pycache__",
        ".pytest_cache",
        ".ruff_cache",
        ".mypy_cache",
    }
    ignored_prefixes = (("archive",), ("private",))
    token_re = re.compile(r"`([^`\n]+)`")
    source_location_re = re.compile(r"^(.+):\d+(?::\d+)?(?:-\d+(?::\d+)?)?$")

    for doc in docs:
        rel_doc = doc.relative_to(ROOT)
        if any(rel_doc.parts[:len(prefix)] == prefix for prefix in ignored_prefixes):
            continue
        text = remove_fenced_code(doc.read_text(encoding="utf-8"))
        for line_number, line in enumerate(text.splitlines(), start=1):
            for match in token_re.finditer(line):
                if error := backticked_source_path_error(
                    rel_doc,
                    line_number,
                    match.group(1),
                    checked_roots,
                    root_files,
                    generated_residue_names,
                    source_location_re,
                ):
                    errors.append(error)
    return errors


# pylint: disable-next=too-many-arguments,too-many-positional-arguments
def backticked_source_path_error(
    rel_doc: Path,
    line_number: int,
    raw_token: str,
    checked_roots: tuple[str, ...],
    root_files: set[str],
    generated_residue_names: set[str],
    source_location_re: re.Pattern[str],
) -> str | None:
    """Describe an invalid backticked source path for the docs verifier."""
    token = raw_token.strip()
    if is_non_source_path_token(token):
        return None

    source_location_match = source_location_re.match(token)
    path_token = source_location_match.group(1) if source_location_match else token
    if Path(path_token).name in generated_residue_names:
        return None
    if not (path_token.startswith(checked_roots) or path_token in root_files):
        return None
    if (ROOT / path_token).exists():
        return None
    return f"{rel_doc}:{line_number}: backticked source path does not exist: {token}"


def is_non_source_path_token(token: str) -> bool:
    """Reject backticked tokens that cannot denote one concrete repository path."""
    return (
        not token
        or " " in token
        or "*" in token
        or token.startswith(("-", "<", "$"))
        or token.endswith("/")
    )


def check_required_topics(docs: list[Path]) -> list[str]:
    """Evaluate required topics and return precise contract violations."""
    corpus = "\n".join(path.read_text(encoding="utf-8") for path in docs).lower()
    return [
        f"required topic missing: {topic}"
        for topic in REQUIRED_TOPICS
        if topic.lower() not in corpus
    ]


def markdown_h2_headings(path: Path) -> list[str]:
    """Read second-level Markdown headings used by architecture-doc contracts."""
    text = path.read_text(encoding="utf-8")
    return re.findall(r"^## (.+)$", text, flags=re.MULTILINE)


def check_public_planning_contract() -> list[str]:
    """Evaluate public planning contract and return precise contract violations."""
    errors: list[str] = []
    docs: list[Path] = []
    for rel_path in PUBLIC_PLANNING_DOCS:
        path = ROOT / rel_path
        if not path.is_file():
            errors.append(f"missing public planning doc: {rel_path}")
            continue
        docs.append(path)

    text_by_path = {
        path.relative_to(ROOT).as_posix(): path.read_text(encoding="utf-8")
        for path in docs
    }
    corpus = "\n".join(text_by_path.values())
    lower_corpus = corpus.lower()
    for token in PUBLIC_PLANNING_REQUIRED_TOKENS:
        if token.lower() not in lower_corpus:
            errors.append(f"public planning docs missing required token: {token}")

    errors.extend(public_planning_text_errors(text_by_path))
    errors.extend(public_architecture_doc_errors(text_by_path))
    return errors


def public_planning_text_errors(text_by_path: dict[str, str]) -> list[str]:
    """Collect public-document wording that violates the release policy."""
    errors: list[str] = []
    for rel_path, text in text_by_path.items():
        if "VERDICT: PARTIAL" not in text:
            errors.append(f"{rel_path}: missing VERDICT: PARTIAL")
        for token in PUBLIC_PLANNING_FORBIDDEN_TOKENS:
            if token in text:
                errors.append(f"{rel_path}: public planning docs contain forbidden token: {token}")
        for token in PUBLIC_ACTIVE_STALE_REFERENCES:
            if token in text:
                errors.append(f"{rel_path}: active public docs contain stale reference: {token}")
    return errors


def public_architecture_doc_errors(text_by_path: dict[str, str]) -> list[str]:
    """Collect public-document wording that violates the release policy."""
    errors: list[str] = []
    for rel_path in PUBLIC_ARCHITECTURE_DOCS:
        path = ROOT / rel_path
        if not path.is_file():
            continue
        text = text_by_path.get(rel_path, path.read_text(encoding="utf-8"))
        headings = markdown_h2_headings(path)
        if PUBLIC_EVIDENCE_LABEL_HEADING not in headings:
            errors.append(
                f"{rel_path}: missing public architecture section: "
                f"{PUBLIC_EVIDENCE_LABEL_HEADING}"
            )
        if not any(label in text for label in PUBLIC_EVIDENCE_LABELS):
            errors.append(f"{rel_path}: missing public evidence label")

    return errors


def check_manual_input_markers(docs: list[Path]) -> list[str]:
    """Evaluate explicit manual-input markers and return contract violations."""
    errors: list[str] = []
    for path in docs:
        text = path.read_text(encoding="utf-8")
        for line_number, line in enumerate(text.splitlines(), start=1):
            if not line.lstrip().startswith("- Input required:"):
                continue
            if "->" not in line or line.count("->") < 2:
                errors.append(
                    f"{path.relative_to(ROOT)}:{line_number}: "
                    "manual-input marker must use ASCII '->' separators"
                )
    return errors
