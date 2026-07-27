#!/usr/bin/env python3
"""Verify concise, reader-facing purpose comments on first-party source files.

The release gate keeps code navigation useful without prescribing verbose prose:
public Python declarations and shell helpers must explain their contract, while
top-level Swift public declarations use Swift's native documentation-comment
syntax.
"""

from __future__ import annotations

import argparse
import ast
from collections.abc import Iterable
from pathlib import Path
import re
import tempfile


SOURCE_SUFFIXES = frozenset({".c", ".h", ".ps1", ".py", ".sh", ".swift"})
EXCLUDED_DIRECTORY_NAMES = frozenset(
    {
        ".build",
        ".git",
        ".pytest_cache",
        ".ruff_cache",
        ".venv",
        "__pycache__",
        "archive",
        "archives",
        "generated",
        "private",
        "privat",
        "third_party",
        "vendor",
        "vendors",
        "opus-1.5.2",
        "xs_ref_sw_ed2",
    }
)
SOURCE_ROOTS = ("Sources", "Tests", "linux_connector", "scripts")
COMMENT_PREFIXES = ("#", "//", "/*", "*", "*/")
TOOL_COMMENT_MARKERS = (
    "cppcheck",
    "hadolint",
    "noqa",
    "pylint",
    "shellcheck",
    "swiftformat",
    "swiftlint",
    "type: ignore",
)
LOW_INFORMATION_COMMENT_FRAGMENTS = (
    "at this module boundary",
    "behavior discoverable",
    "collects the caller-supplied settings that govern",
    "contracts required for reliable release validation",
    "contracts so release validation catches regressions",
    "evidence output, preserving a stable result shape for collection, validation, and json consumers",
    "input and data contracts, giving construction, persistence, and tests one authoritative shape",
    "isolating its stateful control loop from models, protocol details, and result validation",
    "maintained separately to narrow behavior changes and review",
    "owns the mutable runtime state required for",
    "performs the public",
    "propagate a structured result",
    "records the evidence produced while evaluating",
    "supplies implementation details, keeping the owning flow focused on its state transitions",
    "synthetic coverage, preventing fixture-specific behavior from entering the production path",
    "that owns this option",
    "wire data, giving packet codecs and transport code one shared representation",
    "within the benchmark pipeline, isolating this behavior from neighboring execution paths",
    "within the connector interoperability layer, isolating this behavior from neighboring execution paths",
)
LOW_INFORMATION_COMMENT_PATTERNS = (
    re.compile(r"\bcompare parity .+ while preserving repeatable local evidence\b"),
    re.compile(r"\bcontains the .+ implementation for .+, maintained separately to narrow behavior changes and review\b"),
    re.compile(r"\bcreate .+ from the module's validated inputs\b"),
    re.compile(r"\benumerates .+ choices used by\b"),
    re.compile(r"\blocate find\b"),
    re.compile(r"\bprovide .+ for callers of this module\b"),
    re.compile(r"\breject .+ that would violate the supported contract\b"),
    re.compile(r"\brequire require\b"),
    re.compile(r"\breturn whether is\b"),
    re.compile(r"\bsupplies .+ implementation details, keeping the owning flow focused on its state transitions\b"),
    re.compile(r"\bverify verify\b"),
)
SHELL_FUNCTION = re.compile(r"^(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{")
POWERSHELL_FUNCTION = re.compile(r"^\s*function\s+([A-Za-z][A-Za-z0-9-]*)\b", re.IGNORECASE)
SWIFT_DECLARATION_MODIFIERS = frozenset(
    {"public", "open", "package", "final", "indirect", "nonisolated", "distributed"}
)
SWIFT_DECLARATION_KINDS = frozenset({"class", "struct", "enum", "protocol", "actor", "typealias", "func"})
SWIFT_ACCESS_MODIFIERS = frozenset({"public", "open", "package"})
SWIFT_DECLARATION_METADATA_PREFIXES = ("@", "// swiftformat", "// swiftlint")


def is_first_party_source(path: Path, root: Path) -> bool:
    """Return whether *path* is an active, first-party source artifact."""
    try:
        relative_parts = path.relative_to(root).parts
    except ValueError:
        return False
    return (path.suffix in SOURCE_SUFFIXES or path.name == "Dockerfile") and not any(
        part in EXCLUDED_DIRECTORY_NAMES for part in relative_parts
    )


def source_files(root: Path) -> list[Path]:
    """List active source files in stable order for deterministic failures."""
    files: list[Path] = []
    for source_root in SOURCE_ROOTS:
        candidate = root / source_root
        if not candidate.is_dir():
            continue
        files.extend(
            path
            for path in candidate.rglob("*")
            if path.is_file() and is_first_party_source(path, root)
        )
    package_manifest = root / "Package.swift"
    if package_manifest.is_file():
        files.append(package_manifest)
    return sorted(files)


def first_content_line(lines: list[str]) -> int:
    """Skip interpreter and encoding metadata before checking a file header."""
    start = 0
    if lines and lines[0].startswith("#!"):
        start = 1
    if start < len(lines) and re.match(r"^#.*coding[:=]", lines[start]):
        start += 1
    while start < len(lines) and not lines[start].strip():
        start += 1
    return start


def is_low_information_comment(lower_text: str) -> bool:
    """Identify tool directives and known filler phrases that carry no contract."""
    return (
        any(marker in lower_text for marker in TOOL_COMMENT_MARKERS)
        or any(fragment in lower_text for fragment in LOW_INFORMATION_COMMENT_FRAGMENTS)
        or any(pattern.search(lower_text) for pattern in LOW_INFORMATION_COMMENT_PATTERNS)
    )


def has_substantive_comment_words(text: str) -> bool:
    """Require useful prose beyond incomplete-work markers."""
    words = re.findall(r"[A-Za-z][A-Za-z0-9'-]*", text)
    return len(" ".join(words)) >= 12 and any(word.lower() not in {"todo", "fixme"} for word in words)


def is_meaningful_comment(line: str) -> bool:
    """Require enough prose to distinguish a purpose from a delimiter or placeholder."""
    text = line.strip()
    if text.startswith("#!") or not text.startswith(COMMENT_PREFIXES):
        return False
    if is_low_information_comment(text.lower()):
        return False
    return has_substantive_comment_words(text)


def file_header_index(path: Path, lines: list[str]) -> int:
    """Locate the first potential purpose comment after required file metadata."""
    start = first_content_line(lines)
    if path.name != "Package.swift" or start >= len(lines):
        return start
    if not lines[start].startswith("// swift-tools-version:"):
        return start
    start += 1
    while start < len(lines) and not lines[start].strip():
        start += 1
    return start


def python_has_module_purpose(text: str) -> bool:
    """Return whether Python source parses and carries a useful module docstring."""
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return False
    return bool(ast.get_docstring(tree) and len(ast.get_docstring(tree) or "") >= 12)


def block_comment_purpose(lines: list[str], start: int) -> str | None:
    """Collect the bounded leading block comment used as a file purpose."""
    if not lines[start].lstrip().startswith("/*"):
        return None
    comment_lines: list[str] = []
    for line in lines[start : start + 8]:
        comment_lines.append(line)
        if "*/" in line:
            break
    return " ".join(comment_lines)


def has_file_purpose(path: Path, text: str) -> bool:
    """Return whether the leading source text communicates the file's purpose."""
    lines = text.splitlines()
    start = file_header_index(path, lines)
    if path.suffix == ".py":
        return python_has_module_purpose(text)
    if start >= len(lines):
        return False
    if is_meaningful_comment(lines[start]):
        return True
    comment = block_comment_purpose(lines, start)
    return comment is not None and is_meaningful_comment(comment)


def python_public_declaration_errors(path: Path, text: str) -> list[str]:
    """Report undocumented top-level Python API declarations outside test modules."""
    if "tests" in path.parts:
        return []
    try:
        tree = ast.parse(text)
    except SyntaxError as error:
        return [f"{path}: cannot parse Python source: {error.msg}"]
    errors: list[str] = []
    for node in tree.body:
        if not isinstance(node, (ast.AsyncFunctionDef, ast.ClassDef, ast.FunctionDef)):
            continue
        if node.name.startswith("_") or ast.get_docstring(node):
            continue
        errors.append(f"{path}:{node.lineno}: public Python declaration lacks a docstring")
    return errors


def previous_explanatory_line(lines: list[str], index: int) -> bool:
    """Return whether a shell helper has an adjacent explanatory comment."""
    previous = index - 1
    while previous >= 0 and not lines[previous].strip():
        previous -= 1
    return previous >= 0 and is_meaningful_comment(lines[previous])


def shell_function_errors(path: Path, text: str) -> list[str]:
    """Report shell functions whose calling contract lacks a nearby comment."""
    errors: list[str] = []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if SHELL_FUNCTION.match(line) and not previous_explanatory_line(lines, index):
            errors.append(f"{path}:{index + 1}: shell function lacks a preceding explanatory comment")
    return errors


def powershell_function_errors(path: Path, text: str) -> list[str]:
    """Report PowerShell helpers whose operational purpose lacks a nearby comment."""
    errors: list[str] = []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if POWERSHELL_FUNCTION.match(line) and not previous_explanatory_line(lines, index):
            errors.append(f"{path}:{index + 1}: PowerShell function lacks a preceding explanatory comment")
    return errors


def advance_swift_multiline_string(
    line: str,
    index: int,
    hash_count: int,
) -> tuple[int, int | None]:
    """Advance past a raw or ordinary multiline string delimiter when present."""
    delimiter = '"""' + ("#" * hash_count)
    closing = line.find(delimiter, index)
    if closing < 0:
        return len(line), hash_count
    return closing + len(delimiter), None


def advance_swift_block_comment(line: str, index: int, depth: int) -> tuple[int, int]:
    """Advance one lexical step while maintaining nested block-comment depth."""
    if line.startswith("/*", index):
        return index + 2, depth + 1
    if line.startswith("*/", index):
        return index + 2, depth - 1
    return index + 1, depth


def swift_single_line_string_end(line: str, start: int, hash_count: int) -> int:
    """Locate the end of one Swift string, honoring escapes for ordinary strings."""
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


def swift_string_advance(line: str, index: int) -> tuple[int, int | None] | None:
    """Return the next index and multiline state when a Swift string starts here."""
    hash_end = index
    while hash_end < len(line) and line[hash_end] == "#":
        hash_end += 1
    hash_count = hash_end - index
    if line.startswith('"""', hash_end):
        return hash_end + 3, hash_count
    if hash_end >= len(line) or line[hash_end] != '"':
        return None
    return swift_single_line_string_end(line, hash_end, hash_count), None


def swift_code_without_comments_or_strings(
    line: str,
    block_comment_depth: int,
    multiline_string_hashes: int | None,
) -> tuple[str, int, int | None]:
    """Return lexical Swift code while retaining cross-line comment/string state."""
    code: list[str] = []
    index = 0
    while index < len(line):
        if multiline_string_hashes is not None:
            index, multiline_string_hashes = advance_swift_multiline_string(
                line,
                index,
                multiline_string_hashes,
            )
            if multiline_string_hashes is not None:
                return "".join(code), block_comment_depth, multiline_string_hashes
            continue

        if block_comment_depth > 0:
            index, block_comment_depth = advance_swift_block_comment(
                line,
                index,
                block_comment_depth,
            )
            continue

        if line.startswith("//", index):
            break
        if line.startswith("/*", index):
            block_comment_depth = 1
            index += 2
            continue

        string_advance = swift_string_advance(line, index)
        if string_advance is not None:
            index, multiline_string_hashes = string_advance
            continue

        code.append(line[index])
        index += 1

    return "".join(code), block_comment_depth, multiline_string_hashes


def swift_declaration_modifiers(code: str) -> frozenset[str] | None:
    """Parse the modifiers that precede a supported top-level Swift declaration."""
    modifiers: list[str] = []
    for token in code.lstrip().split():
        if token in SWIFT_DECLARATION_MODIFIERS:
            modifiers.append(token)
            continue
        if token in SWIFT_DECLARATION_KINDS and modifiers:
            return frozenset(modifiers)
        return None
    return None


def swift_top_level_public_declarations(text: str) -> list[int]:
    """Return zero-based line indexes for supported top-level public declarations."""
    declaration_lines: list[int] = []
    brace_depth = 0
    block_comment_depth = 0
    multiline_string_hashes: int | None = None
    for index, line in enumerate(text.splitlines()):
        code, block_comment_depth, multiline_string_hashes = swift_code_without_comments_or_strings(
            line,
            block_comment_depth,
            multiline_string_hashes,
        )
        modifiers = swift_declaration_modifiers(code)
        if brace_depth == 0 and modifiers and modifiers & SWIFT_ACCESS_MODIFIERS:
            declaration_lines.append(index)
        brace_depth += code.count("{") - code.count("}")
        brace_depth = max(0, brace_depth)
    return declaration_lines


def swift_doc_comment_before(lines: list[str], declaration_index: int) -> str | None:
    """Return a contiguous DocC block before declaration metadata, if present."""
    previous = declaration_index - 1
    while previous >= 0 and lines[previous].strip().startswith(
        SWIFT_DECLARATION_METADATA_PREFIXES
    ):
        previous -= 1
    if previous < 0 or not lines[previous].lstrip().startswith("///"):
        return None

    doc_lines: list[str] = []
    while previous >= 0 and lines[previous].lstrip().startswith("///"):
        doc_lines.append(lines[previous])
        previous -= 1
    return " ".join(reversed(doc_lines))


def swift_public_declaration_errors(path: Path, text: str) -> list[str]:
    """Report public Swift declarations without a meaningful preceding doc comment."""
    errors: list[str] = []
    lines = text.splitlines()
    for index in swift_top_level_public_declarations(text):
        doc_comment = swift_doc_comment_before(lines, index)
        if doc_comment is None:
            errors.append(f"{path}:{index + 1}: public Swift declaration lacks a preceding /// comment")
        elif not is_meaningful_comment(doc_comment):
            errors.append(
                f"{path}:{index + 1}: public Swift declaration has a non-explanatory /// comment"
            )
    return errors


def documentation_errors(root: Path) -> list[str]:
    """Collect sorted source-documentation failures for the repository gate."""
    errors: list[str] = []
    for path in source_files(root):
        text = path.read_text(encoding="utf-8")
        relative_path = path.relative_to(root)
        if not has_file_purpose(path, text):
            errors.append(f"{relative_path}: missing a concise file-purpose header")
        if path.suffix == ".py":
            errors.extend(python_public_declaration_errors(relative_path, text))
        elif path.suffix == ".sh":
            errors.extend(shell_function_errors(relative_path, text))
        elif path.suffix == ".ps1":
            errors.extend(powershell_function_errors(relative_path, text))
        elif path.suffix == ".swift":
            errors.extend(swift_public_declaration_errors(relative_path, text))
    return sorted(errors)


def write_fixture(root: Path, relative_path: str, content: str) -> None:
    """Write one self-test fixture after creating its isolated parent directory."""
    path = root / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def write_script_documentation_fixtures(root: Path) -> None:
    """Create Python, shell, PowerShell, and Dockerfile documentation fixtures."""
    write_fixture(
        root,
        "scripts/good.py",
        (
            '"""Expose a documented helper for deterministic tests."""\n\n'
            "def render() -> str:\n"
            '    """Return the fixed value used by this verifier fixture."""\n'
            '    return "ok"\n'
        ),
    )
    write_fixture(root, "scripts/bad.sh", "#!/usr/bin/env bash\nrun() {\n  :\n}\n")
    write_fixture(
        root,
        "scripts/directive-only.sh",
        "# Run the documented shell fixture.\n# shellcheck disable=SC2034\nrun() {\n  :\n}\n",
    )
    write_fixture(
        root,
        "linux_connector/deployment/wsl/bad.ps1",
        (
            "# Apply a documented Windows fixture configuration.\n"
            "function Apply-Fixture {\n  $null = $true\n}\n"
        ),
    )
    write_fixture(root, "scripts/Dockerfile", "# Build the documented local fixture image.\nFROM scratch\n")
    write_fixture(root, "linux_connector/Dockerfile", "FROM scratch\n# hadolint ignore=DL3008\n")


def write_swift_documentation_fixtures(root: Path) -> None:
    """Create Swift fixtures for public declarations and documentation directives."""
    write_fixture(
        root,
        "Package.swift",
        (
            "// swift-tools-version: 6.0\n"
            "// Define the package products used by the alpha release build.\n"
        ),
    )
    write_fixture(
        root,
        "Tests/DocumentedTests.swift",
        (
            "// Exercise the documented source gate from the Swift test target.\n"
            "/// Expose a documented fixture type for parser coverage.\n"
            "public struct DocumentedFixture {}\n"
        ),
    )
    write_fixture(
        root,
        "Tests/DirectiveOnlyTests.swift",
        (
            "// Exercise rejection of tool directives used as public API documentation.\n"
            "/// swiftlint:disable:next type_name\n"
            "public struct DirectiveOnlyFixture {}\n"
        ),
    )
    write_fixture(
        root,
        "Tests/LowInformationTests.swift",
        (
            "// Exercise rejection of generated filler used as public API documentation.\n"
            "/// Represents LowInformationFixture at this module boundary.\n"
            "public struct LowInformationFixture {}\n"
            "/// Enumerates RegexFixture choices used by parser tests.\n"
            "public enum RegexFixture {}\n"
        ),
    )


def write_swift_scope_fixture(root: Path) -> None:
    """Create the Swift fixture that exercises comments, strings, scope, and attributes."""
    write_fixture(
        root,
        "Tests/SwiftScopeTests.swift",
        (
            "// Exercise top-level Swift declaration and DocC adjacency rules.\n"
            "/// Describes an indented top-level declaration accepted by the source gate.\n"
            "    public struct IndentedTopLevelFixture {}\n"
            "private extension String {\n"
            "public struct NestedFixture {}\n"
            "public static func nestedMemberFixture() {}\n"
            "}\n"
            'let stringFixture = """\n'
            "public struct StringLiteralFixture {\n"
            "}\n"
            '"""\n'
            "/* public struct BlockCommentFixture {} */\n"
            "/// Describes an attributed top-level declaration accepted by the source gate.\n"
            "@available(macOS 14, *)\n"
            "public struct AttributedFixture {}\n"
            "/// Describes a declaration whose modifier order remains parser-independent.\n"
            "final public class ModifierOrderFixture {}\n"
            "/// This documentation is deliberately separated from its declaration.\n"
            "\n"
            "public struct SeparatedFixture {}\n"
        ),
    )
    write_fixture(root, "Sources/opus-1.5.2/ignored.swift", "public struct IgnoredFixture {}\n")


def self_test() -> int:
    """Exercise missing-header and documented-source cases without repository state."""
    with tempfile.TemporaryDirectory() as temporary_directory:
        root = Path(temporary_directory)
        write_script_documentation_fixtures(root)
        write_swift_documentation_fixtures(root)
        write_swift_scope_fixture(root)
        errors = documentation_errors(root)
        discovered = {path.relative_to(root).as_posix() for path in source_files(root)}
    expected = [
        "Tests/DirectiveOnlyTests.swift:3: public Swift declaration has a non-explanatory /// comment",
        "Tests/LowInformationTests.swift:3: public Swift declaration has a non-explanatory /// comment",
        "Tests/LowInformationTests.swift:5: public Swift declaration has a non-explanatory /// comment",
        "Tests/SwiftScopeTests.swift:20: public Swift declaration lacks a preceding /// comment",
        "linux_connector/Dockerfile: missing a concise file-purpose header",
        "scripts/bad.sh: missing a concise file-purpose header",
        "scripts/bad.sh:2: shell function lacks a preceding explanatory comment",
        "scripts/directive-only.sh:3: shell function lacks a preceding explanatory comment",
    ]
    required = {
        "Package.swift",
        "Tests/DocumentedTests.swift",
        "linux_connector/deployment/wsl/bad.ps1",
        "scripts/Dockerfile",
        "scripts/good.py",
    }
    if not required <= discovered or "Sources/opus-1.5.2/ignored.swift" in discovered:
        print("self-test failed: source boundary discovery is incorrect")
        return 1
    if errors != expected:
        print("self-test failed:", *errors, sep="\n")
        return 1
    print("source-documentation self-test passed")
    return 0


def parse_args(arguments: Iterable[str] | None = None) -> argparse.Namespace:
    """Parse the optional self-test flag without expanding the release interface."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="validate the verifier against temporary fixtures")
    return parser.parse_args(arguments)


def main(arguments: Iterable[str] | None = None) -> int:
    """Run source-documentation validation and print exact actionable failures."""
    if parse_args(arguments).self_test:
        return self_test()
    errors = documentation_errors(Path(__file__).resolve().parents[1])
    if errors:
        print("Source documentation verification failed:")
        print("\n".join(errors))
        return 1
    print("Source documentation verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
