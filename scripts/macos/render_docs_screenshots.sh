#!/usr/bin/env bash
# Render the approved documentation screenshots from the current macOS app surface.
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
output_directory="${OPEN_LOLA_DOC_SCREENSHOT_DIR:-$repository_root/.github/assets}"
scratch_directory="/private/tmp/open-lola-doc-screenshots"

mkdir -p "$output_directory" "$scratch_directory"

cd "$repository_root"
OPEN_LOLA_DOC_SCREENSHOT_DIR="$output_directory" \
swift test --disable-sandbox --scratch-path "$scratch_directory" \
  --filter AppDocumentationScreenshotTests
