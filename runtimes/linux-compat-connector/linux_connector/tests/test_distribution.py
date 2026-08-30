"""Distribution and connector-dependency boundary checks."""

from __future__ import annotations

import ast
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[4]
RUNTIME_ROOT = REPOSITORY_ROOT / "runtimes/linux-compat-connector/linux_connector"
PACKAGE_ROOT = RUNTIME_ROOT / "lola_connector"


def test_connector_import_graph_is_acyclic() -> None:
    """Keep the composed connector services in an acyclic dependency DAG."""
    graph = {path.stem: _internal_imports(path) for path in PACKAGE_ROOT.glob("*.py")}
    for dependencies in graph.values():
        assert dependencies <= graph.keys()
    visited: set[str] = set()
    active: set[str] = set()

    def visit(module: str) -> None:
        assert module not in active, f"connector import cycle includes {module}"
        if module in visited:
            return
        active.add(module)
        for dependency in graph[module]:
            if dependency in graph:
                visit(dependency)
        active.remove(module)
        visited.add(module)

    for module in graph:
        visit(module)


def test_wheel_contains_only_runtime_packages_and_runs_clean_cli(tmp_path: Path) -> None:
    """Build and install the wheel without inheriting source-tree imports."""
    uv = shutil.which("uv")
    assert uv is not None, "uv is required for the locked distribution check"
    source_copy = tmp_path / "distribution-source"
    source_copy.mkdir()
    shutil.copy2(REPOSITORY_ROOT / "pyproject.toml", source_copy / "pyproject.toml")
    shutil.copy2(REPOSITORY_ROOT / "LICENSE", source_copy / "LICENSE")
    shutil.copy2(REPOSITORY_ROOT / "NOTICE", source_copy / "NOTICE")
    (source_copy / "runtimes").mkdir()
    shutil.copytree(
        REPOSITORY_ROOT / "runtimes/linux-compat-connector",
        source_copy / "runtimes/linux-compat-connector",
        ignore=shutil.ignore_patterns("__pycache__", "*.egg-info"),
    )
    cache_dir = tmp_path / "uv-cache"
    wheel_dir = tmp_path / "wheel"
    build = subprocess.run(
        [uv, "build", "--wheel", "--out-dir", str(wheel_dir)],
        cwd=source_copy,
        check=False,
        capture_output=True,
        text=True,
        env={**os.environ, "UV_CACHE_DIR": str(cache_dir)},
        timeout=60,
    )
    assert build.returncode == 0, build.stderr
    wheel = next(wheel_dir.glob("*.whl"))
    with zipfile.ZipFile(wheel) as archive:
        names = set(archive.namelist())
    assert "linux_connector/lola_connector/connector.py" in names
    assert "linux_connector/lola_connector/control_exchange.py" in names
    assert "linux_connector/lola_connector/media_receiver.py" in names
    assert not any(name.startswith("linux_connector/tests/") for name in names)
    assert not any(name.startswith("linux_connector/deployment/") for name in names)
    assert not any(name.startswith("linux_connector/tools/") for name in names)

    environment = tmp_path / "clean-environment"
    subprocess.run([sys.executable, "-m", "venv", str(environment)], check=True, timeout=30)
    python = environment / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    clean_environment = os.environ.copy()
    for inherited_path in ("PYTHONHOME", "PYTHONPATH", "VIRTUAL_ENV"):
        clean_environment.pop(inherited_path, None)
    install = subprocess.run(
        [str(python), "-m", "pip", "install", "--no-deps", "--force-reinstall", str(wheel)],
        check=False,
        capture_output=True,
        text=True,
        env=clean_environment,
    )
    assert install.returncode == 0, install.stderr
    selftest = subprocess.run(
        [str(python), "-m", "linux_connector.lola_connector.cli", "--local-ip", "127.0.0.1", "selftest", "--duration", "0.25"],
        cwd=tmp_path,
        check=False,
        capture_output=True,
        text=True,
        timeout=15,
        env=clean_environment,
    )
    assert selftest.returncode == 0, selftest.stderr
    assert "endpoint_a=" in selftest.stdout and "endpoint_b=" in selftest.stdout


def _internal_imports(path: Path) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"))
    imports: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.level == 1 and node.module:
            imports.add(node.module.split(".", maxsplit=1)[0])
    return imports
