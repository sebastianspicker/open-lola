SHELL := /bin/bash

UV ?= uv
DEVELOPER_DIR ?= $(if $(wildcard /Applications/Xcode-26.6.0.app/Contents/Developer),/Applications/Xcode-26.6.0.app/Contents/Developer,/Applications/Xcode_26.6.app/Contents/Developer)
LINUX_CONNECTOR_ROOT := runtimes/linux-compat-connector
SWIFT_BUILD_PATH ?= /private/tmp/open-lola-swiftpm-build
PYTHON_RUN := $(UV) run --locked --extra dev

.PHONY: architecture architecture-self-test test-swift test-python test-rust lint verify swift-test rust-fmt rust-clippy rust-test python-ruff python-mypy python-pytest python-selftest python rust all

architecture: architecture-self-test
	$(PYTHON_RUN) python tools/verify_architecture.py

architecture-self-test:
	$(PYTHON_RUN) python tools/verify_architecture.py --self-test

test-swift:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" swift test --disable-sandbox --scratch-path "$(SWIFT_BUILD_PATH)"

rust-fmt:
	cargo fmt --all -- --check

rust-clippy:
	cargo clippy --workspace --all-targets --all-features -- -D warnings -D clippy::undocumented_unsafe_blocks -D clippy::missing_safety_doc

rust-test:
	cargo test --workspace --all-targets --all-features

python-ruff:
	$(PYTHON_RUN) ruff check $(LINUX_CONNECTOR_ROOT)/linux_connector tools/verify_docs tools/lib/*.py tools/verify_source_documentation.py tools/verify_architecture.py

python-mypy:
	$(PYTHON_RUN) mypy --strict $(LINUX_CONNECTOR_ROOT)/linux_connector/lola_connector tools/verify_docs tools/lib/*.py tools/verify_source_documentation.py tools/verify_architecture.py

python-pytest:
	PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$(LINUX_CONNECTOR_ROOT)" $(PYTHON_RUN) pytest -p no:cacheprovider $(LINUX_CONNECTOR_ROOT)/linux_connector/tests

python-selftest:
	PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$(LINUX_CONNECTOR_ROOT)" $(PYTHON_RUN) python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25

test-python: python-ruff python-mypy python-pytest python-selftest

lint: python-ruff python-mypy rust-fmt rust-clippy

python: test-python

verify:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" OPEN_LOLA_SKIP_INTERACTIVE_APP=1 OPEN_LOLA_SKIP_LIVE_RESIDUE=1 $(PYTHON_RUN) bash tools/verify-release-readiness.sh

test-rust: rust-fmt rust-clippy rust-test

swift-test: test-swift

rust: test-rust

all: verify
