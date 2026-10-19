# Local native-library staging

This ignored directory may hold diagnostic copies of native libraries. It is not
a runtime search location. XIMEA, PortAudio, and Npcap load only from the trusted
Windows locations documented in
[configuration](../../../docs/configuration.md#rust-station): the system and vendor
directories first, then the known vendor DLL file names directly beside the running
executable as a last fallback (never on a UNC or network path).

The runtime does not discover DLLs through `PATH`, build directories, archives, or
this directory. The allowlist applies only to the top-level DLL; its imports resolve
from that DLL's directory (`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`) and System32.
Diagnostic copying uses the same
trusted-source policy and refuses to replace an existing destination. Signature
or digest verification is not implemented.

Keep any locally staged binaries out of source control and release exports, and
record the actual loaded library source and version with hardware evidence.
