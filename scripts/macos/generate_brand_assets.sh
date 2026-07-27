#!/usr/bin/env bash
# Render and verify the checked-in Open LoLa social preview and macOS icon.
set -euo pipefail

mode="${1:-write}"
case "$mode" in
  write|--check)
    ;;
  *)
    echo "usage: $0 [write|--check]" >&2
    exit 2
    ;;
esac

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
asset_directory="$repository_root/.github/assets"
temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/open-lola-brand-assets.XXXXXX")"
generated_icon="$temporary_root/OpenLoLa.icns"
generated_preview="$temporary_root/open-lola-social-preview.png"
base_icon="$temporary_root/open-lola-app-icon.png"

# Remove only this run's temporary raster and icon intermediates.
cleanup() {
  rm -rf "$temporary_root"
}
trap cleanup EXIT

# Downsample the 1024px source render into one ICNS representation.
render_square_png() {
  local pixels="$1"
  local output="$2"
  sips --resampleHeightWidth "$pixels" "$pixels" "$base_icon" --out "$output" >/dev/null
}

swift "$repository_root/scripts/macos/render_svg.swift" \
  "$asset_directory/open-lola-app-icon.svg" "$base_icon" 1024 1024
render_square_png 16 "$temporary_root/icon-16.png"
render_square_png 32 "$temporary_root/icon-32.png"
render_square_png 64 "$temporary_root/icon-64.png"
render_square_png 128 "$temporary_root/icon-128.png"
render_square_png 256 "$temporary_root/icon-256.png"
render_square_png 512 "$temporary_root/icon-512.png"
swift "$repository_root/scripts/macos/build_icns.swift" "$generated_icon" \
  "icp4=$temporary_root/icon-16.png" \
  "icp5=$temporary_root/icon-32.png" \
  "icp6=$temporary_root/icon-64.png" \
  "ic07=$temporary_root/icon-128.png" \
  "ic08=$temporary_root/icon-256.png" \
  "ic09=$temporary_root/icon-512.png" \
  "ic10=$base_icon"
swift "$repository_root/scripts/macos/render_svg.swift" \
  "$asset_directory/open-lola-social-preview.svg" "$generated_preview" 1280 640

if [[ "$mode" == "--check" ]]; then
  cmp -s "$generated_icon" "$asset_directory/OpenLoLa.icns" || {
    echo "OpenLoLa.icns is not reproducible from open-lola-app-icon.svg" >&2
    exit 1
  }
  cmp -s "$generated_preview" "$asset_directory/open-lola-social-preview.png" || {
    echo "open-lola-social-preview.png is not reproducible from its SVG source" >&2
    exit 1
  }
  echo "Brand assets are current and reproducible."
  exit 0
fi

cp "$generated_icon" "$asset_directory/OpenLoLa.icns"
cp "$generated_preview" "$asset_directory/open-lola-social-preview.png"
echo "Rendered OpenLoLa.icns and open-lola-social-preview.png."
