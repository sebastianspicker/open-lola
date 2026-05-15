# Ghidra Summary: LolaWavSplitter_x64.exe

- Image base: `140000000`
- Executable path: `/Users/sebastian/Git/open-lola/win-compiled/2-0/LolaWavSplitter_x64.exe`
- Language: `x86:LE:64:default`

## Target Import Xrefs

### `WINMM.DLL::mmioCreateChunk`
- `140005240` from `<no function>`
- `140002b5e` from `FUN_140002aa0@140002aa0`
- `140002b81` from `FUN_140002aa0@140002aa0`
- `140002bc8` from `FUN_140002aa0@140002aa0`

### `WINMM.DLL::mmioAscend`
- `140005248` from `<no function>`
- `140002678` from `FUN_140002540@140002540`
- `140002dbd` from `FUN_140002d80@140002d80`
- `140002dd5` from `FUN_140002d80@140002d80`
- `140001f54` from `FUN_140001bb0@140001bb0`
- `140001f6c` from `FUN_140001bb0@140001bb0`
- `140002bac` from `FUN_140002aa0@140002aa0`

### `WINMM.DLL::mmioRead`
- `140005250` from `<no function>`
- `1400028c1` from `FUN_140002840@140002840`
- `140002646` from `FUN_140002540@140002540`

### `WINMM.DLL::mmioClose`
- `140005258` from `<no function>`
- `140002a6a` from `FUN_140002a50@140002a50`
- `140002868` from `FUN_140002840@140002840`
- `1400027a2` from `FUN_140002540@140002540`
- `1400027f7` from `FUN_140002540@140002540`
- `1400025e2` from `FUN_140002540@140002540`
- `14000261c` from `FUN_140002540@140002540`
- `14000265e` from `FUN_140002540@140002540`
- `1400026aa` from `FUN_140002540@140002540`
- `140002703` from `FUN_140002540@140002540`
- `140002de1` from `FUN_140002d80@140002d80`
- `140001f78` from `FUN_140001bb0@140001bb0`
- `140001fd8` from `FUN_140001bb0@140001bb0`
- `140002bd8` from `FUN_140002aa0@140002aa0`

### `WINMM.DLL::mmioDescend`
- `140005260` from `<no function>`
- `1400025d2` from `FUN_140002540@140002540`
- `14000260c` from `FUN_140002540@140002540`
- `14000269a` from `FUN_140002540@140002540`

### `WINMM.DLL::mmioWrite`
- `140005268` from `<no function>`
- `140002d2e` from `FUN_140002c40@140002c40`
- `140002da8` from `FUN_140002d80@140002d80`
- `140001f3f` from `FUN_140001bb0@140001bb0`
- `140002b96` from `FUN_140002aa0@140002aa0`

### `WINMM.DLL::mmioOpenA`
- `140005270` from `<no function>`
- `14000259e` from `FUN_140002540@140002540`
- `140002b29` from `FUN_140002aa0@140002aa0`

### `MFC100.DLL::CWinApp::ExitInstance`
- `140005730` from `<no function>`
- `140002eae` from `ExitInstance@140002eae`

### `MSVCR100.DLL::exit`
- `1400050e0` from `<no function>`
- `1400034c8` from `__tmainCRTStartup@140003358`

### `MSVCR100.DLL::_cexit`
- `1400050e8` from `<no function>`
- `1400034d7` from `__tmainCRTStartup@140003358`

### `MSVCR100.DLL::_exit`
- `1400050f8` from `<no function>`

### `MSVCR100.DLL::_amsg_exit`
- `140005110` from `<no function>`
- `1400038a8` from `_amsg_exit@1400038a8`

### `MSVCR100.DLL::_onexit`
- `140005118` from `<no function>`
- `1400031d4` from `_onexit@1400031b0`

### `MSVCR100.DLL::__dllonexit`
- `140005160` from `<no function>`
- `14000383e` from `__dllonexit@14000383e`

### `KERNEL32.DLL::SetEvent`
- `140005010` from `<no function>`
- `140002006` from `FUN_140001bb0@140001bb0`

### `KERNEL32.DLL::WaitForSingleObject`
- `140005018` from `<no function>`
- `140002149` from `FUN_140002100@140002100`

### `KERNEL32.DLL::ResetEvent`
- `140005030` from `<no function>`
- `140001dd9` from `FUN_140001bb0@140001bb0`

### `KERNEL32.DLL::CreateEventA`
- `1400050b8` from `<no function>`
- `14000166d` from `FUN_1400014e0@1400014e0`

### `SHLWAPI.DLL::PathFileExistsA`
- `1400051f0` from `<no function>`
- `140001be6` from `FUN_140001bb0@140001bb0`

## Target Thunk Callers

### `_onexit@1400031b0`
- `140003264` from `atexit@140003260`

### `atexit@140003260`
- `1400032fb` from `FUN_1400032f0@1400032f0`
- `140004116` from `FUN_1400040e0@1400040e0`
- `140004143` from `FUN_140004120@140004120`

### `MSVCR100.DLL::__dllonexit@14000383e`
- `140003221` from `_onexit@1400031b0`

### `MSVCR100.DLL::_amsg_exit@1400038a8`
- `1400033b9` from `__tmainCRTStartup@140003358`
- `14000334b` from `FUN_1400032f0@1400032f0`

### `AfxInitialize@140003ae0`
- `140004153` from `FUN_140004148@140004148`

## Caller Clusters
- `FUN_140001bb0@140001bb0` -> mmioAscend, mmioClose, mmioWrite, SetEvent, ResetEvent, PathFileExistsA
- `FUN_140002540@140002540` -> mmioAscend, mmioRead, mmioClose, mmioDescend, mmioOpenA
- `FUN_140002840@140002840` -> mmioRead, mmioClose
- `FUN_140002aa0@140002aa0` -> mmioCreateChunk, mmioAscend, mmioClose, mmioWrite, mmioOpenA
- `FUN_140002d80@140002d80` -> mmioAscend, mmioClose, mmioWrite
- `FUN_1400032f0@1400032f0` -> atexit, _amsg_exit
- `__tmainCRTStartup@140003358` -> exit, _cexit, _amsg_exit
- `_onexit@1400031b0` -> _onexit, __dllonexit

## Target String Xrefs

### `140005e20` `Input file is already mono.\nThe file must contain at least 2 audio channels.`
- `140001976` from `FUN_1400017d0@1400017d0`

### `140005f38` `Conversion completed.`
- `140001ef0` from `FUN_140001bb0@140001bb0`

### `140005f70` `Conversion process is not completed.\n\nAre you sure you want to exit the program?`
- `140002119` from `FUN_140002100@140002100`

### `140005fe0` `Lola Wav Splitter - Version 1.0.14\n\n(c) Conservatorio "G.Tartini " - Trieste\nhttp://www.conservatorio.trieste.it/artistica/lola-project/\n\nDeveloper: Stefano Bonetti`

### `14001062e` `FileVersion`

### `1400107fa` `ProductVersion`

## Decompiler Signal Matrix
- `FUN_140002aa0@140002aa0` -> 0x40, 100, mmioWrite
- `FUN_140002540@140002540` -> 100
- `FUN_140002d80@140002d80` -> 0x40, mmioWrite
- `FUN_140001bb0@140001bb0` -> 0x40, 100, mmioWrite, SetEvent
- `FUN_140002c40@140002c40` -> 0x40, mmioWrite
- `__tmainCRTStartup@140003358` -> 100, 0x21
- `FUN_140002100@140002100` -> 100, 0x21, WaitForSingleObject
- `FUN_1400014e0@1400014e0` -> 0x40
- `FUN_1400017d0@1400017d0` -> 100
