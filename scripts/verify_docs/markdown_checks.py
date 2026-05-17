from __future__ import annotations

import re
from pathlib import Path
from urllib.parse import unquote

from .constants import (
    ACTIVE_MAC_PORT_DOCS,
    ARCHIVE_MANIFEST,
    ARCHIVED_TOPOLOGY_PATHS,
    DOC_IGNORE_PREFIXES,
    DOC_PATTERNS,
    EVIDENCE_MATRIX,
    IMPLEMENTATION_COMPANION,
    IMPLEMENTATION_COMPANION_HEADINGS,
    OPEN_QUESTIONS,
    PUBLIC_ACTIVE_STALE_REFERENCES,
    PUBLIC_ARCHITECTURE_DOCS,
    PUBLIC_EVIDENCE_LABEL_HEADING,
    PUBLIC_EVIDENCE_LABELS,
    PUBLIC_RELEASE_FORBIDDEN_TOKENS,
    PUBLIC_RELEASE_INTERNAL_LINK_PREFIXES,
    PUBLIC_MILESTONE_DOCS,
    PUBLIC_MILESTONE_HEADINGS,
    PUBLIC_PLANNING_DOCS,
    PUBLIC_PLANNING_FORBIDDEN_TOKENS,
    PUBLIC_PLANNING_REQUIRED_TOKENS,
    RELEASE_HARDENING_REPORT,
    REQUIRED_TOPICS,
    ROOT,
    SOTA_MATRIX,
)


def is_ignored_doc(path: Path) -> bool:
    try:
        parts = path.relative_to(ROOT).parts
    except ValueError:
        return True
    return any(parts[:len(prefix)] == prefix for prefix in DOC_IGNORE_PREFIXES)


def docs_from_patterns() -> list[Path]:
    docs: set[Path] = set()
    for pattern in DOC_PATTERNS:
        if any(char in pattern for char in "*?["):
            docs.update(ROOT.glob(pattern))
        else:
            docs.add(ROOT / pattern)
    return sorted(path for path in docs if path.is_file() and not is_ignored_doc(path))


def remove_fenced_code(text: str) -> str:
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
    link_re = re.compile(r"(?<!!)\[[^\]\n]+\]\(([^)\n]+)\)")
    return [match.group(1).strip() for match in link_re.finditer(text)]


def is_external_target(target: str) -> bool:
    return bool(re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target))


def normalize_link_target(target: str) -> str:
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    return target.split()[0].strip("'\"")


def check_links(
    docs: list[Path],
    missing_allowed_prefixes: tuple[str, ...] = (),
) -> list[str]:
    errors: list[str] = []
    for doc in docs:
        text = remove_fenced_code(doc.read_text(encoding="utf-8"))
        for raw_target in markdown_links(text):
            target = normalize_link_target(raw_target)
            if not target or target.startswith("#") or is_external_target(target):
                continue
            path_part = target.split("#", 1)[0].split("?", 1)[0]
            if not path_part:
                continue
            if path_part.startswith(missing_allowed_prefixes):
                continue
            candidate = doc.parent / unquote(path_part)
            if not candidate.exists():
                rel_doc = doc.relative_to(ROOT)
                errors.append(f"{rel_doc}: broken relative link: {target}")
    return errors


def check_backticked_source_paths(docs: list[Path]) -> list[str]:
    errors: list[str] = []
    checked_roots = (
        "Sources/",
        "Tests/",
        "scripts/",
        "script/",
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
                token = match.group(1).strip()
                if (
                    not token
                    or " " in token
                    or "*" in token
                    or token.startswith(("-", "<", "$"))
                    or token.endswith("/")
                ):
                    continue
                source_location_match = source_location_re.match(token)
                path_token = source_location_match.group(1) if source_location_match else token
                if Path(path_token).name in generated_residue_names:
                    continue
                if not (path_token.startswith(checked_roots) or path_token in root_files):
                    continue
                if not (ROOT / path_token).exists():
                    errors.append(
                        f"{rel_doc}:{line_number}: backticked source path does not exist: {token}"
                    )
    return errors


def check_required_topics(docs: list[Path]) -> list[str]:
    corpus = "\n".join(path.read_text(encoding="utf-8") for path in docs).lower()
    return [
        f"required topic missing: {topic}"
        for topic in REQUIRED_TOPICS
        if topic.lower() not in corpus
    ]


def check_ascii() -> list[str]:
    errors: list[str] = []
    ascii_docs = [ROOT / "MAC_PORT_PLAN.md"]
    ascii_docs.extend(
        ROOT / rel_path
        for rel_path in ACTIVE_MAC_PORT_DOCS
    )
    for path in ascii_docs:
        if not path.is_file():
            continue
        for line_number, line in enumerate(path.read_bytes().splitlines(), start=1):
            bad_bytes = [byte for byte in line if byte > 0x7F]
            if bad_bytes:
                rel_path = path.relative_to(ROOT)
                errors.append(f"{rel_path}:{line_number}: non-ASCII byte present")
                break
    return errors


def markdown_h2_headings(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return re.findall(r"^## (.+)$", text, flags=re.MULTILINE)


def check_milestone_contract() -> list[str]:
    errors: list[str] = []

    top_level_mac_port = ROOT / "mac-port"
    if top_level_mac_port.exists():
        errors.append("top-level mac-port must stay archived; active handoff is docs/implementation-handoff.md")

    public_milestone_dir = ROOT / "docs" / "milestones"
    if public_milestone_dir.exists():
        errors.append("docs/milestones must stay archived, not active")

    active_doc_dirs = [
        path.relative_to(ROOT).as_posix()
        for path in sorted((ROOT / "docs").iterdir())
        if path.is_dir()
    ]
    if active_doc_dirs:
        errors.append(f"active docs must stay flat; unexpected directories: {active_doc_dirs}")

    active_plan = ROOT / "plan.md"
    if active_plan.exists():
        required_plan_companions = (
            ROOT / "plan-remediation-ledger.md",
            ROOT / "plan-remediation-status.md",
        )
        missing_companions = [
            path.relative_to(ROOT).as_posix()
            for path in required_plan_companions
            if not path.is_file()
        ]
        if missing_companions:
            errors.append(
                "plan.md is active only with remediation companions: "
                f"missing {missing_companions}"
            )

    for stale_path in (
        ROOT / "docs" / "testing" / "plan-remediation-completion-audit.md",
        ROOT / "docs" / "testing" / "p1-p2-remediation-progress.md",
        ROOT / "docs" / "mac-port" / "PROGRESS.md",
        ROOT / "docs" / "mac-port" / "MILESTONE_INDEX.md",
        ROOT / "docs" / "mac-port" / "STATUS_INDEX.md",
        ROOT / "docs" / "mac-port" / "VALIDATION_CHECKLIST.md",
        ROOT / "docs" / "mac-port" / "HARNESS.md",
        ROOT / "docs" / "mac-port" / "EVIDENCE_AND_CONFLICTS.md",
    ):
        if stale_path.exists():
            errors.append(f"{stale_path.relative_to(ROOT)} must stay archived, not active")

    for rel_path in ACTIVE_MAC_PORT_DOCS:
        path = ROOT / rel_path
        if not path.is_file():
            errors.append(f"missing active implementation/status doc: {rel_path}")
            continue
        text = path.read_text(encoding="utf-8")
        if "Resume here" not in text and "Resume Here" not in text:
            errors.append(f"{rel_path} missing Resume here")
        if "VERDICT: PARTIAL" not in text:
            errors.append(f"{rel_path} missing VERDICT: PARTIAL")

    if not ARCHIVE_MANIFEST.is_file():
        errors.append("missing archive manifest: archive/2026-05-05-doc-consolidation/MANIFEST.md")
    else:
        manifest_text = ARCHIVE_MANIFEST.read_text(encoding="utf-8")
        for rel_path in ARCHIVED_TOPOLOGY_PATHS:
            if rel_path not in manifest_text:
                errors.append(f"archive manifest missing archived lane: {rel_path}")

    for rel_path in ARCHIVED_TOPOLOGY_PATHS:
        if not (ROOT / rel_path).exists():
            errors.append(f"missing archived lane: {rel_path}")

    if not (ROOT / "archive" / "2026-05-11-doc-cleanup" / "README.md").is_file():
        errors.append("missing archive note: archive/2026-05-11-doc-cleanup/README.md")
    if not (ROOT / "archive" / "2026-05-11-doc-condense" / "README.md").is_file():
        errors.append("missing archive note: archive/2026-05-11-doc-condense/README.md")
    if not (ROOT / "archive" / "2026-05-11-win-compiled" / "README.md").is_file():
        errors.append("missing archive note: archive/2026-05-11-win-compiled/README.md")
    if not (ROOT / "archive" / "2026-05-11-mac-port-consolidation" / "README.md").is_file():
        errors.append("missing archive note: archive/2026-05-11-mac-port-consolidation/README.md")

    return errors


def check_archive_top_level_copy_files(root: Path = ROOT) -> list[str]:
    archive_root = root / "archive"
    if not archive_root.is_dir():
        return []

    return [
        f"{path.relative_to(root)}: ambiguous top-level archive copy file"
        for path in sorted(archive_root.glob("* copy.md"))
        if path.is_file()
    ]


def check_implementation_companion() -> list[str]:
    errors: list[str] = []
    if not IMPLEMENTATION_COMPANION.is_file():
        return ["missing implementation handoff: docs/implementation-handoff.md"]

    headings = markdown_h2_headings(IMPLEMENTATION_COMPANION)
    if headings != list(IMPLEMENTATION_COMPANION_HEADINGS):
        errors.append(
            "docs/implementation-handoff.md: implementation handoff section contract mismatch"
        )

    text = IMPLEMENTATION_COMPANION.read_text(encoding="utf-8")
    required_tokens = [
        "M00",
        "M15",
        "G16",
        "Q001",
        "Q010",
        "Core Audio",
        "UDP PCM",
        "AVFoundation",
        "VideoToolbox",
        "OSC",
        "sACN",
        "Art-Net",
        "VERDICT: PARTIAL",
    ]
    for token in required_tokens:
        if token not in text:
            errors.append(f"docs/implementation-handoff.md missing {token}")
    return errors


def check_public_planning_contract() -> list[str]:
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

    for rel_path, text in text_by_path.items():
        if "VERDICT: PARTIAL" not in text:
            errors.append(f"{rel_path}: missing VERDICT: PARTIAL")
        for token in PUBLIC_PLANNING_FORBIDDEN_TOKENS:
            if token in text:
                errors.append(f"{rel_path}: public planning docs contain forbidden token: {token}")
        for token in PUBLIC_ACTIVE_STALE_REFERENCES:
            if token in text:
                errors.append(f"{rel_path}: active public docs contain stale reference: {token}")

    for rel_path in PUBLIC_MILESTONE_DOCS:
        path = ROOT / rel_path
        if not path.is_file():
            continue
        headings = markdown_h2_headings(path)
        if headings != list(PUBLIC_MILESTONE_HEADINGS):
            errors.append(f"{rel_path}: public milestone section contract mismatch")

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


def check_release_hardening_contract() -> list[str]:
    errors: list[str] = []
    public_docs = public_release_docs()
    for doc in public_docs:
        text = remove_fenced_code(doc.read_text(encoding="utf-8"))
        rel_doc = doc.relative_to(ROOT)
        for token in PUBLIC_RELEASE_FORBIDDEN_TOKENS:
            if token in text:
                errors.append(f"{rel_doc}: public release docs contain forbidden token: {token}")
        for raw_target in markdown_links(text):
            target = normalize_link_target(raw_target)
            if target.startswith(PUBLIC_RELEASE_INTERNAL_LINK_PREFIXES):
                errors.append(f"{rel_doc}: public release docs link to internal evidence: {target}")

    if not RELEASE_HARDENING_REPORT.is_file():
        return errors + [
            "missing release hardening report: "
            f"{RELEASE_HARDENING_REPORT.relative_to(ROOT)}"
        ]

    report_text = RELEASE_HARDENING_REPORT.read_text(encoding="utf-8")
    required_tokens = (
        "Public Docs Audited",
        "validate-release-hardening-report",
        "release-hardening-synthetic-smoke",
        "release-hardening-run",
        "VERDICT: PARTIAL",
    )
    for token in required_tokens:
        if token not in report_text:
            errors.append(f"{RELEASE_HARDENING_REPORT.relative_to(ROOT)} missing {token}")
    return errors


def public_release_docs() -> list[Path]:
    docs = set((ROOT / "docs").glob("*.md"))
    return sorted(path for path in docs if path.is_file() and not is_ignored_doc(path))


def evidence_sota_probes() -> list[tuple[int, str, str]]:
    text = EVIDENCE_MATRIX.read_text(encoding="utf-8")
    probes: list[tuple[int, str, str]] = []
    current: tuple[int, str] | None = None
    for line in text.splitlines():
        match = re.match(r"^### (\d+)\. (.+)$", line)
        if match:
            current = (int(match.group(1)), match.group(2))
        if "Open questions and required probe:" in line:
            if current is None:
                probes.append((0, "unknown", line.strip()))
                continue
            probe = line.split("Open questions and required probe:", 1)[1].strip()
            probes.append((current[0], current[1], probe))
    return probes


def check_todo_markers(docs: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in docs:
        text = path.read_text(encoding="utf-8")
        for line_number, line in enumerate(text.splitlines(), start=1):
            if "TODO(human):" not in line:
                continue
            if "->" not in line or line.count("->") < 2:
                errors.append(
                    f"{path.relative_to(ROOT)}:{line_number}: "
                    "TODO(human) marker must use ASCII '->' separators"
                )
    return errors


def check_sota_matrix() -> list[str]:
    errors: list[str] = []
    if not SOTA_MATRIX.is_file():
        return ["missing SOTA probe matrix folded into docs/open-questions.md"]
    if not OPEN_QUESTIONS.is_file():
        return ["missing open questions ledger: docs/open-questions.md"]

    matrix_text = SOTA_MATRIX.read_text(encoding="utf-8")
    open_text = OPEN_QUESTIONS.read_text(encoding="utf-8")

    for index in range(1, 11):
        qid = f"Q{index:03d}"
        if qid not in matrix_text:
            errors.append(f"SOTA matrix missing {qid}")
        if qid not in open_text:
            errors.append(f"docs/open-questions.md missing {qid}")

    probes = evidence_sota_probes()
    if len(probes) != 85:
        errors.append(f"expected 85 SOTA probes, found {len(probes)}")

    for number, title, probe in probes:
        sid = f"SOTA{number:03d}"
        if sid not in matrix_text:
            errors.append(f"SOTA matrix missing {sid}")
        if title not in matrix_text:
            errors.append(f"SOTA matrix missing source title for {sid}: {title}")
        if probe not in matrix_text:
            errors.append(f"SOTA matrix missing probe text for {sid}")

    return errors
