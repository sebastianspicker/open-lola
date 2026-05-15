from __future__ import annotations

import hashlib
import re

from .constants import ROOT, WINDOWS_20_CORPUS, WINDOWS_RUNTIME_ANALYSIS, WINDOWS_STATIC_ANALYSIS

def static_inventory_section() -> str:
    text = WINDOWS_STATIC_ANALYSIS.read_text(encoding="utf-8")
    match = re.search(
        r"^## M01 Artifact Inventory\n(?P<section>.*?)(?=^## )",
        text,
        flags=re.MULTILINE | re.DOTALL,
    )
    if match is None:
        return ""
    return match.group("section")


def documented_windows_inventory() -> dict[str, tuple[int, str, str]]:
    section = static_inventory_section()
    inventory: dict[str, tuple[int, str, str]] = {}
    row_re = re.compile(
        r"^\| `(?P<path>archive/2026-05-11-win-compiled/win-compiled/2-0/[^`]+)` "
        r"\| (?P<bytes>[0-9]+) "
        r"\| `(?P<sha>[0-9a-f]{64})` "
        r"\| (?P<type>.+) \|$",
        flags=re.MULTILINE,
    )
    for match in row_re.finditer(section):
        inventory[match.group("path")] = (
            int(match.group("bytes")),
            match.group("sha"),
            match.group("type").strip(),
        )
    return inventory


def actual_windows_inventory() -> dict[str, tuple[int, str]]:
    inventory: dict[str, tuple[int, str]] = {}
    for path in sorted(WINDOWS_20_CORPUS.rglob("*")):
        if not path.is_file() or path.name == ".DS_Store":
            continue
        rel_path = path.relative_to(ROOT).as_posix()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        inventory[rel_path] = (path.stat().st_size, digest)
    return inventory


def check_windows_mc01_hash_inventory() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_20_CORPUS.is_dir():
        return ["missing Windows 2.0 corpus: archive/2026-05-11-win-compiled/win-compiled/2-0"]

    documented = documented_windows_inventory()
    actual = actual_windows_inventory()

    if not documented:
        errors.append("MC01 inventory table missing from Windows static analysis")
        return errors

    missing = sorted(set(actual) - set(documented))
    extra = sorted(set(documented) - set(actual))
    for path in missing:
        errors.append(f"MC01 inventory missing artifact: {path}")
    for path in extra:
        errors.append(f"MC01 inventory lists absent artifact: {path}")

    for path in sorted(set(actual) & set(documented)):
        documented_bytes, documented_sha, _ = documented[path]
        actual_bytes, actual_sha = actual[path]
        if documented_bytes != actual_bytes:
            errors.append(
                f"MC01 inventory byte mismatch for {path}: "
                f"documented {documented_bytes}, actual {actual_bytes}"
            )
        if documented_sha != actual_sha:
            errors.append(
                f"MC01 inventory SHA-256 mismatch for {path}: "
                f"documented {documented_sha}, actual {actual_sha}"
            )

    return errors


def binary_metadata_section() -> str:
    text = WINDOWS_STATIC_ANALYSIS.read_text(encoding="utf-8")
    match = re.search(
        r"^## M02 Binary Metadata And Dependencies\n(?P<section>.*?)(?=^## )",
        text,
        flags=re.MULTILINE | re.DOTALL,
    )
    if match is None:
        return ""
    return match.group("section")


def runtime_control_grammar_section() -> str:
    text = WINDOWS_RUNTIME_ANALYSIS.read_text(encoding="utf-8")
    match = re.search(
        r"^## Control Grammar Recovery\n(?P<section>.*?)(?=^## )",
        text,
        flags=re.MULTILINE | re.DOTALL,
    )
    if match is None:
        return ""
    return match.group("section")


def documented_control_messages() -> dict[str, str]:
    section = runtime_control_grammar_section()
    messages: dict[str, str] = {}
    row_re = re.compile(
        r"^\| `(?P<message>/MESG_[^`]+)` "
        r"\| (?P<fields>[^|]+) "
        r"\| (?P<status>[^|]+) \|$",
        flags=re.MULTILINE,
    )
    for match in row_re.finditer(section):
        messages[match.group("message")] = match.group("fields").strip()
    return messages


def documented_control_fields_for(message: str, messages: dict[str, str]) -> str:
    fields = messages.get(message, "")
    if fields == "Same media fields as quick connect":
        return messages.get("/MESG_QUICKCONN", "")
    return fields


def documented_main_gui_metadata() -> dict[str, str]:
    section = binary_metadata_section()
    metadata: dict[str, str] = {}
    row_re = re.compile(
        r"^\| (?P<field>[^|`]+) \| (?P<value>[^|]+) \|$",
        flags=re.MULTILINE,
    )
    for match in row_re.finditer(section):
        field = match.group("field").strip()
        value = match.group("value").strip().strip("`")
        if field not in {"Field", "---"}:
            metadata[field] = value
    return metadata
