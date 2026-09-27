# Local native-library staging

This ignored directory may hold diagnostic copies of native libraries. It is not
a runtime search location. XIMEA, PortAudio, and Npcap load only from the fixed
absolute Windows locations documented in
[configuration](../../../docs/configuration.md#rust-station).

The runtime does not discover DLLs through `PATH`, executable-adjacent or build
directories, archives, or this directory. Diagnostic copying uses the same
trusted-source policy and refuses to replace an existing destination. Signature
or digest verification is not implemented.

Keep any locally staged binaries out of source control and release exports, and
record the actual loaded library source and version with hardware evidence.
