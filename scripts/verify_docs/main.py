from __future__ import annotations

import sys

from .constants import ROOT
from .markdown_checks import (
    check_archive_top_level_copy_files,
    check_ascii,
    check_backticked_source_paths,
    check_implementation_companion,
    check_links,
    check_public_planning_contract,
    check_release_hardening_contract,
    check_milestone_contract,
    check_required_topics,
    check_sota_matrix,
    check_todo_markers,
    docs_from_patterns,
)
from .windows_binary_checks import (
    check_windows_mc03_main_gui_metadata,
    check_windows_mc04_import_export_counts,
    check_windows_mc05_signing_indicators,
    check_windows_mc06_dependency_ownership,
)
from .windows_control_checks import (
    check_windows_mc02_type_and_role_inventory,
    check_windows_mc07_control_message_strings,
)
from .windows_docs import check_windows_mc01_hash_inventory
from .windows_media_checks import (
    check_windows_mc08_network_surfaces,
    check_windows_mc09_audio_surfaces,
    check_windows_mc10_video_surfaces,
    check_windows_mc11_codec_split,
)

def has_internal_documentation_context() -> bool:
    return (
        (ROOT / "archive" / "2026-05-05-doc-consolidation").is_dir()
        and (ROOT / "docs" / "implementation-handoff.md").is_file()
        and (
            ROOT
            / "archive"
            / "2026-05-11-research-archive"
            / "docs"
            / "research"
            / "RESEARCH_EVIDENCE_MATRIX_2026.md"
        ).is_file()
        and (ROOT / "private" / "reverse-engineering" / "lola-2-windows").is_dir()
        and (ROOT / "archive" / "2026-05-11-win-compiled" / "win-compiled" / "2-0").is_dir()
    )

def main() -> int:
    internal_context = has_internal_documentation_context()
    docs = docs_from_patterns()
    errors: list[str] = []
    candidate_external_prefixes = (
        "archive/",
        "../archive/",
        "../../archive/",
        "private/",
        "../private/",
        "../../private/",
    )
    errors.extend(check_links(
        docs,
        missing_allowed_prefixes=() if internal_context else candidate_external_prefixes,
    ))
    errors.extend(check_backticked_source_paths(docs))
    errors.extend(check_required_topics(docs))
    errors.extend(check_ascii())
    errors.extend(check_archive_top_level_copy_files())
    errors.extend(check_public_planning_contract())
    errors.extend(check_todo_markers(docs))
    if internal_context:
        errors.extend(check_milestone_contract())
        errors.extend(check_implementation_companion())
        errors.extend(check_release_hardening_contract())
        errors.extend(check_sota_matrix())
        errors.extend(check_windows_mc01_hash_inventory())
        errors.extend(check_windows_mc02_type_and_role_inventory())
        errors.extend(check_windows_mc03_main_gui_metadata())
        errors.extend(check_windows_mc04_import_export_counts())
        errors.extend(check_windows_mc05_signing_indicators())
        errors.extend(check_windows_mc06_dependency_ownership())
        errors.extend(check_windows_mc07_control_message_strings())
        errors.extend(check_windows_mc08_network_surfaces())
        errors.extend(check_windows_mc09_audio_surfaces())
        errors.extend(check_windows_mc10_video_surfaces())
        errors.extend(check_windows_mc11_codec_split())
    else:
        print("Documentation verifier running public-candidate checks; internal corpus checks skipped.")

    if errors:
        print("Documentation verification failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Documentation verification passed.")
    return 0
