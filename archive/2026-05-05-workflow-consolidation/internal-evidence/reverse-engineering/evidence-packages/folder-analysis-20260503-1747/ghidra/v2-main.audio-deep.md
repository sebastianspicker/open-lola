# LoLa Audio Deep Dive: LolaGui_XIMEA_x64.exe

- Executable path: `/Users/sebastian/Git/open-lola/win-compiled/2-0/LolaGui_XIMEA_x64.exe`
- Image base: `140000000`

## Target Function Summaries

### `140004dd0`
- Function: `FUN_140004dd0@140004dd0`
- Body: `140004dd0..140004ddf`
- Calls: (none)
- Referenced strings: (none)
- Incoming callers: `140015555` from `FUN_1400152d0@1400152d0`, `14001585c` from `FUN_1400152d0@1400152d0`, `140015b00` from `FUN_1400152d0@1400152d0`
- Decompiler signals: (none)

### `140006e90`
- Function: `FUN_140006e90@140006e90`
- Body: `140006e90..140006e9d`
- Calls: (none)
- Referenced strings: (none)
- Incoming callers: `140015542` from `FUN_1400152d0@1400152d0`, `140015849` from `FUN_1400152d0@1400152d0`, `140015aed` from `FUN_1400152d0@1400152d0`
- Decompiler signals: (none)

### `140006f00`
- Function: `FUN_140006f00@140006f00`
- Body: `140006f00..140006f8f`
- Calls: free@1400363fc, operator_new@14003643c, memset@140039b36, FUN_140007320@140007320
- Referenced strings: (none)
- Incoming callers: `14001551c` from `FUN_1400152d0@1400152d0`, `140015aa4` from `FUN_1400152d0@1400152d0`, `140015fb1` from `FUN_1400152d0@1400152d0`
- Decompiler signals: 0x40

### `1400070b0`
- Function: `FUN_1400070b0@1400070b0`
- Body: `1400070b0..1400071fb`
- Calls: operator_new@14003643c, FUN_140006df0@140006df0, memcpy@140039b1e
- Referenced strings: (none)
- Incoming callers: `140009e1d` from `FUN_140009bf0@140009bf0`, `1400117e7` from `FUN_1400115c0@1400115c0`, `140012040` from `FUN_140011c10@140011c10`
- Decompiler signals: 0x21

### `140007200`
- Function: `FUN_140007200@140007200`
- Body: `140007200..14000724c`
- Calls: memcpy@140039b1e
- Referenced strings: (none)
- Incoming callers: `140015527` from `FUN_1400152d0@1400152d0`, `1400157ad` from `FUN_1400152d0@1400152d0`, `140015930` from `FUN_1400152d0@1400152d0`
- Decompiler signals: 0x40, 0x21

### `140007980`
- Function: `FUN_140007980@140007980`
- Body: `140007980..14000865c`
- Calls: `eh_vector_constructor_iterator'@140036d30, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, FUN_140004a10@140004a10, InitializeCriticalSection@EXTERNAL:0000020b, CreateEventA@EXTERNAL:000001ed, operator=@EXTERNAL:000001a1, Pa_Initialize@1400360ed, Pa_GetHostApiCount@1400360f9, Pa_GetHostApiInfo@1400360ff, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, Compare@EXTERNAL:0000019f, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, Pa_HostApiDeviceIndexToDeviceIndex@140036105, Pa_GetDeviceInfo@14003610b, operator=@EXTERNAL:000001a2, FUN_14000ab60@14000ab60
- Referenced strings: `1400440a0` `WriteEvent`, `1400440b0` `AudSndThreadEnded`, `1400440c8` `LocRecThreadEnded`, `1400440e0` `RemRecThreadEnded`, `1400440f8` `LOLA_REC`
- Incoming callers: `1400294ed` from `FUN_140029370@140029370`
- Decompiler signals: Pa_, CreateEvent, WriteEvent, AudSndThreadEnded, LocRecThreadEnded, RemRecThreadEnded, 0x40, 0x2a, 0x21

### `1400086e0`
- Function: `FUN_1400086e0@1400086e0`
- Body: `1400086e0..1400089d8`
- Calls: FUN_14000a770@14000a770, Pa_IsStreamActive@14003612f, Pa_IsStreamStopped@140036129, Pa_Terminate@1400360f3, SetEvent@EXTERNAL:000001ef, WaitForSingleObject@EXTERNAL:000001fa, CloseHandle@EXTERNAL:00000206, free@1400364f4, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, `eh_vector_destructor_iterator'@140036da8, FUN_140004a40@140004a40, free@1400363fc, _invalid_parameter_noinfo_noreturn@EXTERNAL:000002a5
- Referenced strings: (none)
- Incoming callers: `140008a8f` from `FUN_140008a80@140008a80`
- Decompiler signals: Pa_, SetEvent, WaitForSingleObject, 0x40

### `140008b10`
- Function: `FUN_140008b10@140008b10`
- Body: `140008b10..140008e77`
- Calls: sin@140039b96, __security_check_cookie@1400364d0
- Referenced strings: (none)
- Incoming callers: `140009d42` from `FUN_140009bf0@140009bf0`
- Decompiler signals: 0x40

### `140009010`
- Function: `FUN_140009010@140009010`
- Body: `140009010..140009106`
- Calls: Pa_IsStreamActive@14003612f, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b7, Compare@EXTERNAL:0000019f, Pa_HostApiDeviceIndexToDeviceIndex@140036105, PaAsio_GetAvailableBufferSizes@140036135, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af
- Referenced strings: (none)
- Incoming callers: `1400299b2` from `FUN_140029370@140029370`, `1400299db` from `FUN_140029370@140029370`, `140029a0b` from `FUN_140029370@140029370`, `14002d76f` from `FUN_14002d090@14002d090`
- Decompiler signals: Pa_, PaAsio

### `1400093a0`
- Function: `FUN_1400093a0@1400093a0`
- Body: `1400093a0..140009ac8`
- Calls: Pa_IsStreamActive@14003612f, Pa_CloseStream@140036117, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b7, Compare@EXTERNAL:0000019f, Pa_HostApiDeviceIndexToDeviceIndex@140036105, Pa_GetDeviceInfo@14003610b, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, operator_new@14003643c, operator=@EXTERNAL:000001a2, Pa_OpenStream@140036111, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, Pa_GetErrorText@1400360e7, Format@EXTERNAL:00000197, MessageBoxA@EXTERNAL:00000228, free@1400364f4, memset@140039b36
- Referenced strings: `140044110` `ASIOAudio: dev open stream error (+%s)`, `140044138` `ASIOAudio`
- Incoming callers: `14002ef0f` from `FUN_14002ee30@14002ee30`
- Decompiler signals: Pa_, 0x40

### `140009ad0`
- Function: `FUN_140009ad0@140009ad0`
- Body: `140009ad0..140009bcf`
- Calls: ResetEvent@EXTERNAL:000001ee, operator_new@140036e9c, operator_new@14003643c, memcpy@140039b1e, FUN_1400215a0@1400215a0, Sleep@EXTERNAL:00000207, SetEvent@EXTERNAL:000001ef
- Referenced strings: (none)
- Incoming callers: `140009bd4` from `FUN_140009bd0@140009bd0`
- Decompiler signals: SetEvent, ResetEvent

### `140009bf0`
- Function: `FUN_140009bf0@140009bf0`
- Body: `140009bf0..140009ff5`
- Calls: operator_new@140036e9c, FUN_140006c50@140006c50, FUN_140007250@140007250, FUN_1400209e0@1400209e0, FUN_140006ef0@140006ef0, operator_new@14003643c, memset@140039b36, FUN_140008b10@140008b10, ResetEvent@EXTERNAL:000001ee, FUN_140004dc0@140004dc0, FUN_140004ff0@140004ff0, WaitForSingleObject@EXTERNAL:000001fa, FUN_140004e40@140004e40, FUN_140004bf0@140004bf0, FUN_1400070b0@1400070b0, FUN_140006ee0@140006ee0, EnterCriticalSection@EXTERNAL:0000020a, Ordinal_11@EXTERNAL:000002cd, ... +8 more
- Referenced strings: (none)
- Incoming callers: `140009be4` from `FUN_140009be0@140009be0`
- Decompiler signals: pcap_, SetEvent, ResetEvent, WaitForSingleObject, 0x2a, 0x21

### `14000a000`
- Function: `FUN_14000a000@14000a000`
- Body: `14000a000..14000a30c`
- Calls: GetBuffer@EXTERNAL:000001bc, FUN_14000ab60@14000ab60, operator=@EXTERNAL:000001a2, pcap_findalldevs@140036147, strstr@140039b2a, FUN_140020660@140020660, FUN_1400205b0@1400205b0, EnterCriticalSection@EXTERNAL:0000020a, pcap_open@14003614d, LeaveCriticalSection@EXTERNAL:00000209, AfxBeginThread@140037dfe, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, __security_check_cookie@1400364d0
- Referenced strings: (none)
- Incoming callers: `14002be89` from `FUN_14002b9b0@14002b9b0`, `14002fbdd` from `FUN_14002f3d0@14002f3d0`
- Decompiler signals: pcap_

### `14000a350`
- Function: `FUN_14000a350@14000a350`
- Body: `14000a350..14000a397`
- Calls: Pa_StartStream@14003611d
- Referenced strings: (none)
- Incoming callers: `14002ef20` from `FUN_14002ee30@14002ee30`
- Decompiler signals: Pa_

### `14000a710`
- Function: `FUN_14000a710@14000a710`
- Body: `14000a710..14000a767`
- Calls: Pa_IsStreamStopped@140036129, Pa_StopStream@140036123
- Referenced strings: (none)
- Incoming callers: `14002eea2` from `FUN_14002ee30@14002ee30`
- Decompiler signals: Pa_

### `14000a930`
- Function: `FUN_14000a930@14000a930`
- Body: `14000a930..14000aa4b`
- Calls: CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, ResetEvent@EXTERNAL:000001ee, operator_new@140036e9c, operator_new@14003643c, memcpy@140039b1e, FUN_1400215a0@1400215a0, Sleep@EXTERNAL:00000207, SetEvent@EXTERNAL:000001ef, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af
- Referenced strings: (none)
- Incoming callers: `14000aa54` from `FUN_14000aa50@14000aa50`
- Decompiler signals: SetEvent, ResetEvent

### `14000aaa0`
- Function: `FUN_14000aaa0@14000aaa0`
- Body: `14000aaa0..14000aae2`
- Calls: (none)
- Referenced strings: (none)
- Incoming callers: `140029912` from `FUN_140029370@140029370`, `14002d99d` from `FUN_14002d090@14002d090`, `14002ddf7` from `FUN_14002ddf0@14002ddf0`
- Decompiler signals: (none)

### `14000acb0`
- Function: `FUN_14000acb0@14000acb0`
- Body: `14000acb0..14000acda`
- Calls: FUN_14000ad00@14000ad00
- Referenced strings: (none)
- Incoming callers: (none)
- Decompiler signals: (none)

### `14000ad00`
- Function: `FUN_14000ad00@14000ad00`
- Body: `14000ad00..14000b05e`
- Calls: SetEvent@EXTERNAL:000001ef, memcpy@140039b1e, memset@140039b36
- Referenced strings: (none)
- Incoming callers: `14000accf` from `FUN_14000acb0@14000acb0`
- Decompiler signals: SetEvent

### `140014f30`
- Function: `FUN_140014f30@140014f30`
- Body: `140014f30..140015185`
- Calls: CStdioFile@140037e1c, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, FUN_140020e00@140020e00, operator=@EXTERNAL:000001a1, Format@EXTERNAL:00000197, CreateEventA@EXTERNAL:000001ed, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af
- Referenced strings: `140044f00` `(not available)`, `140044f10` `AudioRxEvent%d`, `140044f20` `RemRecFrameReadyEvent%d`, `140044f38` `AudioVideoRecvThreadEnded%d`, `140044f58` `RemRecVideoThreadEnded%d`
- Incoming callers: `1400294aa` from `FUN_140029370@140029370`
- Decompiler signals: CreateEvent, AudioRxEvent, AudioVideoRecvThreadEnded, 0x2a

### `1400152d0`
- Function: `FUN_1400152d0@1400152d0`
- Body: `1400152d0..1400160b5`
- Calls: operator_new@140036e9c, FUN_140006bd0@140006bd0, FUN_1400049f0@1400049f0, ResetEvent@EXTERNAL:000001ee, pcap_sendqueue_alloc@140036153, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, operator_new@14003643c, pcap_next_ex@14003616b, Ordinal_15@EXTERNAL:000002cc, Format@EXTERNAL:00000197, Compare@EXTERNAL:0000019f, FUN_140006f00@140006f00, FUN_140007200@140007200, FUN_140006e90@140006e90, FUN_140004dd0@140004dd0, FUN_140004d60@140004d60, FUN_140004c40@140004c40, ... +29 more
- Referenced strings: `140044410` `Jpeg decoding (CPU): `, `140045020` `%d.%d.%d.%d`
- Incoming callers: `1400160c4` from `FUN_1400160c0@1400160c0`
- Decompiler signals: pcap_, SetEvent, ResetEvent

### `140016f20`
- Function: `FUN_140016f20@140016f20`
- Body: `140016f20..1400174cf`
- Calls: operator=@EXTERNAL:000001a2, pcap_findalldevs@140036147, strstr@140039b2a, FUN_140020660@140020660, pcap_open@14003614d, pcap_freealldevs@14003617d, pcap_setmintocopy@140036183, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, Format@EXTERNAL:00000197, pcap_compile@140036177, pcap_setfilter@140036171, _time64@EXTERNAL:0000028f, _localtime64_s@EXTERNAL:00000293, strftime@EXTERNAL:00000290, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, AfxBeginThread@140037dfe, __security_check_cookie@1400364d0, FUN_140015270@140015270
- Referenced strings: `140044f78` `ip and udp`, `140044f90` `ip and src host %s and dst host %s and (udp port %d or udp port %d)`, `140044fd8` `%H:%M:%S`
- Incoming callers: `14002bef3` from `FUN_14002b9b0@14002b9b0`, `14002fc57` from `FUN_14002f3d0@14002f3d0`
- Decompiler signals: pcap_

### `140020580`
- Function: `FUN_140020580@140020580`
- Body: `140020580..14002058d`
- Calls: (none)
- Referenced strings: (none)
- Incoming callers: `140020a3c` from `FUN_140020a10@140020a10`, `140020b47` from `FUN_140020a80@140020a80`
- Decompiler signals: (none)

### `140020a10`
- Function: `FUN_140020a10@140020a10`
- Body: `140020a10..140020a71`
- Calls: FUN_140020580@140020580
- Referenced strings: (none)
- Incoming callers: `140020d32` from `FUN_140020ba0@140020ba0`
- Decompiler signals: (none)

### `140020a80`
- Function: `FUN_140020a80@140020a80`
- Body: `140020a80..140020b93`
- Calls: operator_new@14003643c, memset@140039b36, Ordinal_9@EXTERNAL:000002c8, memcpy@140039b1e, FUN_140020580@140020580, free@1400364f4
- Referenced strings: (none)
- Incoming callers: `140020d11` from `FUN_140020ba0@140020ba0`
- Decompiler signals: (none)

### `140020ba0`
- Function: `FUN_140020ba0@140020ba0`
- Body: `140020ba0..140020d61`
- Calls: Ordinal_9@EXTERNAL:000002c8, memcpy@140039b1e, FUN_140020a80@140020a80, FUN_140020a10@140020a10
- Referenced strings: (none)
- Incoming callers: `140009ec7` from `FUN_140009bf0@140009bf0`, `1400118ff` from `FUN_1400115c0@1400115c0`, `140011a18` from `FUN_1400115c0@1400115c0`, `140012162` from `FUN_140011c10@140011c10`, `140012277` from `FUN_140011c10@140011c10`
- Decompiler signals: 0x2a, 0x1337

### `1400214a0`
- Function: `FUN_1400214a0@1400214a0`
- Body: `1400214a0..140021591`
- Calls: mmioOpenA@EXTERNAL:00000017, mmioCreateChunk@EXTERNAL:00000018, mmioWrite@EXTERNAL:0000001a, mmioAscend@EXTERNAL:00000019, free@1400363fc
- Referenced strings: (none)
- Incoming callers: `14000a521` from `FUN_14000a3a0@14000a3a0`, `14000a661` from `FUN_14000a3a0@14000a3a0`
- Decompiler signals: mmio, 0x40

### `1400215a0`
- Function: `FUN_1400215a0@1400215a0`
- Body: `1400215a0..1400215f9`
- Calls: mmioWrite@EXTERNAL:0000001a, free@1400363fc
- Referenced strings: (none)
- Incoming callers: `140009b6b` from `FUN_140009ad0@140009ad0`, `14000a9db` from `FUN_14000a930@14000a930`
- Decompiler signals: mmio

### `14002a6e0`
- Function: `FUN_14002a6e0@14002a6e0`
- Body: `14002a6e0..14002b585`
- Calls: PathFileExistsA@EXTERNAL:00000247, FUN_14001cdf0@14001cdf0, FUN_14001d680@14001d680, FUN_14001dc70@14001dc70, operator=@EXTERNAL:000001a2, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, FUN_14001d5e0@14001d5e0, FUN_14001d400@14001d400, FUN_14001ce40@14001ce40, operator=@EXTERNAL:000001a1, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, operator+=@EXTERNAL:000000e2
- Referenced strings: `14004baa0` `.\\LolaGui.ini`, `14004bab0` `LolaPriority`, `14004bac0` `General`, `14004bad0` `InputAudioDevName`, `14004bae4` `Audio`, `14004baf0` `OutputAudioDevName`, `14004bb08` `SamplingRate`, `14004bb18` `NumOfChannels`, `14004bb28` `bitPerSample`, `14004bb38` `AudioIOSuggLat`, `14004bb48` `AudioInputOffset`, `14004bb60` `AudioOutputLevel`, `14004bb78` `AudioBuffersWarning`, `14004bb90` `0;1;2;3;4;5;6;7;`, `14004bba8` `InputChannels`, `14004bbb8` `1;3;5;7;`, `14004bbc8` `OutputChannels`, `14004bbd8` `InputVideoBoardType`, ... +61 more
- Incoming callers: `140029410` from `FUN_140029370@140029370`
- Decompiler signals: pcap_, SamplingRate, NumOfChannels, bitPerSample, AudioIOSuggLat, AudioInputOffset, AudioOutputLevel, InputChannels, OutputChannels, AudioTxFixedBuffer, WinPcap_SetMinToCopy, RxPacketFiltering, audioport, videoport, socketport, 0x40

## Audio String Xrefs

### `1400440a0` `WriteEvent`
- `140007b2e` from `FUN_140007980@140007980`

### `1400440b0` `AudSndThreadEnded`
- `140007b46` from `FUN_140007980@140007980`

### `1400440c8` `LocRecThreadEnded`
- `140007b64` from `FUN_140007980@140007980`

### `1400440e0` `RemRecThreadEnded`
- `140007b82` from `FUN_140007980@140007980`

### `140044838` `VideoWriteEvent`
- `14000e5bb` from `FUN_14000e1a0@14000e1a0`

### `140044f10` `AudioRxEvent%d`
- `14001506e` from `FUN_140014f30@140014f30`

### `140044f38` `AudioVideoRecvThreadEnded%d`
- `1400150ca` from `FUN_140014f30@140014f30`

### `140047410` `/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `14001fc66` from `FUN_14001fb60@14001fb60`

### `140047480` `/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `14001fcdf` from `FUN_14001fb60@14001fb60`

### `1400475e0` `/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`
- `14001fd62` from `FUN_14001fb60@14001fb60`

### `140047618` `/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`
- `14001fd6b` from `FUN_14001fb60@14001fb60`

### `140047768` `/MESG_QUICKCONN`
- `14001f4f0` from `FUN_14001f390@14001f390`

### `140047778` `/MESG_QUICKCONN_ACK`
- `14001f535` from `FUN_14001f390@14001f390`

### `140047828` `/MESG_SEND_AUDIO_SIGNAL`
- `14001f9f5` from `FUN_14001f390@14001f390`

### `140047840` `/MESG_STOP_AUDIO_SIGNAL`
- `14001fa3a` from `FUN_14001f390@14001f390`

### `1400496bc` `44100`
- `14002535b` from `FUN_1400252b0@1400252b0`
- `140025362` from `FUN_1400252b0@1400252b0`
- `1400253a7` from `FUN_1400252b0@1400252b0`

### `1400496c4` `48000`
- `14002537a` from `FUN_1400252b0@1400252b0`
- `140025381` from `FUN_1400252b0@1400252b0`
- `1400253a7` from `FUN_1400252b0@1400252b0`

### `14004bb08` `SamplingRate`
- `140031f1b` from `FUN_140031d70@140031d70`
- `14002a7db` from `FUN_14002a6e0@14002a6e0`

### `14004bb18` `NumOfChannels`
- `140031f41` from `FUN_140031d70@140031d70`
- `14002a808` from `FUN_14002a6e0@14002a6e0`

### `14004bb28` `bitPerSample`
- `140031f67` from `FUN_140031d70@140031d70`
- `14002a833` from `FUN_14002a6e0@14002a6e0`

### `14004bb38` `AudioIOSuggLat`
- `140031f8d` from `FUN_140031d70@140031d70`
- `14002a85e` from `FUN_14002a6e0@14002a6e0`

### `14004bb48` `AudioInputOffset`
- `140031fb3` from `FUN_140031d70@140031d70`
- `14002a886` from `FUN_14002a6e0@14002a6e0`

### `14004bb60` `AudioOutputLevel`
- `140031fdb` from `FUN_140031d70@140031d70`
- `14002a8ab` from `FUN_14002a6e0@14002a6e0`

### `14004bba8` `InputChannels`
- `140032017` from `FUN_140031d70@140031d70`
- `14002a8f9` from `FUN_14002a6e0@14002a6e0`

### `14004bbc8` `OutputChannels`
- `140032035` from `FUN_140031d70@140031d70`
- `14002a93c` from `FUN_14002a6e0@14002a6e0`

### `14004be30` `socketport`
- `14003244d` from `FUN_140031d70@140031d70`
- `14002ae28` from `FUN_14002a6e0@14002a6e0`

### `14004be48` `audioport`
- `140032473` from `FUN_140031d70@140031d70`
- `14002ae53` from `FUN_14002a6e0@14002a6e0`

### `14004be58` `videoport`
- `140032499` from `FUN_140031d70@140031d70`
- `14002ae7e` from `FUN_14002a6e0@14002a6e0`

### `14004be78` `AudioTxFixedBuffer`
- `1400324fb` from `FUN_140031d70@140031d70`
- `14002aecc` from `FUN_14002a6e0@14002a6e0`

### `14004be90` `WinPcap_SetMinToCopy`
- `140032521` from `FUN_140031d70@140031d70`
- `14002aef7` from `FUN_14002a6e0@14002a6e0`

### `14004beb8` `RxPacketFiltering`
- `14003255d` from `FUN_140031d70@140031d70`
- `14002af5d` from `FUN_14002a6e0@14002a6e0`

### `14006094c` `mmioOpenA`

### `140060958` `mmioClose`

### `140060964` `mmioWrite`

### `140060970` `mmioAscend`

### `14006097e` `mmioCreateChunk`

### `1400609ac` `pcap_close`

### `1400609ba` `pcap_sendpacket`

### `1400609cc` `pcap_findalldevs`

### `1400609e0` `pcap_open`

### `1400609ec` `pcap_sendqueue_alloc`

### `140060a04` `pcap_sendqueue_destroy`

### `140060a1e` `pcap_sendqueue_queue`

### `140060a36` `pcap_sendqueue_transmit`

### `140060a50` `pcap_next_ex`

### `140060a60` `pcap_setfilter`

### `140060a72` `pcap_compile`

### `140060a82` `pcap_freealldevs`

### `140060a96` `pcap_setmintocopy`

### `140060aaa` `pcap_findalldevs_ex`

### `14006188e` `CreateThread`

### `14006191a` `WaitForSingleObject`

### `1400619d2` `SetEvent`

### `1400619de` `ResetEvent`

### `1400619ec` `CreateEventA`

### `140061bce` `WaitForSingleObjectEx`

### `140061be6` `CreateEventW`
