#!/usr/bin/env python3
"""Verify that the repository's runtime and tooling boundaries are explicit."""

from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path


CORE_FACADE_FILES = frozenset({"Facade.swift"})
REQUIRED_DIRECTORIES = (
    "runtimes/macos/Sources",
    "runtimes/linux-compat-connector/linux_connector",
    "runtimes/rust-station/src",
    "third_party/opus",
    "third_party/jpeg-xs",
    "tools",
    "web/demo",
)
REQUIRED_FILES = (
    "Package.swift",
    "pyproject.toml",
    "runtimes/rust-station/Cargo.toml",
    "tools/README.md",
    "web/demo/index.html",
)
LEGACY_ROOT_DIRECTORIES = (
    "Sources",
    "rusty-lola",
    "scripts",
    "site",
)
PACKAGE_TARGETS = frozenset(
    {
        "OpenLolaContracts",
        "OpenLolaCore",
        "OpenLolaSessionDomain",
        "OpenLolaTransport",
        "OpenLolaMediaPlatform",
        "OpenLolaEvidenceModels",
        "OpenLolaApplication",
        "OpenLolaAppSupport",
        "COpenLolaAtomics",
        "CJpegXSReference",
        "COpus",
        "open-lola",
        "open-lola-app",
        "OpenLolaContractsTests",
        "OpenLolaCoreTests",
        "OpenLolaSessionDomainTests",
        "OpenLolaEvidenceModelsTests",
        "OpenLolaApplicationTests",
        "OpenLolaTransportTests",
        "OpenLolaMediaPlatformTests",
    }
)
PACKAGE_TARGET_GRAPH = {
    "OpenLolaContracts": frozenset(),
    "OpenLolaCore": frozenset(
        {
            "OpenLolaApplication",
            "OpenLolaContracts",
            "OpenLolaSessionDomain",
            "OpenLolaTransport",
            "OpenLolaMediaPlatform",
            "OpenLolaEvidenceModels",
        }
    ),
    "OpenLolaSessionDomain": frozenset({"OpenLolaContracts"}),
    "OpenLolaTransport": frozenset(
        {"OpenLolaContracts", "OpenLolaSessionDomain", "OpenLolaEvidenceModels"}
    ),
    "OpenLolaMediaPlatform": frozenset(
        {
            "OpenLolaContracts",
            "OpenLolaSessionDomain",
            "OpenLolaEvidenceModels",
            "OpenLolaTransport",
            "COpenLolaAtomics",
            "CJpegXSReference",
            "COpus",
        }
    ),
    "OpenLolaEvidenceModels": frozenset({"OpenLolaContracts"}),
    "OpenLolaApplication": frozenset(
        {
            "OpenLolaContracts",
            "OpenLolaSessionDomain",
            "OpenLolaTransport",
            "OpenLolaMediaPlatform",
            "OpenLolaEvidenceModels",
            "COpenLolaAtomics",
            "CJpegXSReference",
            "COpus",
        }
    ),
    "OpenLolaAppSupport": frozenset({"OpenLolaCore", "COpenLolaAtomics"}),
    "COpenLolaAtomics": frozenset(),
    "CJpegXSReference": frozenset(),
    "COpus": frozenset(),
    "open-lola": frozenset({"OpenLolaCore", "OpenLolaApplication", "OpenLolaEvidenceModels"}),
    "open-lola-app": frozenset({"OpenLolaAppSupport"}),
    "OpenLolaContractsTests": frozenset({"OpenLolaContracts"}),
    "OpenLolaCoreTests": frozenset({"OpenLolaCore"}),
    "OpenLolaSessionDomainTests": frozenset({"OpenLolaSessionDomain"}),
    "OpenLolaEvidenceModelsTests": frozenset({"OpenLolaEvidenceModels"}),
    "OpenLolaApplicationTests": frozenset({"OpenLolaApplication"}),
    "OpenLolaTransportTests": frozenset({"OpenLolaTransport"}),
    "OpenLolaMediaPlatformTests": frozenset({"OpenLolaMediaPlatform"}),
}
PACKAGE_TARGET_PATHS = {
    "OpenLolaContracts": "runtimes/macos/Sources/OpenLolaContracts",
    "OpenLolaCore": "runtimes/macos/Sources/OpenLolaCore",
    "OpenLolaSessionDomain": "runtimes/macos/Sources/OpenLolaSessionDomain",
    "OpenLolaTransport": "runtimes/macos/Sources/OpenLolaTransport",
    "OpenLolaMediaPlatform": "runtimes/macos/Sources/OpenLolaMediaPlatform",
    "OpenLolaEvidenceModels": "runtimes/macos/Sources/OpenLolaEvidenceModels",
    "OpenLolaApplication": "runtimes/macos/Sources/OpenLolaApplication",
    "OpenLolaAppSupport": "runtimes/macos/Sources/open-lola-app",
    "COpenLolaAtomics": "runtimes/macos/Sources/COpenLolaAtomics",
    "CJpegXSReference": "third_party/jpeg-xs/libjxs",
    "COpus": "third_party/opus",
    "open-lola": "runtimes/macos/Sources/open-lola",
    "open-lola-app": "runtimes/macos/Sources/open-lola-app-main",
}
TARGET_IMPORT_ALLOWLISTS = {
    "OpenLolaSessionDomain": frozenset({"OpenLolaContracts"}),
    "OpenLolaEvidenceModels": frozenset({"OpenLolaContracts"}),
    "OpenLolaTransport": frozenset(
        {"OpenLolaContracts", "OpenLolaSessionDomain", "OpenLolaEvidenceModels"}
    ),
    "OpenLolaMediaPlatform": frozenset(
        {
            "OpenLolaContracts",
            "OpenLolaSessionDomain",
            "OpenLolaEvidenceModels",
            "OpenLolaTransport",
            "COpenLolaAtomics",
            "CJpegXSReference",
            "COpus",
        }
    ),
    "OpenLolaApplication": frozenset(
        {
            "OpenLolaContracts",
            "OpenLolaSessionDomain",
            "OpenLolaTransport",
            "OpenLolaMediaPlatform",
            "OpenLolaEvidenceModels",
            "COpenLolaAtomics",
            "CJpegXSReference",
            "COpus",
        }
    ),
    "OpenLolaAppSupport": frozenset({"OpenLolaCore", "COpenLolaAtomics"}),
    "OpenLolaCore": frozenset(
        {
            "OpenLolaApplication",
            "OpenLolaContracts",
            "OpenLolaSessionDomain",
            "OpenLolaTransport",
            "OpenLolaMediaPlatform",
            "OpenLolaEvidenceModels",
        }
    ),
}
SESSION_DOMAIN_BANNED_FRAMEWORKS = frozenset(
    {"AppKit", "AVFoundation", "AudioToolbox", "CoreAudio", "CoreVideo", "SwiftUI", "VideoToolbox"}
)
TRANSPORT_BANNED_FRAMEWORKS = frozenset(
    {"AppKit", "AVFoundation", "AudioToolbox", "CoreAudio", "CoreVideo", "SwiftUI", "VideoToolbox"}
)
SESSION_DOMAIN_SIDE_EFFECTS = (
    "FileHandle",
    "FileManager",
    "NotificationCenter",
    "Process(",
    "URLSession",
    "UserDefaults",
    "Data(contentsOf:",
    ".write(to:",
)
CLI_PARSER_DECLARATIONS = re.compile(
    r"\b(?:struct|class|enum|actor|protocol|typealias|extension)\s+"
    r"(?:OpenLolaCLI|KeyValueArgumentParser)\b"
)


def swift_core_errors(root: Path) -> list[str]:
    """Return errors for the core facade and lower-module import boundaries."""
    core = root / "runtimes/macos/Sources/OpenLolaCore"
    if not core.is_dir():
        return []
    errors = []
    children = {child.name for child in core.iterdir() if child.is_dir() and not child.name.startswith(".")}
    if children:
        errors.append(f"OpenLolaCore must have no child directories; found {sorted(children)}")
    files = {child.name for child in core.iterdir() if child.is_file()}
    if files != CORE_FACADE_FILES:
        errors.append(f"OpenLolaCore must contain exactly {sorted(CORE_FACADE_FILES)}; found {sorted(files)}")
    facade = core / "Facade.swift"
    if facade.is_file():
        actual_facade_imports = frozenset(
            re.findall(
                r"^\s*@_exported\s+import\s+([A-Za-z][A-Za-z0-9_]*)\b",
                facade.read_text(encoding="utf-8"),
                re.MULTILINE,
            )
        )
        expected_facade_imports = TARGET_IMPORT_ALLOWLISTS["OpenLolaCore"]
        if actual_facade_imports != expected_facade_imports:
            errors.append(
                "OpenLolaCore Facade.swift imports must be "
                f"{sorted(expected_facade_imports)}; found {sorted(actual_facade_imports)}"
            )
    errors.extend(_module_import_errors(root, "OpenLolaCore", frozenset(TARGET_IMPORT_ALLOWLISTS["OpenLolaCore"])))
    policy_roots = [("Session/Domain", core / "Session/Domain")]
    standalone_domain = root / "runtimes/macos/Sources/OpenLolaSessionDomain"
    if standalone_domain.is_dir():
        policy_roots.append(("OpenLolaSessionDomain", standalone_domain))
    for relative, policy_root in policy_roots:
        for file_path in sorted(policy_root.rglob("*.swift")):
            for line_number, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), 1):
                match = re.match(r"^\s*import\s+([A-Za-z][A-Za-z0-9_.]*)\b", line)
                if match and match.group(1).split(".")[-1] in SESSION_DOMAIN_BANNED_FRAMEWORKS:
                    errors.append(
                        f"{file_path.relative_to(root)}:{line_number}: {relative} may not import {match.group(1)}"
                    )
                if any(marker in line for marker in SESSION_DOMAIN_SIDE_EFFECTS):
                    errors.append(
                        f"{file_path.relative_to(root)}:{line_number}: {relative} must remain side-effect free"
                    )
    transport_roots = [("Transport", core / "Transport")]
    standalone_transport = root / "runtimes/macos/Sources/OpenLolaTransport"
    if standalone_transport.is_dir():
        transport_roots.append(("OpenLolaTransport", standalone_transport))
    for relative, transport_root in transport_roots:
        for file_path in sorted(transport_root.rglob("*.swift")):
            for line_number, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), 1):
                match = re.match(r"^\s*import\s+([A-Za-z][A-Za-z0-9_.]*)\b", line)
                if match and match.group(1).split(".")[-1] in TRANSPORT_BANNED_FRAMEWORKS:
                    errors.append(
                        f"{file_path.relative_to(root)}:{line_number}: {relative} may not import {match.group(1)}"
                    )
    return errors


def _module_import_errors(root: Path, module: str, allowed: frozenset[str]) -> list[str]:
    """Reject imports of first-party modules outside a target's declared allowlist."""
    module_root = root / "runtimes/macos/Sources" / module
    if not module_root.is_dir():
        return []
    errors = []
    first_party = set(PACKAGE_TARGETS)
    for file_path in sorted(module_root.rglob("*.swift")):
        for line_number, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), 1):
            match = re.match(r"^\s*(?:@_exported\s+)?import\s+([A-Za-z][A-Za-z0-9_]*)\b", line)
            if match and match.group(1) in first_party and match.group(1) not in allowed:
                errors.append(
                    f"{file_path.relative_to(root)}:{line_number}: {module} may not import {match.group(1)}"
                )
    return errors


def cli_parser_errors(root: Path) -> list[str]:
    """Reject parser declarations in every first-party target except Application."""
    errors = []
    for target, relative_path in PACKAGE_TARGET_PATHS.items():
        if target in {"OpenLolaApplication", "COpenLolaAtomics", "CJpegXSReference", "COpus"}:
            continue
        target_root = root / relative_path
        if not target_root.is_dir():
            continue
        for file_path in sorted(target_root.rglob("*.swift")):
            for line_number, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), 1):
                if CLI_PARSER_DECLARATIONS.search(line):
                    errors.append(
                        f"{file_path.relative_to(root)}:{line_number}: CLI parsers/OpenLolaCLI must live below Application"
                    )
    return errors


def _target_blocks(package_text: str) -> dict[str, str]:
    """Extract SwiftPM target declaration blocks without evaluating Package.swift."""
    blocks: dict[str, str] = {}
    for match in re.finditer(r"\.(?:target|executableTarget|testTarget)\s*\(", package_text):
        depth = 0
        end = match.end() - 1
        for index in range(end, len(package_text)):
            character = package_text[index]
            if character == "(":
                depth += 1
            elif character == ")":
                depth -= 1
                if depth == 0:
                    block = package_text[match.start() : index + 1]
                    name_match = re.search(r"\bname:\s*\"([^\"]+)\"", block)
                    if name_match:
                        blocks[name_match.group(1)] = block
                    break
    return blocks


def package_target_errors(root: Path) -> list[str]:
    """Return errors in the preserved SwiftPM target declarations and DAG."""
    package_path = root / "Package.swift"
    if not package_path.is_file():
        return []
    package_text = package_path.read_text(encoding="utf-8")
    blocks = _target_blocks(package_text)
    declared = set(blocks)
    errors = [f"Package.swift is missing preserved target: {name}" for name in sorted(PACKAGE_TARGETS - declared)]
    errors.extend(f"Package.swift has unexpected target: {name}" for name in sorted(declared - PACKAGE_TARGETS))
    for name, dependencies in PACKAGE_TARGET_GRAPH.items():
        block = blocks.get(name)
        if block is None:
            continue
        dependency_match = re.search(r"\bdependencies:\s*\[(.*?)\]", block, re.DOTALL)
        actual = frozenset(re.findall(r'(?<!name:)\"([A-Za-z][A-Za-z0-9-]*)\"', dependency_match.group(1))) if dependency_match else frozenset()
        if actual != dependencies:
            errors.append(f"Package.swift target {name} dependencies must be {sorted(dependencies)}; found {sorted(actual)}")
        expected_path = PACKAGE_TARGET_PATHS.get(name)
        if expected_path is not None:
            path_match = re.search(r"\bpath:\s*\"([^\"]+)\"", block)
            if path_match is None or path_match.group(1) != expected_path:
                found = path_match.group(1) if path_match else "<missing>"
                errors.append(f"Package.swift target {name} path must be {expected_path}; found {found}")
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str, trail: tuple[str, ...] = ()) -> None:
        if name in visiting:
            cycle = " -> ".join((*trail, name))
            errors.append(f"Package.swift target dependency graph contains a cycle: {cycle}")
            return
        if name in visited:
            return
        visiting.add(name)
        for dependency in PACKAGE_TARGET_GRAPH.get(name, frozenset()):
            visit(dependency, (*trail, name))
        visiting.remove(name)
        visited.add(name)

    for target_name in sorted(PACKAGE_TARGET_GRAPH):
        visit(target_name)
    return errors


def architecture_errors(root: Path) -> list[str]:
    """Return missing required boundaries and present legacy root directories."""
    errors = [
        f"missing required directory: {relative}"
        for relative in REQUIRED_DIRECTORIES
        if not (root / relative).is_dir()
    ]
    errors.extend(
        f"missing required file: {relative}"
        for relative in REQUIRED_FILES
        if not (root / relative).is_file()
    )
    errors.extend(
        f"legacy root directory remains: {relative}"
        for relative in LEGACY_ROOT_DIRECTORIES
        if (root / relative).exists()
    )
    legacy_connector = root / "linux_connector"
    if legacy_connector.is_dir():
        unexpected = sorted(child.name for child in legacy_connector.iterdir() if child.name != "__pycache__")
        if unexpected:
            errors.append(f"deleted root linux_connector surface remains: {unexpected}")
    errors.extend(swift_core_errors(root))
    errors.extend(cli_parser_errors(root))
    for module, allowed in TARGET_IMPORT_ALLOWLISTS.items():
        if module != "OpenLolaCore":
            errors.extend(_module_import_errors(root, module, allowed))
    errors.extend(package_target_errors(root))
    return errors


def self_test() -> int:
    """Exercise semantic placement checks against isolated temporary fixtures."""
    expected_facade = "\n".join(
        f"@_exported import {module}"
        for module in sorted(TARGET_IMPORT_ALLOWLISTS["OpenLolaCore"])
    )
    with tempfile.TemporaryDirectory(prefix="open-lola-architecture-") as temporary:
        fixture_root = Path(temporary)
        core = fixture_root / "runtimes/macos/Sources/OpenLolaCore"
        core.mkdir(parents=True)
        (core / "Facade.swift").write_text(expected_facade + "\n", encoding="utf-8")
        if swift_core_errors(fixture_root):
            print("architecture self-test failed: facade-only consolidation was rejected", file=sys.stderr)
            return 1

        transport = fixture_root / "runtimes/macos/Sources/OpenLolaTransport"
        application = fixture_root / "runtimes/macos/Sources/OpenLolaApplication"
        transport.mkdir(parents=True)
        application.mkdir(parents=True)
        (transport / "InvalidParser.swift").write_text(
            "struct KeyValueArgumentParser {}\n", encoding="utf-8"
        )
        (application / "ValidParser.swift").write_text(
            "struct KeyValueArgumentParser {}\n", encoding="utf-8"
        )
        parser_errors = cli_parser_errors(fixture_root)
        if len(parser_errors) != 1 or "InvalidParser.swift" not in parser_errors[0]:
            print("architecture self-test failed: parser placement fixture was not rejected", file=sys.stderr)
            return 1
    print("architecture self-test passed")
    return 0


def main(arguments: list[str] | None = None) -> int:
    """Check the current checkout and print a machine-readable architecture verdict."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run isolated architecture fixtures")
    options = parser.parse_args(arguments)
    if options.self_test:
        return self_test()
    root = Path(__file__).resolve().parents[1]
    errors = architecture_errors(root)
    if errors:
        print("ARCHITECTURE_VERDICT: FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("ARCHITECTURE_VERDICT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
