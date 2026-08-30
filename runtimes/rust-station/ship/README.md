# ship/ — optional probe DLLs

This folder is for **local** vendor DLL copies used only by optional backend
probes (`xiapi64.dll`, `portaudio_x64.dll`, `jpeg62.dll`, …).

Nothing here is required for `cargo test` or the software station path.

## Populate from the closed archive

From the workspace root (adjust if your archive path differs):

```text
copy archive\lola-closed-2.0\xiapi64.dll runtimes\rust-station\ship\
copy archive\lola-closed-2.0\portaudio_x64.dll runtimes\rust-station\ship\
copy archive\lola-closed-2.0\jpeg62.dll runtimes\rust-station\ship\
```

`*.dll` files under `ship/` are gitignored — they are closed/third-party
binaries and should not land in a public repo without clear redistribution
rights.
