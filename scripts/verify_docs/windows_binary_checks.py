from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

from .constants import WINDOWS_15_CORPUS, WINDOWS_20_CORPUS, WINDOWS_STATIC_ANALYSIS
from .windows_docs import (
    binary_metadata_section,
    documented_main_gui_metadata,
)

def rabin2_info(path: Path) -> dict[str, str]:
    result = subprocess.run(
        ["rabin2", "-I", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    info: dict[str, str] = {}
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        parts = line.split(None, 1)
        if len(parts) == 2:
            info[parts[0]] = parts[1].strip()
    return info


def main_gui_metadata_from_rabin2() -> dict[str, str]:
    info = rabin2_info(WINDOWS_20_CORPUS / "LolaGui_XIMEA_x64.exe")
    architecture = "x86-64" if info.get("arch") == "x86" and info.get("bits") == "64" else ""
    toolchain = "MSVC" if info.get("lang") == "msvc" or info.get("cc") == "ms" else ""
    gui_type = ""
    if info.get("class") == "PE32+" and info.get("os") == "windows" and info.get("subsys") == "Windows GUI":
        gui_type = "PE32+ Windows GUI"

    return {
        "Type": gui_type,
        "Architecture": architecture,
        "Compile timestamp": info.get("compiled", ""),
        "Language/toolchain": toolchain,
        "PDB path": info.get("dbg_file", ""),
        "Protections": (
            f"NX {info.get('nx', '')}, "
            f"stack canary {info.get('canary', '')}, "
            f"PIC {info.get('pic', '')}"
        ),
        "Signing indicator": info.get("signed", ""),
    }


def check_windows_mc03_main_gui_metadata() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    main_gui = WINDOWS_20_CORPUS / "LolaGui_XIMEA_x64.exe"
    if not main_gui.is_file():
        return ["missing Windows 2.0 main GUI: win-compiled/2-0/LolaGui_XIMEA_x64.exe"]

    documented = documented_main_gui_metadata()
    actual = main_gui_metadata_from_rabin2()
    required_fields = (
        "Type",
        "Architecture",
        "Compile timestamp",
        "Language/toolchain",
        "PDB path",
        "Protections",
        "Signing indicator",
    )

    for field in required_fields:
        if field not in documented:
            errors.append(f"MC03 metadata table missing field: {field}")
            continue
        if documented[field] != actual[field]:
            errors.append(
                f"MC03 metadata mismatch for {field}: "
                f"documented {documented[field]!r}, rabin2 reports {actual[field]!r}"
            )

    return errors


def documented_windows_pe_inventory() -> dict[str, tuple[bool, int, int, str]]:
    section = binary_metadata_section()
    inventory: dict[str, tuple[bool, int, int, str]] = {}
    row_re = re.compile(
        r"^\| `(?P<path>[^`]+\.(?:exe|dll))` "
        r"\| (?P<signed>true|false) "
        r"\| (?P<compiled>[^|]+) "
        r"\| (?P<imports>[0-9]+) "
        r"\| (?P<exports>[0-9]+) "
        r"\| (?P<role>.+) \|$",
        flags=re.IGNORECASE | re.MULTILINE,
    )
    for match in row_re.finditer(section):
        inventory[match.group("path")] = (
            match.group("signed").lower() == "true",
            int(match.group("imports")),
            int(match.group("exports")),
            match.group("role").strip(),
        )
    return inventory


def documented_windows_pe_roles() -> dict[str, str]:
    return {
        path: role
        for path, (_, _, _, role) in documented_windows_pe_inventory().items()
    }


def documented_dependency_ownership() -> dict[str, tuple[str, str]]:
    section = binary_metadata_section()
    match = re.search(
        r"^Dependency ownership:\n\n(?P<table>(?:\|.*\n)+)",
        section,
        flags=re.MULTILINE,
    )
    if match is None:
        return {}

    ownership: dict[str, tuple[str, str]] = {}
    row_re = re.compile(
        r"^\| (?P<boundary>[^|]+) "
        r"\| (?P<evidence>[^|]+) "
        r"\| (?P<meaning>[^|]+) \|$",
        flags=re.MULTILINE,
    )
    for row in row_re.finditer(match.group("table")):
        boundary = row.group("boundary").strip()
        if boundary in {"Boundary", "---"}:
            continue
        ownership[boundary] = (
            row.group("evidence").strip(),
            row.group("meaning").strip(),
        )
    return ownership


def rabin2_json(path: Path, flag: str) -> dict[str, object]:
    result = subprocess.run(
        ["rabin2", flag, str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(result.stdout)
    if not isinstance(payload, dict):
        return {}
    return payload


def rabin2_json_info(path: Path) -> dict[str, object]:
    payload = rabin2_json(path, "-Ij")
    info = payload.get("info", {})
    if not isinstance(info, dict):
        return {}
    return info


def rabin2_json_imports(path: Path) -> list[dict[str, object]]:
    payload = rabin2_json(path, "-ij")
    imports = payload.get("imports", [])
    if not isinstance(imports, list):
        return []
    return [item for item in imports if isinstance(item, dict)]


def rabin2_json_exports(path: Path) -> list[dict[str, object]]:
    payload = rabin2_json(path, "-Ej")
    exports = payload.get("exports", [])
    if not isinstance(exports, list):
        return []
    return [item for item in exports if isinstance(item, dict)]


def import_libraries(imports: list[dict[str, object]]) -> set[str]:
    return {
        str(item.get("libname", "")).lower()
        for item in imports
        if item.get("libname")
    }


def has_import(imports: list[dict[str, object]], library: str, name: str) -> bool:
    expected_library = library.lower()
    expected_name = name.lower()
    return any(
        str(item.get("libname", "")).lower() == expected_library
        and str(item.get("name", "")).lower() == expected_name
        for item in imports
    )


def has_import_ordinal(imports: list[dict[str, object]], library: str, ordinal: int) -> bool:
    expected_library = library.lower()
    return any(
        str(item.get("libname", "")).lower() == expected_library
        and item.get("ordinal") == ordinal
        for item in imports
    )


def has_export(path: Path, name: str) -> bool:
    expected_name = name.lower()
    return any(
        str(item.get("name", "")).lower() == expected_name
        for item in rabin2_json_exports(path)
    )


def file_contains_ascii(path: Path, token: str) -> bool:
    return token.encode("ascii") in path.read_bytes()


def rabin2_row_count(path: Path, flag: str) -> int:
    result = subprocess.run(
        ["rabin2", flag, str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    row_re = re.compile(r"^\s*[0-9]+\s+0x[0-9a-fA-F]+", flags=re.MULTILINE)
    return len(row_re.findall(result.stdout))


def check_windows_mc04_import_export_counts() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_20_CORPUS.is_dir():
        return ["missing Windows 2.0 corpus: win-compiled/2-0"]

    documented = documented_windows_pe_inventory()
    if not documented:
        errors.append("MC04 PE import/export table missing from Windows static analysis")
        return errors

    for path, (_, documented_imports, documented_exports, _) in sorted(documented.items()):
        artifact = WINDOWS_20_CORPUS / path
        if not artifact.is_file():
            continue
        actual_imports = rabin2_row_count(artifact, "-i")
        actual_exports = rabin2_row_count(artifact, "-E")
        if documented_imports != actual_imports:
            errors.append(
                f"MC04 import count mismatch for {path}: "
                f"documented {documented_imports}, rabin2 reports {actual_imports}"
            )
        if documented_exports != actual_exports:
            errors.append(
                f"MC04 export count mismatch for {path}: "
                f"documented {documented_exports}, rabin2 reports {actual_exports}"
            )
    return errors


def check_windows_mc05_signing_indicators() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_20_CORPUS.is_dir():
        return ["missing Windows 2.0 corpus: win-compiled/2-0"]

    documented = documented_windows_pe_inventory()
    if not documented:
        errors.append("MC05 PE signing table missing from Windows static analysis")
        return errors

    for path, (documented_signed, _, _, _) in sorted(documented.items()):
        artifact = WINDOWS_20_CORPUS / path
        if not artifact.is_file():
            continue
        actual_signed = bool(rabin2_json_info(artifact).get("signed", False))
        if documented_signed != actual_signed:
            errors.append(
                f"MC05 signing mismatch for {path}: "
                f"documented {str(documented_signed).lower()}, "
                f"rabin2 reports {str(actual_signed).lower()}"
            )

    return errors


def check_windows_mc06_dependency_ownership() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_20_CORPUS.is_dir():
        return ["missing Windows 2.0 corpus: win-compiled/2-0"]

    ownership = documented_dependency_ownership()
    if not ownership:
        errors.append("MC06 dependency ownership table missing from Windows static analysis")
        return errors

    check_dependency_boundaries(errors, ownership)
    check_dependency_doc_tokens(errors, ownership)

    main_gui = WINDOWS_20_CORPUS / "LolaGui_XIMEA_x64.exe"
    if not main_gui.is_file():
        errors.append("missing Windows 2.0 main GUI: win-compiled/2-0/LolaGui_XIMEA_x64.exe")
        return errors

    main_imports = rabin2_json_imports(main_gui)
    main_libraries = import_libraries(main_imports)
    pe_inventory = documented_windows_pe_inventory()

    check_lola_owned_artifacts(errors, main_gui)
    check_microsoft_runtime_ownership(errors, main_libraries, pe_inventory)
    check_portaudio_ownership(errors, main_libraries)
    check_ximea_ownership(errors, main_imports)
    check_winpcap_ownership(errors, main_imports)
    check_opencv_ijg_ownership(errors, main_gui, main_libraries)
    check_cuda_gpujpeg_ownership(errors, main_libraries)
    return errors


def check_dependency_boundaries(
    errors: list[str],
    ownership: dict[str, tuple[str, str]],
) -> None:
    required_boundaries = (
        "LoLa-owned GUI",
        "LoLa-owned helpers",
        "Microsoft runtime",
        "PortAudio/ASIO",
        "XIMEA",
        "WinPcap",
        "OpenCV/IJG",
        "CUDA/GPUJPEG",
    )
    for boundary in required_boundaries:
        if boundary not in ownership:
            errors.append(f"MC06 dependency boundary missing: {boundary}")


def check_dependency_doc_tokens(
    errors: list[str],
    ownership: dict[str, tuple[str, str]],
) -> None:
    required_doc_tokens = {
        "LoLa-owned GUI": ("LolaGui_XIMEA_x64.exe", "PDB", "unsigned"),
        "LoLa-owned helpers": ("Tester", "converter", "splitter"),
        "Microsoft runtime": ("MFC", "VC", "signed"),
        "PortAudio/ASIO": (
            "portaudio_x64.dll",
            "Pa_OpenStream",
            "Pa_StartStream",
            "PaAsio_GetAvailableBufferSizes",
        ),
        "XIMEA": ("xiGetImage", "xiOpenDevice", "xiSetParam", "xiStartAcquisition"),
        "WinPcap": ("wpcap.dll", "send", "receive", "BPF", "minimum-copy"),
        "OpenCV/IJG": ("OpenCV 2.4.9", "jpeg62.dll", "Independent JPEG Group"),
        "CUDA/GPUJPEG": ("cudart64_55.dll", "gpujpeg.dll", "no static"),
    }
    for boundary, tokens in required_doc_tokens.items():
        if boundary not in ownership:
            continue
        row_text = " ".join(ownership[boundary])
        for token in tokens:
            if token not in row_text:
                errors.append(f"MC06 {boundary} row missing evidence token: {token}")


def check_lola_owned_artifacts(errors: list[str], main_gui: Path) -> None:
    main_info = rabin2_info(main_gui)

    if bool(rabin2_json_info(main_gui).get("signed", False)):
        errors.append("MC06 LoLa-owned GUI should remain documented as unsigned")
    if "NewLolaGUI" not in main_info.get("dbg_file", ""):
        errors.append("MC06 LoLa-owned GUI PDB path does not identify NewLolaGUI")

    helper_paths = (
        "LolaGui_Tester/LolaGui_TESTER_x64.exe",
        "LolaVideoConverter_x64.exe",
        "LolaWavSplitter_x64.exe",
    )
    for helper_path in helper_paths:
        if not (WINDOWS_20_CORPUS / helper_path).is_file():
            errors.append(f"MC06 missing LoLa helper artifact: {helper_path}")


def check_microsoft_runtime_ownership(
    errors: list[str],
    main_libraries: set[str],
    pe_inventory: dict[str, tuple[bool, int, int, str]],
) -> None:
    microsoft_runtime_paths = (
        "LolaGui_Tester/mfc100.dll",
        "LolaGui_Tester/msvcp100.dll",
        "LolaGui_Tester/msvcr100.dll",
        "concrt140.dll",
        "mfc100.dll",
        "mfc140.dll",
        "msvcp100.dll",
        "msvcp140.dll",
        "msvcr100.dll",
        "vcruntime140.dll",
    )
    for runtime_path in microsoft_runtime_paths:
        if runtime_path not in pe_inventory:
            errors.append(f"MC06 Microsoft runtime missing from PE inventory: {runtime_path}")
            continue
        if not pe_inventory[runtime_path][0]:
            errors.append(f"MC06 Microsoft runtime should be signed: {runtime_path}")

    for library in ("mfc140.dll", "msvcp140.dll", "vcruntime140.dll"):
        if library not in main_libraries:
            errors.append(f"MC06 main GUI missing Microsoft runtime import: {library}")


def check_portaudio_ownership(errors: list[str], main_libraries: set[str]) -> None:
    if "portaudio_x64.dll" not in main_libraries:
        errors.append("MC06 main GUI missing PortAudio import: portaudio_x64.dll")
    for export in ("Pa_OpenStream", "Pa_StartStream", "PaAsio_GetAvailableBufferSizes"):
        if not has_export(WINDOWS_20_CORPUS / "portaudio_x64.dll", export):
            errors.append(f"MC06 PortAudio export missing: {export}")


def check_ximea_ownership(errors: list[str], main_imports: list[dict[str, object]]) -> None:
    for name in ("xiGetImage", "xiOpenDevice", "xiSetParamFloat", "xiSetParamInt", "xiStartAcquisition"):
        if not has_import(main_imports, "xiapi64.dll", name):
            errors.append(f"MC06 main GUI missing XIMEA import: {name}")
        if not has_export(WINDOWS_20_CORPUS / "xiapi64.dll", name):
            errors.append(f"MC06 XIMEA export missing: {name}")


def check_winpcap_ownership(errors: list[str], main_imports: list[dict[str, object]]) -> None:
    for name in (
        "pcap_open",
        "pcap_next_ex",
        "pcap_sendpacket",
        "pcap_sendqueue_queue",
        "pcap_compile",
        "pcap_setfilter",
        "pcap_setmintocopy",
    ):
        if not has_import(main_imports, "wpcap.dll", name):
            errors.append(f"MC06 main GUI missing WinPcap import: {name}")


def check_opencv_ijg_ownership(
    errors: list[str],
    main_gui: Path,
    main_libraries: set[str],
) -> None:
    for library in ("opencv_core249.dll", "opencv_highgui249.dll", "opencv_imgproc249.dll", "jpeg62.dll"):
        if library not in main_libraries:
            errors.append(f"MC06 main GUI missing OpenCV/IJG import: {library}")
    if not file_contains_ascii(main_gui, "Independent JPEG Group"):
        errors.append("MC06 main GUI missing Independent JPEG Group string")


def check_cuda_gpujpeg_ownership(errors: list[str], main_libraries: set[str]) -> None:
    for shipped_runtime in ("cudart64_55.dll", "gpujpeg.dll"):
        if not (WINDOWS_20_CORPUS / shipped_runtime).is_file():
            errors.append(f"MC06 missing shipped CUDA/GPUJPEG runtime: {shipped_runtime}")
    for absent_library in ("cudart64_55.dll", "gpujpeg.dll"):
        if absent_library in main_libraries:
            errors.append(f"MC06 v2.0 main GUI unexpectedly imports {absent_library}")
    if "cudart64_55.dll" not in import_libraries(rabin2_json_imports(WINDOWS_20_CORPUS / "gpujpeg.dll")):
        errors.append("MC06 gpujpeg.dll missing CUDA runtime import: cudart64_55.dll")
    if not has_export(WINDOWS_20_CORPUS / "gpujpeg.dll", "gpujpeg_init_device"):
        errors.append("MC06 gpujpeg.dll missing export: gpujpeg_init_device")
    if WINDOWS_15_CORPUS.is_dir():
        cuda_gui = WINDOWS_15_CORPUS / "LolaGui_XIMEA_CUDA_x64.exe"
        if cuda_gui.is_file() and "gpujpeg.dll" not in import_libraries(rabin2_json_imports(cuda_gui)):
            errors.append("MC06 v1.5 CUDA GUI missing comparison GPUJPEG import")
