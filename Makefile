SHELL := /bin/bash

UV ?= uv
DEVELOPER_DIR ?= $(or $(firstword $(wildcard /Applications/Xcode-26.6.0.app/Contents/Developer /Applications/Xcode_26.6.app/Contents/Developer)),$(shell xcode-select -p 2>/dev/null))
# OPEN_LOLA_SWIFT_BUILD_PATH is the one name shared with the scripts under tools/.
# SWIFT_BUILD_PATH is a deprecated fallback; the shared default below is only a
# convenience, so set a per-checkout path when several checkouts build at once.
OPEN_LOLA_SWIFT_BUILD_PATH ?= $(or $(SWIFT_BUILD_PATH),/private/tmp/open-lola-swiftpm-build)
$(if $(SWIFT_BUILD_PATH),$(warning SWIFT_BUILD_PATH is deprecated; use OPEN_LOLA_SWIFT_BUILD_PATH))
PYTHON_RUN := $(UV) run --locked --extra dev

.PHONY: verify-full architecture architecture-self-test code-quality code-quality-self-test test-python test-rust lint shellcheck swift-lint web-lint workflow-lint verify swift-build swift-test rust-fmt rust-clippy rust-test rust-cli-test python-ruff python-mypy python-tool-tests python rust all

architecture: architecture-self-test
	$(PYTHON_RUN) python tools/verify_architecture.py

architecture-self-test:
	$(PYTHON_RUN) python tools/verify_architecture.py --self-test

code-quality:
	$(PYTHON_RUN) python tools/verify_code_quality.py

code-quality-self-test:
	$(PYTHON_RUN) python tools/verify_code_quality.py --self-test

rust-fmt:
	cargo fmt --all -- --check

rust-clippy:
	cargo clippy --workspace --all-targets --all-features -- -D warnings -D clippy::undocumented_unsafe_blocks -D clippy::missing_safety_doc

rust-test:
	cargo test --workspace --all-targets --all-features

rust-cli-test:
	cargo test --workspace --all-targets --no-default-features

python-ruff:
	$(PYTHON_RUN) ruff check tools/verify_docs tools/lib/*.py tools/verify_source_documentation.py tools/verify_architecture.py tools/verify_code_quality.py tools/verify_pmr14_runtime_contract.py

python-mypy:
	$(PYTHON_RUN) mypy --strict tools/verify_docs tools/lib/*.py tools/verify_source_documentation.py tools/verify_architecture.py tools/verify_code_quality.py tools/verify_pmr14_runtime_contract.py

python-tool-tests:
	$(PYTHON_RUN) python tools/verify_architecture.py --self-test
	$(PYTHON_RUN) python tools/verify_code_quality.py --self-test
	$(PYTHON_RUN) python tools/verify_source_documentation.py --self-test
	$(PYTHON_RUN) python -m tools.verify_docs

test-python: python-ruff python-mypy python-tool-tests

shellcheck:
	shellcheck -x tools/*.sh tools/lib/*.sh tools/macos/*.sh

swift-lint: swift-build

swift-build:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" swift build --disable-sandbox --scratch-path "$(OPEN_LOLA_SWIFT_BUILD_PATH)" -Xswiftc -warnings-as-errors

# Test sources are not published; without a local runtimes/macos/Tests this builds instead.
swift-test:
	if [ -d runtimes/macos/Tests ]; then \
		DEVELOPER_DIR="$(DEVELOPER_DIR)" swift test --disable-sandbox --scratch-path "$(OPEN_LOLA_SWIFT_BUILD_PATH)" -Xswiftc -warnings-as-errors; \
	else \
		echo "SKIPPED: no local Swift test sources (runtimes/macos/Tests); building only"; \
		$(MAKE) swift-build; \
	fi

web-lint:
	node --check web/demo/app.js

workflow-lint:
	test "$$(actionlint -version | head -n 1)" = "1.7.12"
	actionlint

lint: code-quality code-quality-self-test python-ruff python-mypy shellcheck swift-lint web-lint workflow-lint rust-fmt rust-clippy

python: test-python

# Headless-safe gate: skips the GUI launch probe and the raw-checkout residue scan.
# The script prints a "SKIPPED:" line for each skip.
verify:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" OPEN_LOLA_SWIFT_BUILD_PATH="$(OPEN_LOLA_SWIFT_BUILD_PATH)" OPEN_LOLA_SKIP_INTERACTIVE_APP=1 OPEN_LOLA_SKIP_LIVE_RESIDUE=1 $(PYTHON_RUN) bash tools/verify-release-readiness.sh

# Complete local gate: needs a logged-in GUI session and a checkout without generated residue.
verify-full:
	DEVELOPER_DIR="$(DEVELOPER_DIR)" OPEN_LOLA_SWIFT_BUILD_PATH="$(OPEN_LOLA_SWIFT_BUILD_PATH)" OPEN_LOLA_SKIP_INTERACTIVE_APP=0 OPEN_LOLA_SKIP_LIVE_RESIDUE=0 $(PYTHON_RUN) bash tools/verify-release-readiness.sh

test-rust: rust-fmt rust-clippy rust-test rust-cli-test


rust: test-rust

all: verify
