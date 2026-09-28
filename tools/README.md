# Repository tools

Run these tools from the repository root. They support local builds, asset
generation, and source packaging.

## macOS local bundle and assets

`tools/macos/build_and_run.sh` stages and optionally launches a local app
bundle. `tools/macos/build_cli_app_bundle.sh` assembles the command-line
executable into a local bundle.

Both helpers use ad-hoc signing. They do not create a Developer ID,
notarized, Gatekeeper-verified, or distribution-ready application.

Generate or verify the checked-in icon and social-preview assets with:

```bash
bash tools/macos/generate_brand_assets.sh --check
```

## Source candidate

Create an inspection candidate outside the checkout:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
```

The exporter copies tracked public paths and calls
`tools/verify-release-hygiene.sh`. The release procedure and boundary are in
[docs/RELEASING.md](../docs/RELEASING.md) and
[docs/release-manifest.md](../docs/release-manifest.md).
