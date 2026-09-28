SHELL := /bin/bash

SWIFT_BUILD_PATH ?= /private/tmp/open-lola-swiftpm-build

.PHONY: swift-build rust-build rust-cli-build rust-fmt rust-clippy web-lint shellcheck lint verify all

swift-build:
	swift build --disable-sandbox --scratch-path "$(SWIFT_BUILD_PATH)" -Xswiftc -warnings-as-errors

rust-build:
	cargo build --workspace --all-features

rust-cli-build:
	cargo build --workspace --no-default-features

rust-fmt:
	cargo fmt --all -- --check

rust-clippy:
	cargo clippy --workspace --bins --lib --all-features -- -D warnings -D clippy::undocumented_unsafe_blocks -D clippy::missing_safety_doc

web-lint:
	node --check web/demo/app.js

shellcheck:
	shellcheck -x tools/*.sh tools/lib/*.sh tools/macos/*.sh

lint: rust-fmt rust-clippy web-lint shellcheck

verify: swift-build rust-build rust-cli-build lint

all: verify
