#!/usr/bin/env python3
"""Enforce first-party line, complexity, and reviewed-duplication budgets."""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import shutil
import subprocess
import tempfile
from bisect import bisect_right
from collections import defaultdict
from collections.abc import Iterable, Sequence
from pathlib import Path
from typing import Any
from unittest.mock import patch

from lizard import FileAnalyzer  # type: ignore[import-untyped]
from lizard_ext.lizardduplicate import (  # type: ignore[import-untyped]
    DuplicateFinder,
    LizardExtension,
    NestingStackWithUnifiedTokens,
)

MAX_PHYSICAL_LINES = 600
MAX_CCN = 19
MIN_DUPLICATE_TOKENS = 70
EXCEPTION_FILE = Path("tools/code-line-budget-exceptions.txt")
DUPLICATION_BASELINE = Path("tools/code-duplication-baseline.json")
DUPLICATION_SCHEMA = "open-lola.normalized-token-duplication/v1"
DUPLICATION_TOOL = {
    "name": "lizard_ext.lizardduplicate",
    "lizardVersion": "1.24.0",
    "extensionVersion": 1,
    "minimumTokens": MIN_DUPLICATE_TOKENS,
    "normalization": "LizardExtension unified identifiers and constants;sample-hash sequences",
}
SOURCE_SUFFIXES = frozenset(
    {
        ".bash",
        ".c",
        ".cjs",
        ".css",
        ".h",
        ".html",
        ".js",
        ".jsx",
        ".mjs",
        ".ps1",
        ".py",
        ".rs",
        ".sh",
        ".svg",
        ".swift",
        ".ts",
        ".tsx",
        ".zsh",
    }
)
LIZARD_SUFFIXES = frozenset({".c", ".cjs", ".h", ".js", ".jsx", ".mjs", ".py", ".rs", ".swift", ".ts", ".tsx"})
SHELL_SUFFIXES = frozenset({".bash", ".sh", ".zsh"})
EXCLUDED_PARTS = frozenset(
    {
        ".build",
        ".repowise",
        "archive",
        "archives",
        "build",
        "dist",
        "generated",
        "private",
        "privat",
        "vendor",
        "vendors",
    }
)


def is_first_party_source(relative_path: Path) -> bool:
    """Return whether a path belongs to the maintained executable-source surface."""
    path = relative_path.as_posix()
    if relative_path.suffix.lower() not in SOURCE_SUFFIXES or any(
        part in EXCLUDED_PARTS for part in relative_path.parts
    ):
        return False
    if relative_path.parts and relative_path.parts[0] == "interop":
        return False
    return not path.startswith("third_party/") or path.startswith("third_party/opus/openlola_bridge/")


def repository_source_files(root: Path) -> list[Path]:
    """Build the single stable manifest used by every code-quality check."""
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return sorted(
        relative
        for raw_path in result.stdout.split(b"\0")
        if raw_path
        for relative in [Path(raw_path.decode("utf-8"))]
        if is_first_party_source(relative) and (root / relative).is_file()
    )


def line_budget_exceptions(root: Path, source_files: set[Path]) -> tuple[dict[Path, int], list[str]]:
    """Parse the audited line-budget escape hatch and reject stale entries."""
    exceptions: dict[Path, int] = {}
    errors: list[str] = []
    exception_path = root / EXCEPTION_FILE
    for line_number, raw_line in enumerate(exception_path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        fields = [field.strip() for field in line.split("|", 2)]
        if len(fields) != 3 or not all(fields):
            errors.append(f"{EXCEPTION_FILE}:{line_number}: expected path|max_lines|reason")
            continue
        relative = Path(fields[0])
        if relative in exceptions:
            errors.append(f"{EXCEPTION_FILE}:{line_number}: duplicate exception for {relative}")
            continue
        try:
            maximum = int(fields[1])
        except ValueError:
            errors.append(f"{EXCEPTION_FILE}:{line_number}: max_lines must be an integer")
            continue
        if maximum <= MAX_PHYSICAL_LINES:
            errors.append(f"{EXCEPTION_FILE}:{line_number}: exception maximum must exceed {MAX_PHYSICAL_LINES}")
        elif relative not in source_files:
            errors.append(f"{EXCEPTION_FILE}:{line_number}: stale or out-of-scope path {relative}")
        else:
            exceptions[relative] = maximum
    return exceptions, errors


def physical_line_count(path: Path) -> int:
    """Count physical text lines, including a final unterminated line."""
    data = path.read_bytes()
    return data.count(b"\n") + int(bool(data) and not data.endswith(b"\n"))


def line_budget_errors(root: Path, source_files: list[Path]) -> list[str]:
    """Report oversized sources and invalid audited exceptions."""
    exceptions, errors = line_budget_exceptions(root, set(source_files))
    for relative in source_files:
        maximum = exceptions.get(relative, MAX_PHYSICAL_LINES)
        actual = physical_line_count(root / relative)
        if actual > maximum:
            errors.append(f"{relative}: {actual} physical lines exceeds maximum {maximum}")
    return sorted(errors)


def lizard_groups(source_files: Iterable[Path]) -> dict[str, list[Path]]:
    """Partition the manifest by Lizard parser, including the deliberate shell C parser."""
    groups: dict[str, list[Path]] = {"default": [], "cpp": []}
    for relative in source_files:
        suffix = relative.suffix.lower()
        if suffix in LIZARD_SUFFIXES:
            groups["default"].append(relative)
        elif suffix in SHELL_SUFFIXES:
            groups["cpp"].append(relative)
    return {name: paths for name, paths in groups.items() if paths}


def run_lizard_group(
    executable: str,
    root: Path,
    parser: str,
    source_files: list[Path],
    *,
    quiet: bool = False,
) -> int:
    """Run one Lizard parser over explicit paths so it cannot expand outside the manifest."""
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", prefix="open-lola-lizard-", delete=False) as manifest:
        manifest_path = Path(manifest.name)
        manifest.writelines(f"{path.as_posix()}\n" for path in source_files)
    try:
        command = [executable, "-C", str(MAX_CCN), "-w", "-f", str(manifest_path)]
        if parser == "cpp":
            command.extend(["-l", "cpp"])
        return subprocess.run(command, cwd=root, check=False, capture_output=quiet).returncode
    finally:
        manifest_path.unlink(missing_ok=True)


def run_lizard(root: Path, source_files: list[Path]) -> int:
    """Run pinned Lizard, treating shell syntax explicitly with its C-like parser."""
    executable = shutil.which("lizard")
    if executable is None:
        print("code quality failed: pinned Lizard executable is unavailable")
        return 1
    return max(
        run_lizard_group(executable, root, parser, paths) for parser, paths in lizard_groups(source_files).items()
    )


def duplicate_fingerprint(tokens: list[str]) -> str:
    """Return the stable fingerprint for one maximal normalized clone."""
    return hashlib.sha256("\0".join(tokens).encode("utf-8")).hexdigest()


def duplication_entries(root: Path, source_files: list[Path]) -> list[dict[str, Any]]:
    """Find maximal Lizard-normalized cross-file clones from the canonical manifest."""
    extension = LizardExtension()
    analyzer = FileAnalyzer([extension])
    fileinfos = [analyzer(str(root / relative)) for relative in source_files]
    list(extension.cross_file_process(fileinfos))
    boundaries = [offset for offset, _ in extension.fileinfos]
    finder = DuplicateFinder(
        extension.nodes,
        boundaries,
        min_duplicate_tokens=MIN_DUPLICATE_TOKENS,
        sample_size=NestingStackWithUnifiedTokens.SAMPLE_SIZE,
    )
    clones: dict[str, dict[tuple[str, int], int]] = defaultdict(dict)
    for ranges in finder.find_start_and_ends():
        locations: list[tuple[str, int, int]] = []
        for start, end in ranges:
            file_index = bisect_right(boundaries, start) - 1
            path = Path(extension.fileinfos[file_index][1].filename).relative_to(root).as_posix()
            relative_start = start - boundaries[file_index]
            locations.append((path, relative_start, end - start + NestingStackWithUnifiedTokens.SAMPLE_SIZE))
        paths = sorted({path for path, _, _ in locations})
        if len(paths) > 1:
            start, end = ranges[0]
            normalized = [
                node.hash for node in extension.nodes[start : end + NestingStackWithUnifiedTokens.SAMPLE_SIZE]
            ]
            fingerprint = duplicate_fingerprint(normalized)
            for path, relative_start, length in locations:
                location = (path, relative_start)
                clones[fingerprint][location] = max(clones[fingerprint].get(location, 0), length)
    return [
        {
            "fingerprint": fingerprint,
            "occurrences": len(locations),
            "paths": sorted({path for path, _ in locations}),
            "coveredTokens": sum(locations.values()),
        }
        for fingerprint, locations in sorted(clones.items())
    ]


def current_duplication_baseline(root: Path, source_files: list[Path]) -> dict[str, Any]:
    """Build the reviewable baseline representation without writing a repository file."""
    entries = duplication_entries(root, source_files)
    paths = sorted({path for entry in entries for path in entry["paths"]})
    indexes = {path: index for index, path in enumerate(paths)}
    fingerprints = {
        str(entry["fingerprint"]): [
            entry["occurrences"],
            [indexes[path] for path in entry["paths"]],
            entry["coveredTokens"],
        ]
        for entry in entries
    }
    return {
        "schema": DUPLICATION_SCHEMA,
        "tool": DUPLICATION_TOOL,
        "entrySchema": ["occurrences", "pathIndexes", "coveredTokens"],
        "paths": paths,
        "fingerprints": fingerprints,
        "coveredTokens": sum(int(entry["coveredTokens"]) for entry in entries),
    }


def read_duplication_baseline(root: Path) -> tuple[dict[str, Any] | None, list[str]]:
    """Read the checked-in baseline and reject malformed or tool-drifted data."""
    path = root / DUPLICATION_BASELINE
    try:
        baseline = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return None, [f"{DUPLICATION_BASELINE}: unreadable baseline: {error}"]
    if not isinstance(baseline, dict):
        return None, [f"{DUPLICATION_BASELINE}: baseline must be a JSON object"]
    errors: list[str] = []
    if baseline.get("schema") != DUPLICATION_SCHEMA:
        errors.append(f"{DUPLICATION_BASELINE}: schema drift")
    if baseline.get("tool") != DUPLICATION_TOOL:
        errors.append(f"{DUPLICATION_BASELINE}: tool drift")
    fingerprints = baseline.get("fingerprints")
    paths = baseline.get("paths")
    if baseline.get("entrySchema") != ["occurrences", "pathIndexes", "coveredTokens"]:
        errors.append(f"{DUPLICATION_BASELINE}: fingerprint entry schema drift")
    if not isinstance(paths, list) or paths != sorted(set(paths)) or not all(isinstance(path, str) for path in paths):
        errors.append(f"{DUPLICATION_BASELINE}: paths must be a sorted unique string list")
    if not isinstance(fingerprints, dict) or not all(
        isinstance(entry, list) and len(entry) == 3 for entry in fingerprints.values()
    ):
        errors.append(f"{DUPLICATION_BASELINE}: fingerprints must be an object")
    elif baseline.get("coveredTokens") != sum(entry[2] for entry in fingerprints.values()):
        errors.append(f"{DUPLICATION_BASELINE}: coveredTokens does not match fingerprints")
    return baseline, errors


def decoded_fingerprint_entries(baseline: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Expand compact reviewed entries before comparing paths, counts, and coverage."""
    paths = baseline["paths"]
    return {
        fingerprint: {
            "occurrences": values[0],
            "paths": [paths[index] for index in values[1]],
            "coveredTokens": values[2],
        }
        for fingerprint, values in baseline["fingerprints"].items()
    }


def duplication_errors(root: Path, source_files: list[Path]) -> list[str]:
    """Reject new, larger, stale, or baseline-tool-drifted clone debt."""
    baseline, errors = read_duplication_baseline(root)
    if baseline is None or errors:
        return errors
    current = current_duplication_baseline(root, source_files)
    old_entries = decoded_fingerprint_entries(baseline)
    new_entries = decoded_fingerprint_entries(current)
    for fingerprint in sorted(new_entries.keys() - old_entries.keys()):
        errors.append(f"duplication new: {fingerprint}")
    for fingerprint in sorted(old_entries.keys() - new_entries.keys()):
        errors.append(f"duplication stale: {fingerprint}")
    for fingerprint in sorted(old_entries.keys() & new_entries.keys()):
        previous, live = old_entries[fingerprint], new_entries[fingerprint]
        if previous["paths"] != live["paths"]:
            errors.append(f"duplication stale paths: {fingerprint}")
        if previous["occurrences"] != live["occurrences"]:
            errors.append(f"duplication stale occurrences: {fingerprint}")
        if int(previous["coveredTokens"]) < int(live["coveredTokens"]):
            errors.append(f"duplication growth: {fingerprint}")
        elif int(previous["coveredTokens"]) > int(live["coveredTokens"]):
            errors.append(f"duplication stale coverage: {fingerprint}")
    return errors


def write_fixture(path: Path, token: str, repeats: int = MIN_DUPLICATE_TOKENS) -> None:
    """Write one controlled token stream for the verifier's isolated self-test."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(" ".join([token] * repeats) + "\n", encoding="utf-8")


class SelfTestFailure(Exception):
    """Identify one isolated verifier contract that did not hold."""


def require_self_test(condition: bool, message: str) -> None:
    """Raise a labelled fixture failure when a verifier invariant is false."""
    if not condition:
        raise SelfTestFailure(message)


def manifest_self_test() -> None:
    """Lock the intentional first-party include and exclusion boundary."""
    included = {
        Path("tools/check.sh"),
        Path("web/demo/app.js"),
        Path("third_party/opus/openlola_bridge/bridge.c"),
    }
    excluded = {
        Path("interop/lola2/case.py"),
        Path("archive/old.swift"),
        Path("generated/result.ts"),
        Path("third_party/opus/celt/upstream.c"),
    }
    require_self_test(all(is_first_party_source(path) for path in included), "included manifest path")
    require_self_test(not any(is_first_party_source(path) for path in excluded), "excluded manifest path")
    groups = lizard_groups([Path("tools/check.sh"), Path("runtimes/rust-station/src/main.rs")])
    require_self_test(
        groups
        == {
            "default": [Path("runtimes/rust-station/src/main.rs")],
            "cpp": [Path("tools/check.sh")],
        },
        "Lizard parser routing",
    )


def line_budget_self_test(root: Path) -> None:
    """Exercise the inclusive 600-line boundary and rejecting 601-line case."""
    source = Path("boundary.py")
    exception_path = root / EXCEPTION_FILE
    exception_path.parent.mkdir(parents=True)
    exception_path.write_text("# no exceptions\n", encoding="utf-8")
    (root / source).write_text("value = 1\n" * MAX_PHYSICAL_LINES, encoding="utf-8")
    require_self_test(not line_budget_errors(root, [source]), "600 physical lines")
    (root / source).write_text("value = 1\n" * (MAX_PHYSICAL_LINES + 1), encoding="utf-8")
    require_self_test(
        any("601 physical lines" in error for error in line_budget_errors(root, [source])),
        "601 physical lines",
    )


def branch_source(language: str, branch_count: int) -> str:
    """Build one boundary fixture for the selected Lizard parser."""
    if language == "python":
        lines = ["def decision(value):"]
        lines.extend(f"    if value == {index}: return {index}" for index in range(branch_count))
        return "\n".join([*lines, "    return -1", ""])
    lines = ["decision() {"]
    if language == "shell-case":
        lines.append('  case "$1" in')
        lines.extend(("    yes) : ;;", "    no) : ;;"))
        lines.append("  esac")
        lines.extend("  if true; then :; fi" for _ in range(branch_count))
    elif language == "shell-loop":
        lines.extend("  while true; do :; done" for _ in range(branch_count))
    else:
        lines.extend("  if true; then :; fi" for _ in range(branch_count))
    return "\n".join([*lines, "}", ""])


def lizard_boundary_self_test(root: Path) -> None:
    """Lock CCN 19/20 and the explicit shell C-family parsing behavior."""
    executable = shutil.which("lizard")
    if executable is None:
        raise SelfTestFailure("pinned Lizard fixture dependency")
    cases = (
        (Path("ccn19.py"), "default", branch_source("python", MAX_CCN - 1), 0),
        (Path("ccn20.py"), "default", branch_source("python", MAX_CCN), 1),
        (Path("shell-if-ccn19.sh"), "cpp", branch_source("shell-if", MAX_CCN - 1), 0),
        (Path("shell-if-ccn20.sh"), "cpp", branch_source("shell-if", MAX_CCN), 1),
        (Path("shell-case-ccn19.sh"), "cpp", branch_source("shell-case", MAX_CCN - 2), 0),
        (Path("shell-case-ccn20.sh"), "cpp", branch_source("shell-case", MAX_CCN - 1), 1),
        (Path("shell-loop-ccn19.sh"), "cpp", branch_source("shell-loop", MAX_CCN - 1), 0),
        (Path("shell-loop-ccn20.sh"), "cpp", branch_source("shell-loop", MAX_CCN), 1),
    )
    for relative, parser, source, expected_status in cases:
        (root / relative).write_text(source, encoding="utf-8")
        status = run_lizard_group(executable, root, parser, [relative], quiet=True)
        require_self_test(status == expected_status, relative.name)
    with (
        patch.object(shutil, "which", return_value=None),
        contextlib.redirect_stdout(io.StringIO()),
    ):
        require_self_test(run_lizard(root, [Path("ccn19.py")]) == 1, "missing Lizard")


def write_duplication_baseline(root: Path, baseline: dict[str, Any]) -> None:
    """Install one isolated baseline inside a disposable self-test root."""
    path = root / DUPLICATION_BASELINE
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(baseline), encoding="utf-8")


def duplication_self_test(root: Path) -> None:
    """Exercise clone growth, removal, stale state, and canonical output."""
    source_files = [Path("a.py"), Path("b.py")]
    write_fixture(root / "a.py", "shared")
    write_fixture(root / "b.py", "shared")
    baseline = current_duplication_baseline(root, source_files)
    require_self_test(baseline == current_duplication_baseline(root, source_files), "canonical output")
    require_self_test(baseline["paths"] == sorted(set(baseline["paths"])), "canonical paths")
    require_self_test(list(baseline["fingerprints"]) == sorted(baseline["fingerprints"]), "canonical fingerprints")
    write_duplication_baseline(root, baseline)
    require_self_test(not duplication_errors(root, source_files), "clean baseline")

    write_fixture(root / "c.py", "shared")
    growth = duplication_errors(root, [*source_files, Path("c.py")])
    require_self_test(any("occurrences" in error or "growth" in error for error in growth), "duplicate introduction")

    (root / "b.py").write_text("pass\n", encoding="utf-8")
    removal = duplication_errors(root, source_files)
    require_self_test(any("duplication stale" in error for error in removal), "clone removal stale baseline")

    write_duplication_baseline(root, {**baseline, "tool": {}})
    require_self_test(
        any("tool drift" in error for error in duplication_errors(root, source_files)),
        "tool drift",
    )
    write_duplication_baseline(root, {**baseline, "schema": "stale"})
    require_self_test(
        any("schema drift" in error for error in duplication_errors(root, source_files)),
        "schema drift",
    )


def self_test() -> int:
    """Exercise every repository quality-gate boundary in disposable fixtures."""
    try:
        manifest_self_test()
        with tempfile.TemporaryDirectory(prefix="open-lola-code-quality-") as temporary:
            root = Path(temporary)
            line_budget_self_test(root)
            lizard_boundary_self_test(root)
        with tempfile.TemporaryDirectory(prefix="open-lola-duplication-") as temporary:
            duplication_self_test(Path(temporary))
    except SelfTestFailure as error:
        print(f"code-quality self-test failed: {error}")
        return 1
    print("code-quality self-test passed")
    return 0


def parse_args(arguments: Sequence[str] | None = None) -> argparse.Namespace:
    """Parse read-only diagnostics; this verifier never rewrites its baseline."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list-files", action="store_true", help="print the canonical first-party source manifest")
    parser.add_argument(
        "--print-duplication-baseline", action="store_true", help="print a candidate baseline for human review"
    )
    parser.add_argument("--self-test", action="store_true", help="run isolated verifier fixtures")
    return parser.parse_args(arguments)


def main(arguments: Sequence[str] | None = None) -> int:
    """Validate live source using one manifest and print a machine-readable verdict."""
    options = parse_args(arguments)
    if options.self_test:
        return self_test()
    root = Path(__file__).resolve().parents[1]
    source_files = repository_source_files(root)
    if options.list_files:
        print("\n".join(path.as_posix() for path in source_files))
        return 0
    if options.print_duplication_baseline:
        print(json.dumps(current_duplication_baseline(root, source_files), indent=2) + "\n")
        return 0
    errors = line_budget_errors(root, source_files) if source_files else ["first-party source manifest is empty"]
    errors.extend(duplication_errors(root, source_files))
    lizard_status = run_lizard(root, source_files) if source_files else 1
    if errors or lizard_status:
        print("CODE_QUALITY_VERDICT: FAIL")
        for error in sorted(errors):
            print(f"- {error}")
        return 1
    print(
        f"CODE_QUALITY_VERDICT: PASS (max {MAX_PHYSICAL_LINES} physical lines; max CCN {MAX_CCN}; duplicate tokens >= {MIN_DUPLICATE_TOKENS})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
