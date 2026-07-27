#!/usr/bin/env bash
# Build the macOS app bundle, then launch it with optional inspectable evidence.
set -euo pipefail

MODE="${1:-run}"
APP_NAME="OpenLoLa"
APP_UI_NAME="Open LoLa"
PRODUCT_NAME="open-lola-app"
CLI_PRODUCT_NAME="open-lola"
BUNDLE_ID="de.hfmt.open-lola.app"
MIN_SYSTEM_VERSION="14.0"
VERIFY_EVIDENCE_DIR="${OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
CLI_BINARY="$APP_MACOS/$CLI_PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS_SOURCE="$ROOT_DIR/Sources/open-lola-app/open-lola-app.entitlements"
ENTITLEMENTS_BUNDLE="$APP_RESOURCES/open-lola-app.entitlements"
ICON_SOURCE="$ROOT_DIR/.github/assets/OpenLoLa.icns"
ICON_BUNDLE="$APP_RESOURCES/OpenLoLa.icns"

# Restrict invocation to supported launch, log, telemetry, and verification modes.
validate_mode() {
  case "$MODE" in
    run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
      ;;
    *)
      echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
      exit 2
      ;;
  esac
}

# Build one named SwiftPM product and surface a product-specific failure.
build_product() {
  local product_name="$1"
  swift build --disable-sandbox --product "$product_name" || {
    echo "Build failed: $product_name" >&2
    exit 1
  }
}

# Build the named product and print SwiftPM's resolved binary directory.
product_build_bin_path() {
  local product_name="$1"
  swift build --disable-sandbox --product "$product_name" --show-bin-path || {
    echo "Build path lookup failed: $product_name" >&2
    exit 1
  }
}

# Escape dynamic values before embedding them in the generated Info.plist XML.
xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  value="${value//\'/&apos;}"
  printf '%s' "$value"
}

# List only running processes whose executable belongs to the staged app bundle.
staged_app_pids() {
  local pid
  local command
  while IFS= read -r pid; do
    if [[ -z "$pid" ]]; then
      continue
    fi
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    case "$command" in
      "$APP_BINARY"*)
        printf '%s\n' "$pid"
        ;;
    esac
  done < <(pgrep -u "$USER" -x "$APP_NAME" 2>/dev/null || true)
}

# Stop stale staged app instances before replacing or relaunching the bundle.
terminate_staged_app_processes() {
  local pid
  while IFS= read -r pid; do
    if [[ -n "$pid" ]]; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done < <(staged_app_pids)
}

validate_mode
build_product "$PRODUCT_NAME"
build_product "$CLI_PRODUCT_NAME"
BUILD_DIR="$(product_build_bin_path "$PRODUCT_NAME")"
BUILD_BINARY="$BUILD_DIR/$PRODUCT_NAME"
BUILD_CLI="$BUILD_DIR/$CLI_PRODUCT_NAME"
APP_NAME_XML="$(xml_escape "$APP_NAME")"
BUNDLE_ID_XML="$(xml_escape "$BUNDLE_ID")"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_CLI" "$CLI_BINARY"
cp "$ENTITLEMENTS_SOURCE" "$ENTITLEMENTS_BUNDLE"
[[ -f "$ICON_SOURCE" ]] || {
  echo "app icon source is missing: $ICON_SOURCE" >&2
  exit 1
}
cp "$ICON_SOURCE" "$ICON_BUNDLE"
chmod +x "$APP_BINARY"
chmod +x "$CLI_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME_XML</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>OpenLoLa.icns</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID_XML</string>
  <key>CFBundleName</key>
  <string>Open LoLa</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSCameraUsageDescription</key>
  <string>Open LoLa captures selected camera frames for explicit Mac-to-Mac video transport tests.</string>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Open LoLa sends and receives local UDP media between explicitly configured Mac peers.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Open LoLa captures selected audio inputs for explicit low-latency Mac-to-Mac audio tests.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - --entitlements "$ENTITLEMENTS_BUNDLE" "$APP_BUNDLE"
terminate_staged_app_processes

# Ask Launch Services to start a fresh instance of the staged bundle.
open_app() {
  /usr/bin/open -n -F "$APP_BUNDLE"
}

# Check bundle metadata, executable presence, and ad-hoc code-signature validity.
validate_staged_bundle() {
  [[ -f "$INFO_PLIST" ]] || {
    echo "staged app bundle is missing Info.plist: $INFO_PLIST" >&2
    return 1
  }
  [[ -x "$APP_BINARY" ]] || {
    echo "staged app executable is missing or not executable: $APP_BINARY" >&2
    return 1
  }
  [[ -f "$ICON_BUNDLE" ]] || {
    echo "staged app icon is missing: $ICON_BUNDLE" >&2
    return 1
  }
  local declared_executable
  declared_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
  [[ "$declared_executable" == "$APP_NAME" ]] || {
    echo "CFBundleExecutable mismatch: expected $APP_NAME, got $declared_executable" >&2
    return 1
  }
  local declared_icon
  declared_icon="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO_PLIST")"
  [[ "$declared_icon" == "OpenLoLa.icns" ]] || {
    echo "CFBundleIconFile mismatch: expected OpenLoLa.icns, got $declared_icon" >&2
    return 1
  }
  codesign --verify --deep --strict "$APP_BUNDLE"
}

# Launch through Launch Services while recording stdout, stderr, and exit status.
open_app_with_evidence() {
  local evidence_dir="$1"
  local status=0
  open_app >"$evidence_dir/open.stdout.txt" 2>"$evidence_dir/open.stderr.txt" || status="$?"
  printf '%s\n' "$status" >"$evidence_dir/open.status.txt"
  if (( status != 0 )); then
    echo "Launch Services failed with status $status; see $evidence_dir/open.stderr.txt" >&2
    return "$status"
  fi
}

# Resolve the caller-selected launch-evidence directory or the dist default.
verify_evidence_dir() {
  if [[ -n "$VERIFY_EVIDENCE_DIR" ]]; then
    printf '%s\n' "$VERIFY_EVIDENCE_DIR"
  else
    printf '%s\n' "$DIST_DIR/app-launch-evidence"
  fi
}

# Poll for the staged executable for at most ten seconds after launch.
wait_for_app_process() {
  local deadline=$((SECONDS + 10))
  while (( SECONDS <= deadline )); do
    if [[ -n "$(staged_app_pids)" ]]; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

# Save recent unified-log entries for the staged application process.
capture_app_launch_log() {
  local evidence_dir="$1"
  /usr/bin/log show \
    --style compact \
    --last 2m \
    --predicate "process == \"$APP_NAME\"" \
    >"$evidence_dir/os-log.txt" 2>&1 || true
  if [[ ! -s "$evidence_dir/os-log.txt" ]]; then
    printf 'no recent unified log entries for %s\n' "$APP_NAME" >"$evidence_dir/os-log.txt"
  fi
}

# Record accessibility-visible windows, menus, labels, values, and process identity.
capture_app_ui_evidence() {
  local evidence_dir="$1"
  /usr/bin/osascript >"$evidence_dir/accessibility-ui.txt" 2>"$evidence_dir/accessibility-error.txt" <<APPLESCRIPT
tell application id "$BUNDLE_ID" to activate
delay 0.2
tell application "System Events"
  if not (exists process "$APP_UI_NAME") then error "missing process $APP_UI_NAME"
  tell process "$APP_UI_NAME"
    set processName to "unknown"
    set processDisplayedName to "unknown"
    set processBundleID to "unknown"
    set processFrontmostBeforeActivation to "unknown"
    set processFrontmostAfterActivation to "unknown"
    try
      set processName to name as text
    end try
    try
      set processDisplayedName to displayed name as text
    end try
    try
      set processBundleID to bundle identifier as text
    end try
    try
      set processFrontmostBeforeActivation to frontmost as text
    end try
    try
      set frontmost to true
    end try
    delay 0.2
    try
      set processFrontmostAfterActivation to frontmost as text
    end try
    repeat with attempt from 1 to 40
      if (count of windows) > 0 then exit repeat
      delay 0.25
    end repeat
    if (count of windows) = 0 then error "missing accessibility app window (process=" & processName & ", displayedName=" & processDisplayedName & ", bundleIdentifier=" & processBundleID & ", frontmostBeforeActivation=" & processFrontmostBeforeActivation & ", frontmostAfterActivation=" & processFrontmostAfterActivation & ", accessibilityWindows=0)"
    set uiText to "windows: " & ((name of windows) as text) & linefeed
    try
      set menuLabels to ""
      repeat with menuBarItemRef in menu bar items of menu bar 1
        try
          set menuLabels to menuLabels & (name of menuBarItemRef as text) & linefeed
        end try
        try
          repeat with menuItemRef in menu items of menu 1 of menuBarItemRef
            try
              set menuItemName to name of menuItemRef
              if menuItemName is not missing value and menuItemName is not "" then
                set menuLabels to menuLabels & menuItemName & linefeed
              end if
            end try
          end repeat
        end try
      end repeat
      set uiText to uiText & "menu:" & linefeed & menuLabels
    end try
    try
      set windowLabels to ""
      set windowElements to entire contents of window 1
      repeat with elementRef in windowElements
        try
          set elementName to name of elementRef
          if elementName is not missing value and elementName is not "" then
            set windowLabels to windowLabels & elementName & linefeed
          end if
        end try
        try
          set elementDescription to description of elementRef
          if elementDescription is not missing value and elementDescription is not "" then
            set windowLabels to windowLabels & elementDescription & linefeed
          end if
        end try
        try
          set elementHelp to help of elementRef
          if elementHelp is not missing value and elementHelp is not "" then
            set windowLabels to windowLabels & elementHelp & linefeed
          end if
        end try
        try
          set elementValue to value of elementRef
          if elementValue is not missing value and elementValue is not "" then
            set windowLabels to windowLabels & (elementValue as text) & linefeed
          end if
        end try
      end repeat
      set uiText to uiText & "window:" & linefeed & windowLabels
    end try
    return uiText
  end tell
end tell
APPLESCRIPT
}

# Enumerate visible layer-zero windows and retain the largest matching app window first.
capture_visible_window_evidence() {
  local evidence_dir="$1"
  local app_pid="$2"
  /usr/bin/swift - "$app_pid" "$APP_UI_NAME" >"$evidence_dir/window-list.txt" <<'SWIFT'
import CoreGraphics
import Foundation

let pid = Int(CommandLine.arguments[1]) ?? -1
let displayName = CommandLine.arguments[2]
let windows = (
    CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]]
) ?? []
let matches = windows.filter { window in
    let ownerPID = window[kCGWindowOwnerPID as String] as? Int
    let ownerName = window[kCGWindowOwnerName as String] as? String
    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    return (ownerPID == pid || ownerName == displayName) && layer == 0
}.sorted { lhs, rhs in
    func area(_ window: [String: Any]) -> CGFloat {
        guard let rawBounds = window[kCGWindowBounds as String] else { return 0 }
        let dictionary = rawBounds as! CFDictionary
        guard let bounds = CGRect(dictionaryRepresentation: dictionary) else { return 0 }
        return bounds.width * bounds.height
    }
    return area(lhs) > area(rhs)
}

for window in matches {
    let windowID = window[kCGWindowNumber as String] ?? "unknown"
    let ownerPID = window[kCGWindowOwnerPID as String] ?? "unknown"
    let ownerName = window[kCGWindowOwnerName as String] ?? "unknown"
    let windowName = window[kCGWindowName as String] ?? "unknown"
    let bounds = window[kCGWindowBounds as String] ?? "unknown"
    print("window_id=\(windowID) pid=\(ownerPID) owner=\(ownerName) name=\(windowName) bounds=\(bounds)")
}

if matches.isEmpty {
    fputs("missing visible app window for pid \(pid) / \(displayName)\n", stderr)
    exit(1)
}
SWIFT
}

# Require one literal UI label in the captured accessibility tree.
require_ui_label() {
  local evidence_dir="$1"
  local label="$2"
  if ! grep -Fq "$label" "$evidence_dir/accessibility-ui.txt"; then
    echo "missing launched app UI label in accessibility evidence: $label" >&2
    return 1
  fi
}

# Capture the selected app window and verify the output has a PNG signature.
capture_app_screenshot() {
  local evidence_dir="$1"
  local window_id
  window_id="$(sed -n 's/^window_id=\([0-9][0-9]*\).*/\1/p' "$evidence_dir/window-list.txt" | head -n 1)"
  [[ -n "$window_id" ]] || {
    echo "visible app window evidence did not contain a numeric window ID" >&2
    return 1
  }
  /usr/sbin/screencapture -x -l "$window_id" "$evidence_dir/screenshot.png" >/dev/null 2>&1 || return 1
  [[ -s "$evidence_dir/screenshot.png" ]] || return 1
  local signature
  signature="$(/usr/bin/od -An -tx1 -N8 "$evidence_dir/screenshot.png" | tr -d ' \n')"
  [[ "$signature" == "89504e470d0a1a0a" ]]
}

# Assemble launch evidence and validate the visible alpha application surface.
verify_launched_app_surface() {
  local evidence_dir
  evidence_dir="$(verify_evidence_dir)"
  rm -rf "$evidence_dir"
  mkdir -p "$evidence_dir"
  {
    printf 'app_bundle=%s\n' "$APP_BUNDLE"
    printf 'app_binary=%s\n' "$APP_BINARY"
    printf 'cli_binary=%s\n' "$CLI_BINARY"
    printf 'evidence_class=bundle-launch-ui\n'
    printf 'screenshot_scope=largest-visible-app-window\n'
    printf 'captured_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } >"$evidence_dir/manifest.txt"

  validate_staged_bundle
  open_app_with_evidence "$evidence_dir" || {
    capture_app_launch_log "$evidence_dir"
    return 1
  }
  wait_for_app_process
  local app_pid
  app_pid="$(staged_app_pids | head -n 1)"
  printf '%s\n' "$app_pid" >"$evidence_dir/process.pid"
  capture_app_launch_log "$evidence_dir"
  local accessibility_status=0
  capture_app_ui_evidence "$evidence_dir" || accessibility_status="$?"
  capture_visible_window_evidence "$evidence_dir" "$app_pid"
  capture_app_screenshot "$evidence_dir" || {
    echo "window-scoped screenshot capture failed, was empty, or was not a PNG" >&2
    return 1
  }

  local required_ui_labels=(
    "Session"
    "Connection"
    "Routing"
    "Media"
    "Packets"
    "Review"
    "Diagnostics"
    "Settings"
    "Refresh Local Media Inventory"
    "Refresh Source/Synthetic Report"
    "Arm Execution"
    "Dry Run Supervisor"
    "Start Armed Supervisor"
    "Stop Supervisor Run"
    "Validate Supervisor Report"
    "Evidence Summary"
    "Packet evidence"
    "Not measured"
  )
  if (( accessibility_status == 0 )); then
    local label
    for label in "${required_ui_labels[@]}"; do
      require_ui_label "$evidence_dir" "$label"
    done
  else
    echo "accessibility label capture failed; required UI labels were not verified" >&2
    if [[ -s "$evidence_dir/accessibility-error.txt" ]]; then
      echo "accessibility capture stderr:" >&2
      sed 's/^/  /' "$evidence_dir/accessibility-error.txt" >&2
    fi
    if [[ -s "$evidence_dir/window-list.txt" ]]; then
      echo "visible window evidence captured before accessibility failure:" >&2
      sed 's/^/  /' "$evidence_dir/window-list.txt" >&2
    fi
    return 1
  fi

  echo "native app launch evidence: $evidence_dir"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    verify_launched_app_surface
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
