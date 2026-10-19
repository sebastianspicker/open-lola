# Local native-library staging

This git-ignored directory can hold diagnostic copies of native libraries. The
runtime never loads libraries from it.

XIMEA, PortAudio, and Npcap load only from the Windows locations listed in
[configuration](../../../docs/configuration.md#rust-station): the system and
vendor directories first, then, as a last resort, the known vendor DLL file
names next to the running executable (never on a UNC or network path). `PATH`,
build directories, archives, and this directory are not searched. These rules
cover only the top-level DLL. Its imports resolve from that DLL's directory
(`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`) and System32.

Diagnostic copying uses the same source rules and never overwrites an existing
file. Signatures and digests are not checked.

Keep staged binaries out of source control and release exports. When you record
hardware results, note which library file and version were actually loaded.
