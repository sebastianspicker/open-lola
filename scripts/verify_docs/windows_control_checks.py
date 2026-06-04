from __future__ import annotations

from collections.abc import Mapping
import subprocess
from pathlib import Path

from .constants import (
    CONTROL_MESSAGE_REQUIRED_FIELDS,
    CONTROL_MESSAGE_TEMPLATES,
    ROOT,
    WINDOWS_20_CORPUS,
    WINDOWS_RUNTIME_ANALYSIS,
    WINDOWS_STATIC_ANALYSIS,
)
from .windows_binary_checks import documented_windows_pe_roles, file_contains_ascii
from .windows_docs import (
    actual_windows_inventory,
    documented_control_fields_for,
    documented_control_messages,
    documented_windows_inventory,
)


def check_windows_mc07_control_message_strings() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_RUNTIME_ANALYSIS.is_file():
        return [
            "missing Windows runtime-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/runtime-analysis.md"
        ]

    main_gui = WINDOWS_20_CORPUS / "LolaGui_XIMEA_x64.exe"
    if not main_gui.is_file():
        return ["missing Windows 2.0 main GUI: win-compiled/2-0/LolaGui_XIMEA_x64.exe"]

    documented_messages = documented_control_messages()
    if not documented_messages:
        errors.append("MC07 control grammar table missing from Windows runtime analysis")
        return errors

    check_control_message_required_fields(errors, documented_messages)
    check_static_control_anchors(errors)
    check_control_templates(errors, main_gui)
    check_runtime_control_summary(errors)
    return errors


def check_control_message_required_fields(
    errors: list[str],
    documented_messages: dict[str, str],
) -> None:
    for message, required_fields in CONTROL_MESSAGE_REQUIRED_FIELDS.items():
        if message not in documented_messages:
            errors.append(f"MC07 control grammar table missing message: {message}")
            continue
        field_text = documented_control_fields_for(message, documented_messages)
        for field in required_fields:
            if field not in field_text:
                errors.append(f"MC07 {message} row missing visible field: {field}")


def check_static_control_anchors(errors: list[str]) -> None:
    static_text = WINDOWS_STATIC_ANALYSIS.read_text(encoding="utf-8")
    static_anchor_tokens = (
        "Control/session grammar",
        "/MESG_CHECKLOLASTATUS",
        "/MESG_QUICKCONN",
        "/MESG_REJECT",
        "/MESG_DISCONNECT",
        "/MESG_CHAT",
        "SRCIP",
        "DSTIP",
        "SID",
        "FUN_14001fb60",
        "FUN_14001f390",
    )
    for token in static_anchor_tokens:
        if token not in static_text:
            errors.append(f"MC07 static-analysis control anchor missing: {token}")


def check_control_templates(errors: list[str], main_gui: Path) -> None:
    for message, template in CONTROL_MESSAGE_TEMPLATES.items():
        if not file_contains_ascii(main_gui, template):
            errors.append(f"MC07 main GUI missing control template: {message}")


def check_runtime_control_summary(errors: list[str]) -> None:
    runtime_text = WINDOWS_RUNTIME_ANALYSIS.read_text(encoding="utf-8")
    for token in ("/MESG_*", "SRCIP", "DSTIP", "SID", "TXT"):
        if token not in runtime_text:
            errors.append(f"MC07 runtime-analysis summary missing token: {token}")


def file_output(path: Path) -> str:
    result = subprocess.run(
        ["file", "-b", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def type_matches_file_output(documented_type: str, actual_type: str) -> bool:
    if documented_type == "ASCII text, CRLF":
        return "ASCII text" in actual_type and "CRLF" in actual_type
    if documented_type.startswith("Generic INItialization configuration"):
        return actual_type == documented_type
    if documented_type == "PE32+ GUI x86-64":
        return (
            "PE32+ executable" in actual_type
            and "(GUI)" in actual_type
            and "(DLL)" not in actual_type
            and "x86-64" in actual_type
        )
    if documented_type == "PE32+ DLL x86-64":
        return (
            "PE32+ executable" in actual_type
            and "(DLL)" in actual_type
            and "x86-64" in actual_type
        )
    if documented_type == "PE32 GUI NSIS installer":
        return (
            "PE32 executable" in actual_type
            and "(GUI)" in actual_type
            and ("Nullsoft Installer" in actual_type or "NSIS" in actual_type)
        )
    return False


def check_windows_mc02_type_and_role_inventory() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_20_CORPUS.is_dir():
        return ["missing Windows 2.0 corpus: win-compiled/2-0"]

    documented = documented_windows_inventory()
    roles = documented_windows_pe_roles()
    actual = actual_windows_inventory()

    if not documented:
        errors.append("MC02 type inventory table missing from Windows static analysis")
        return errors
    if not roles:
        errors.append("MC02 PE role table missing from Windows static analysis")
        return errors

    check_documented_windows_file_types(errors, actual, documented)
    check_windows_pe_roles(errors, actual, roles)
    return errors


def check_documented_windows_file_types(
    errors: list[str],
    actual: Mapping[str, tuple[int, str]],
    documented: Mapping[str, tuple[int, str, str]],
) -> None:
    for path in sorted(actual):
        if path not in documented:
            continue
        _, _, documented_type = documented[path]
        if not documented_type:
            errors.append(f"MC02 missing file type classification for {path}")
            continue
        actual_type = file_output(ROOT / path)
        if not type_matches_file_output(documented_type, actual_type):
            errors.append(
                f"MC02 file type mismatch for {path}: "
                f"documented {documented_type!r}, file reports {actual_type!r}"
            )


def check_windows_pe_roles(
    errors: list[str],
    actual: Mapping[str, tuple[int, str]],
    roles: dict[str, str],
) -> None:
    pe_paths = sorted(
        path
        for path in actual
        if Path(path).suffix.lower() in {".exe", ".dll"}
    )
    expected_role_paths = [
        Path(path).relative_to(WINDOWS_20_CORPUS.relative_to(ROOT)).as_posix()
        for path in pe_paths
    ]
    missing_roles = sorted(set(expected_role_paths) - set(roles))
    extra_roles = sorted(set(roles) - set(expected_role_paths))

    for path in missing_roles:
        errors.append(f"MC02 missing PE static role row: {path}")
    for path in extra_roles:
        errors.append(f"MC02 PE static role row has no live artifact: {path}")
    for path in sorted(set(expected_role_paths) & set(roles)):
        if not roles[path].strip() or roles[path].strip() == "-":
            errors.append(f"MC02 empty PE static role: {path}")
