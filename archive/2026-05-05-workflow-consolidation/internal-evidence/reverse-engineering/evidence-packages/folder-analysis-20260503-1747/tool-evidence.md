# Tool Evidence And Boundaries

- Generated: `2026-05-03T18:01:16` local time.
- Target: `win-compiled/2-0`
- File count: `29`
- Role counts: `{"config": 3, "dll": 19, "exe": 4, "installer": 2, "metadata": 1}`

## Tools Used

- `file`: file-5.41
- `shasum`: 6.04
- `strings`: available
- `rabin2`: rabin2 6.1.4 +0 abi:83 @ darwin-arm_64
- `python3`: Python 3.13.5
- `lief`: 0.16.4-
- `Ghidra analyzeHeadless`: rerun succeeded with OpenJDK 25 on the primary GUI and the LoLa-owned helper/tester EXEs; outputs: `ghidra/v2-main.audio-deep.md`, `ghidra/v2-main.ghidra-summary.md`, `ghidra/v2-main.network-session-deep.md`, `ghidra/v2-main.video-deep.md`, `ghidra/v2-tester.ghidra-summary.md`, `ghidra/v2-video-converter.ghidra-summary.md`, `ghidra/v2-wav-splitter.ghidra-summary.md`

## Static Boundary

- No unknown binaries were executed.
- No network commands were run.
- No source code or binary patching was needed.
- No licensing, DRM, authentication, or access-control bypass was attempted.
- No usable credentials or secrets were extracted; secret-like value patterns are redacted in string output.
- Mach-O-specific tools (`otool`, `lipo`, `nm`, `codesign`, `spctl`) were not applied because this folder contains no Mach-O, `.dylib`, or framework binaries.
- `sqlite3` was not applied because no database file was found.
- Installer payloads were identified as NSIS PE files and analyzed statically; payload extraction should be done offline with NSIS-aware tools if needed.

## Reproduction Commands

```sh
python3 reverse-engineering/evidence-packages/folder-analysis-20260503-1747/tools/static_inventory.py
find win-compiled/2-0 -type f -print0 | xargs -0 file
find win-compiled/2-0 -type f -print0 | xargs -0 shasum -a 256
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp lola-folder-analysis-20260503-1747-main-jdk25 -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-main -postScript LoLaAudioDeepDive.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-main -postScript LoLaVideoDeepDive.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-main -postScript LoLaNetworkSessionDeepDive.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-main -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp lola-folder-analysis-20260503-1747-tester -import win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-tester -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp lola-folder-analysis-20260503-1747-video-converter -import win-compiled/2-0/LolaVideoConverter_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-video-converter -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp lola-folder-analysis-20260503-1747-wav-splitter -import win-compiled/2-0/LolaWavSplitter_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java reverse-engineering/evidence-packages/folder-analysis-20260503-1747/ghidra v2-wav-splitter -deleteProject
```
