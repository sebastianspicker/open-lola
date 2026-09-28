"""Scan top-level Swift declarations for adjacent explanatory DocC comments."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

SWIFT_DECLARATION_MODIFIERS = frozenset(
    {"public", "open", "package", "final", "indirect", "nonisolated", "distributed"}
)
SWIFT_DECLARATION_KINDS = frozenset(
    {"class", "struct", "enum", "protocol", "actor", "typealias", "func"}
)
SWIFT_ACCESS_MODIFIERS = frozenset({"public", "open", "package"})
SWIFT_DECLARATION_METADATA_PREFIXES = ("@", "// swiftformat", "// swiftlint")


def _advance_multiline_string(line: str, index: int, hash_count: int) -> tuple[int, int | None]:
    """Advance past a raw or ordinary multiline string delimiter when present."""
    delimiter = '"""' + ("#" * hash_count)
    closing = line.find(delimiter, index)
    if closing < 0:
        return len(line), hash_count
    return closing + len(delimiter), None


def _advance_block_comment(line: str, index: int, depth: int) -> tuple[int, int]:
    """Advance one lexical step while maintaining nested block-comment depth."""
    if line.startswith("/*", index):
        return index + 2, depth + 1
    if line.startswith("*/", index):
        return index + 2, depth - 1
    return index + 1, depth


def _single_line_string_end(line: str, start: int, hash_count: int) -> int:
    """Locate the end of one Swift string, honoring ordinary-string escapes."""
    delimiter = '"' + ("#" * hash_count)
    cursor = start + 1
    while cursor < len(line):
        if hash_count == 0 and line[cursor] == "\\":
            cursor += 2
            continue
        if line.startswith(delimiter, cursor):
            return cursor + len(delimiter)
        cursor += 1
    return cursor


def _string_advance(line: str, index: int) -> tuple[int, int | None] | None:
    """Return the next index and multiline state when a Swift string starts."""
    hash_end = index
    while hash_end < len(line) and line[hash_end] == "#":
        hash_end += 1
    hash_count = hash_end - index
    if line.startswith('"""', hash_end):
        return hash_end + 3, hash_count
    if hash_end >= len(line) or line[hash_end] != '"':
        return None
    return _single_line_string_end(line, hash_end, hash_count), None


def _code_without_comments_or_strings(
    line: str,
    block_comment_depth: int,
    multiline_string_hashes: int | None,
) -> tuple[str, int, int | None]:
    """Return lexical Swift code while retaining cross-line scanner state."""
    code: list[str] = []
    index = 0
    while index < len(line):
        if multiline_string_hashes is not None:
            index, multiline_string_hashes = _advance_multiline_string(
                line, index, multiline_string_hashes
            )
            if multiline_string_hashes is not None:
                return "".join(code), block_comment_depth, multiline_string_hashes
            continue
        if block_comment_depth > 0:
            index, block_comment_depth = _advance_block_comment(line, index, block_comment_depth)
            continue
        if line.startswith("//", index):
            break
        if line.startswith("/*", index):
            block_comment_depth = 1
            index += 2
            continue
        string_advance = _string_advance(line, index)
        if string_advance is not None:
            index, multiline_string_hashes = string_advance
            continue
        code.append(line[index])
        index += 1
    return "".join(code), block_comment_depth, multiline_string_hashes


def _declaration_modifiers(code: str) -> frozenset[str] | None:
    """Parse modifiers that precede a supported top-level declaration."""
    modifiers: list[str] = []
    for token in code.lstrip().split():
        if token in SWIFT_DECLARATION_MODIFIERS:
            modifiers.append(token)
            continue
        if token in SWIFT_DECLARATION_KINDS and modifiers:
            return frozenset(modifiers)
        return None
    return None


def _top_level_public_declarations(text: str) -> list[int]:
    """Return zero-based line indexes for supported public declarations."""
    declaration_lines: list[int] = []
    brace_depth = 0
    block_comment_depth = 0
    multiline_string_hashes: int | None = None
    for index, line in enumerate(text.splitlines()):
        code, block_comment_depth, multiline_string_hashes = _code_without_comments_or_strings(
            line, block_comment_depth, multiline_string_hashes
        )
        modifiers = _declaration_modifiers(code)
        if brace_depth == 0 and modifiers and modifiers & SWIFT_ACCESS_MODIFIERS:
            declaration_lines.append(index)
        brace_depth = max(0, brace_depth + code.count("{") - code.count("}"))
    return declaration_lines


def _doc_comment_before(lines: list[str], declaration_index: int) -> str | None:
    """Return a contiguous DocC block before declaration metadata."""
    previous = declaration_index - 1
    while previous >= 0 and lines[previous].strip().startswith(SWIFT_DECLARATION_METADATA_PREFIXES):
        previous -= 1
    if previous < 0 or not lines[previous].lstrip().startswith("///"):
        return None
    doc_lines: list[str] = []
    while previous >= 0 and lines[previous].lstrip().startswith("///"):
        doc_lines.append(lines[previous])
        previous -= 1
    return " ".join(reversed(doc_lines))


def public_declaration_errors(
    path: Path,
    text: str,
    is_meaningful_comment: Callable[[str], bool],
) -> list[str]:
    """Report public Swift declarations without a meaningful DocC comment."""
    errors: list[str] = []
    lines = text.splitlines()
    for index in _top_level_public_declarations(text):
        doc_comment = _doc_comment_before(lines, index)
        if doc_comment is None:
            errors.append(f"{path}:{index + 1}: public Swift declaration lacks a preceding /// comment")
        elif not is_meaningful_comment(doc_comment):
            errors.append(f"{path}:{index + 1}: public Swift declaration has a non-explanatory /// comment")
    return errors
