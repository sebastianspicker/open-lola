# LoLa Network/Session Deep Dive: LolaGui_XIMEA_x64.exe

- Executable path: `/Users/sebastian/Git/open-lola/win-compiled/2-0/LolaGui_XIMEA_x64.exe`
- Image base: `140000000`
- Language: `x86:LE:64:default`

## Target Function Summaries

### `140006e80`
- Function: `FUN_140006e80@140006e80`
- Body: `140006e80..140006e89`
- Calls: (none)
- Referenced strings: (none)
- Incoming callers: `140015751` from `FUN_1400152d0@1400152d0`, `1400157d7` from `FUN_1400152d0@1400152d0`, `140015938` from `FUN_1400152d0@1400152d0`
- Decompiler signals: 0x40
- Signal lines:
  - `*(int *)(param_1 + 0x40) == *(int *)(param_1 + 0x10));`

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
- Signal lines:
  - `*(undefined4 *)(param_1 + 0x40) = 0;`

### `1400070b0`
- Function: `FUN_1400070b0@1400070b0`
- Body: `1400070b0..1400071fb`
- Calls: operator_new@14003643c, FUN_140006df0@140006df0, memcpy@140039b1e
- Referenced strings: (none)
- Incoming callers: `140009e1d` from `FUN_140009bf0@140009bf0`, `1400117e7` from `FUN_1400115c0@1400115c0`, `140012040` from `FUN_140011c10@140011c10`
- Decompiler signals: 0x21, 0xeeeeeeee
- Signal lines:
  - `uVar6 = *(int *)(param_1 + 0xc) - 0x21;`
  - `puVar3[1] = CONCAT44(uVar2,0xeeeeeeee);`
  - `memcpy((void *)((longlong)puVar3 + 0x21),_Src,(ulonglong)uVar6);`

### `140007200`
- Function: `FUN_140007200@140007200`
- Body: `140007200..14000724c`
- Calls: memcpy@140039b1e
- Referenced strings: (none)
- Incoming callers: `140015527` from `FUN_1400152d0@1400152d0`, `1400157ad` from `FUN_1400152d0@1400152d0`, `140015930` from `FUN_1400152d0@1400152d0`
- Decompiler signals: 0x21, 0x40
- Signal lines:
  - `(void *)(param_2 + 0x21),(ulonglong)*(uint *)(param_2 + 0x1c));`
  - `*(int *)(param_1 + 0x40) = *(int *)(param_1 + 0x40) + 1;`

### `140009bf0`
- Function: `FUN_140009bf0@140009bf0`
- Body: `140009bf0..140009ff5`
- Calls: operator_new@140036e9c, FUN_140006c50@140006c50, FUN_140007250@140007250, FUN_1400209e0@1400209e0, FUN_140006ef0@140006ef0, operator_new@14003643c, memset@140039b36, FUN_140008b10@140008b10, ResetEvent@EXTERNAL:000001ee, FUN_140004dc0@140004dc0, FUN_140004ff0@140004ff0, WaitForSingleObject@EXTERNAL:000001fa, FUN_140004e40@140004e40, FUN_140004bf0@140004bf0, FUN_1400070b0@1400070b0, FUN_140006ee0@140006ee0, EnterCriticalSection@EXTERNAL:0000020a, Ordinal_11@EXTERNAL:000002cd, FUN_140020ba0@140020ba0, pcap_sendpacket@140036141, LeaveCriticalSection@EXTERNAL:00000209, FUN_140020a00@140020a00, free@1400363fc, pcap_close@14003613b, free@1400364f4, SetEvent@EXTERNAL:000001ef
- Referenced strings: (none)
- Incoming callers: `140009be4` from `FUN_140009be0@140009be0`
- Decompiler signals: pcap_sendpacket, 0x21, 0x2a
- Signal lines:
  - `uVar10 = *(int *)(param_1 + 0x54) * 0x80 + 0x2a;`
  - `plVar9 = (longlong *)(pcVar12 + -0x218);`
  - `pcap_sendpacket(*(undefined8 *)(pcVar12 + -0x10),**(undefined8 **)(param_1 + 0x1b60),`
  - `*(int *)(*(undefined8 **)(param_1 + 0x1b60) + 1) + 0x2a);`

### `1400115c0`
- Function: `FUN_1400115c0@1400115c0`
- Body: `1400115c0..140011c09`
- Calls: operator_new@140036e9c, FUN_140006c50@140006c50, FUN_140007250@140007250, FUN_140006ef0@140006ef0, FUN_1400209e0@1400209e0, FUN_140004a10@140004a10, ResetEvent@EXTERNAL:000001ee, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, WaitForSingleObject@EXTERNAL:000001fa, SetEvent@EXTERNAL:000001ef, FUN_140004dc0@140004dc0, FUN_140004ff0@140004ff0, FUN_140004e40@140004e40, FUN_140004bf0@140004bf0, FUN_1400070b0@1400070b0, pcap_sendqueue_alloc@140036153, FUN_140006eb0@140006eb0, FUN_140006ec0@140006ec0, Ordinal_11@EXTERNAL:000002cd, FUN_140020ba0@140020ba0, pcap_sendqueue_queue@14003615f, FUN_140006ee0@140006ee0, pcap_sendqueue_transmit@140036165, pcap_sendqueue_destroy@140036159, FUN_140020a00@140020a00, free@1400363fc, EnterCriticalSection@EXTERNAL:0000020a, pcap_close@14003613b, ... +4 more
- Referenced strings: `140044ca0` `Video Recording: `
- Incoming callers: `1400115a9` from `FUN_140011590@140011590`
- Decompiler signals: pcap_sendqueue_alloc, pcap_sendqueue_queue, pcap_sendqueue_transmit, pcap_sendqueue_destroy, 0x21, 0x2a, 0x40
- Signal lines:
  - `uVar10 = pcap_sendqueue_alloc(iVar5);`
  - `plVar11 = (longlong *)(pcVar12 + -0x218);`
  - `*(undefined4 *)(pcVar12 + -500),uVar7,uVar2,uVar2,&local_78,0x40);`
  - `pcap_sendqueue_queue`
  - `local_d0 = local_e0 + 0x2a;`
  - `plVar11 = (longlong *)(pcVar12 + -0x218);`
  - `iVar5 = pcap_sendqueue_queue`
  - `pcap_sendqueue_transmit`
  - `pcap_sendqueue_destroy(*(undefined8 *)(pcVar12 + -8));`
  - `uVar10 = pcap_sendqueue_alloc(local_d4);`
  - `pcap_sendqueue_queue(uVar10,puVar8,**(undefined8 **)(param_1 + 0x1828));`
  - `pcap_sendqueue_transmit(*plVar11,plVar11[1],0);`
  - `pcap_sendqueue_destroy(plVar11[1]);`

### `140011680`
- Function: `FUN_1400115c0@1400115c0`
- Body: `1400115c0..140011c09`
- Calls: operator_new@140036e9c, FUN_140006c50@140006c50, FUN_140007250@140007250, FUN_140006ef0@140006ef0, FUN_1400209e0@1400209e0, FUN_140004a10@140004a10, ResetEvent@EXTERNAL:000001ee, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, WaitForSingleObject@EXTERNAL:000001fa, SetEvent@EXTERNAL:000001ef, FUN_140004dc0@140004dc0, FUN_140004ff0@140004ff0, FUN_140004e40@140004e40, FUN_140004bf0@140004bf0, FUN_1400070b0@1400070b0, pcap_sendqueue_alloc@140036153, FUN_140006eb0@140006eb0, FUN_140006ec0@140006ec0, Ordinal_11@EXTERNAL:000002cd, FUN_140020ba0@140020ba0, pcap_sendqueue_queue@14003615f, FUN_140006ee0@140006ee0, pcap_sendqueue_transmit@140036165, pcap_sendqueue_destroy@140036159, FUN_140020a00@140020a00, free@1400363fc, EnterCriticalSection@EXTERNAL:0000020a, pcap_close@14003613b, ... +4 more
- Referenced strings: `140044ca0` `Video Recording: `
- Incoming callers: `1400115a9` from `FUN_140011590@140011590`
- Decompiler signals: pcap_sendqueue_alloc, pcap_sendqueue_queue, pcap_sendqueue_transmit, pcap_sendqueue_destroy, 0x21, 0x2a, 0x40
- Signal lines:
  - `uVar10 = pcap_sendqueue_alloc(iVar5);`
  - `plVar11 = (longlong *)(pcVar12 + -0x218);`
  - `*(undefined4 *)(pcVar12 + -500),uVar7,uVar2,uVar2,&local_78,0x40);`
  - `pcap_sendqueue_queue`
  - `local_d0 = local_e0 + 0x2a;`
  - `plVar11 = (longlong *)(pcVar12 + -0x218);`
  - `iVar5 = pcap_sendqueue_queue`
  - `pcap_sendqueue_transmit`
  - `pcap_sendqueue_destroy(*(undefined8 *)(pcVar12 + -8));`
  - `uVar10 = pcap_sendqueue_alloc(local_d4);`
  - `pcap_sendqueue_queue(uVar10,puVar8,**(undefined8 **)(param_1 + 0x1828));`
  - `pcap_sendqueue_transmit(*plVar11,plVar11[1],0);`
  - `pcap_sendqueue_destroy(plVar11[1]);`

### `140011c10`
- Function: `FUN_140011c10@140011c10`
- Body: `140011c10..14001248c`
- Calls: operator_new@140036e9c, FUN_140006c50@140006c50, FUN_140007250@140007250, FUN_140006ef0@140006ef0, FUN_1400209e0@1400209e0, FUN_140004a10@140004a10, ResetEvent@EXTERNAL:000001ee, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, malloc@EXTERNAL:000002af, memset@140039b36, jpeg_std_error@140036051, jpeg_CreateCompress@140036081, WaitForSingleObject@EXTERNAL:000001fa, FUN_140020e20@140020e20, jpeg_set_defaults@140036093, jpeg_set_quality@140036099, jpeg_mem_dest@14003608d, jpeg_start_compress@14003609f, jpeg_write_scanlines@1400360a5, jpeg_finish_compress@1400360ab, FUN_140020e30@140020e30, GetManager@EXTERNAL:000001a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b9, Concatenate@EXTERNAL:000001bb, operator=@EXTERNAL:000001a2, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, FUN_140004dc0@140004dc0, FUN_140004ff0@140004ff0, ... +22 more
- Referenced strings: `140044cd8` `Jpeg encoding: `
- Incoming callers: `14001159d` from `FUN_140011590@140011590`
- Decompiler signals: pcap_sendqueue_alloc, pcap_sendqueue_queue, pcap_sendqueue_transmit, pcap_sendqueue_destroy, 0x21, 0x2a, 0x40
- Signal lines:
  - `uVar11 = pcap_sendqueue_alloc(iVar5);`
  - `plVar12 = (longlong *)(pcVar15 + -0x218);`
  - `*(uint *)(pcVar15 + -500),uVar6,uVar2,uVar2,&local_78,0x40);`
  - `pcap_sendqueue_queue`
  - `local_398 = local_3b8 + 0x2a;`
  - `plVar12 = (longlong *)(pcVar15 + -0x218);`
  - `iVar5 = pcap_sendqueue_queue`
  - `pcap_sendqueue_transmit`
  - `pcap_sendqueue_destroy(*(undefined8 *)(pcVar15 + -8));`
  - `uVar11 = pcap_sendqueue_alloc(local_39c);`
  - `pcap_sendqueue_queue(uVar11,puVar7,**(undefined8 **)(param_1 + 0x1828));`
  - `pcap_sendqueue_transmit(*plVar12,plVar12[1],0);`
  - `pcap_sendqueue_destroy(plVar12[1]);`

### `1400152d0`
- Function: `FUN_1400152d0@1400152d0`
- Body: `1400152d0..1400160b5`
- Calls: operator_new@140036e9c, FUN_140006bd0@140006bd0, FUN_1400049f0@1400049f0, ResetEvent@EXTERNAL:000001ee, pcap_sendqueue_alloc@140036153, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, operator_new@14003643c, pcap_next_ex@14003616b, Ordinal_15@EXTERNAL:000002cc, Format@EXTERNAL:00000197, Compare@EXTERNAL:0000019f, FUN_140006f00@140006f00, FUN_140007200@140007200, FUN_140006e90@140006e90, FUN_140004dd0@140004dd0, FUN_140004d60@140004d60, FUN_140004c40@140004c40, FUN_140006e80@140006e80, FUN_140006ed0@140006ed0, SetEvent@EXTERNAL:000001ef, FUN_140020e20@140020e20, TryEnterCriticalSection@EXTERNAL:000001ec, free@1400364f4, memcpy@140039b1e, jpeg_std_error@140036051, jpeg_CreateDecompress@140036057, jpeg_mem_src@140036063, ... +19 more
- Referenced strings: `140044410` `Jpeg decoding (CPU): `, `140045020` `%d.%d.%d.%d`
- Incoming callers: `1400160c4` from `FUN_1400160c0@1400160c0`
- Decompiler signals: pcap_next_ex, pcap_sendqueue_alloc, pcap_sendqueue_destroy
- Signal lines:
  - `local_3a0 = (undefined8 *)pcap_sendqueue_alloc(100000);`
  - `iVar8 = pcap_next_ex(*(undefined8 *)(param_1 + 0x50),local_358,&local_378);`
  - `pcap_sendqueue_destroy(local_3a0);`

### `140016f20`
- Function: `FUN_140016f20@140016f20`
- Body: `140016f20..1400174cf`
- Calls: operator=@EXTERNAL:000001a2, pcap_findalldevs@140036147, strstr@140039b2a, FUN_140020660@140020660, pcap_open@14003614d, pcap_freealldevs@14003617d, pcap_setmintocopy@140036183, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, Format@EXTERNAL:00000197, pcap_compile@140036177, pcap_setfilter@140036171, _time64@EXTERNAL:0000028f, _localtime64_s@EXTERNAL:00000293, strftime@EXTERNAL:00000290, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, AfxBeginThread@140037dfe, __security_check_cookie@1400364d0, FUN_140015270@140015270
- Referenced strings: `140044f78` `ip and udp`, `140044f90` `ip and src host %s and dst host %s and (udp port %d or udp port %d)`, `140044fd8` `%H:%M:%S`
- Incoming callers: `14002bef3` from `FUN_14002b9b0@14002b9b0`, `14002fc57` from `FUN_14002f3d0@14002f3d0`
- Decompiler signals: pcap_findalldevs, pcap_open, pcap_compile, pcap_setfilter, pcap_setmintocopy, ip and udp, ip and src host
- Signal lines:
  - `iVar5 = pcap_findalldevs((longlong)param_1 + 0x58,local_148);`
  - `lVar14 = pcap_open(*(undefined8 *)(*(longlong *)((longlong)param_1 + 0x58) + 8),0x10000,8,500);`
  - `pcap_setmintocopy(lVar14,*(undefined4 *)(*(longlong *)((longlong)param_1 + 600) + 0x10c));`
  - `,"ip and udp");`
  - `&local_5f8,"ip and src host %s and dst host %s and (udp port %d or udp port %d)",`
  - `iVar5 = pcap_compile(*(undefined8 *)((longlong)param_1 + 0x50),local_5d0,local_5f8,1);`
  - `iVar5 = pcap_setfilter(*(undefined8 *)((longlong)param_1 + 0x50),local_5d0);`

### `14001f390`
- Function: `FUN_14001f390@14001f390`
- Body: `14001f390..14001fb5a`
- Calls: operator=@EXTERNAL:000001a2, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b7, FUN_14001f270@14001f270, Tokenize@EXTERNAL:0000019e, Compare@EXTERNAL:0000019f, FUN_14001fb60@14001fb60, AfxGetThread@140038224, SendMessageA@EXTERNAL:00000225, atoi@EXTERNAL:000002b3, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af
- Referenced strings: `14004771c` `SRCIP:`, `140047724` `DSTIP:`, `140047730` `/MESG_CHECKLOLASTATUS`, `140047748` `/MESG_CHECKLOLASTATUS_ACK`, `140047768` `/MESG_QUICKCONN`, `140047778` `/MESG_QUICKCONN_ACK`, `14004778c` `CHNLS:`, `1400477b8` `COMP:`, `1400477c0` `BAYER:`, `1400477c8` `/MESG_DISCONNECT`, `1400477e0` `/MESG_REJECT`, `1400477f8` `/MESG_SWITCH_ON_BB`, `140047810` `/MESG_SWITCH_OFF_BB`, `140047828` `/MESG_SEND_AUDIO_SIGNAL`, `140047840` `/MESG_STOP_AUDIO_SIGNAL`, `140047858` `/MESG_CHAT`
- Incoming callers: `140020277` from `FUN_140020110@140020110`
- Decompiler signals: connect, SRCIP, DSTIP, /MESG_CHECKLOLASTATUS, /MESG_CHECKLOLASTATUS_ACK, /MESG_QUICKCONN, /MESG_QUICKCONN_ACK, /MESG_REJECT, /MESG_DISCONNECT, /MESG_SWITCH_ON_BB, /MESG_SWITCH_OFF_BB, /MESG_CHAT, /MESG_SEND_AUDIO_SIGNAL, /MESG_STOP_AUDIO_SIGNAL, quick, chat, 0x40
- Signal lines:
  - `&local_70,"SRCIP:");`
  - `(local_60,"DSTIP:");`
  - `(local_res18,"/MESG_CHECKLOLASTATUS");`
  - `(local_res18,"/MESG_CHECKLOLASTATUS_ACK");`
  - `(local_res18,"/MESG_QUICKCONN");`
  - `SendMessageA(*(HWND *)(lVar6 + 0x40),0x8002,0,0);`
  - `(local_res18,"/MESG_QUICKCONN_ACK");`
  - `(*(longlong *)(param_1 + 0x38) + 0x40),local_res20);`
  - `(local_res18,"/MESG_DISCONNECT");`
  - `SendMessageA(*(HWND *)(lVar6 + 0x40),0x8003,0,0);`
  - `(local_res18,"/MESG_REJECT");`
  - `(local_res18,"/MESG_SWITCH_ON_BB");`
  - `SendMessageA(*(HWND *)(lVar6 + 0x40),0x8005,0,0);`
  - `(local_res18,"/MESG_SWITCH_OFF_BB");`
  - `SendMessageA(*(HWND *)(lVar6 + 0x40),0x8005,0,0);`
  - `(local_res18,"/MESG_SEND_AUDIO_SIGNAL");`
  - `SendMessageA(*(HWND *)(lVar6 + 0x40),0x8007,0,0);`
  - `(local_res18,"/MESG_STOP_AUDIO_SIGNAL");`
  - `SendMessageA(*(HWND *)(lVar6 + 0x40),0x8008,0,0);`
  - `(local_res18,"/MESG_CHAT");`
  - `SendMessageA(*(HWND *)(lVar7 + 0x40),0x8006,0,0);`

### `14001fb60`
- Function: `FUN_14001fb60@14001fb60`
- Body: `14001fb60..14001ff5e`
- Calls: CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, Format@EXTERNAL:00000197, operator_new@140036e9c, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b7, _beginthreadex@EXTERNAL:000002aa, _Thrd_detach@140036366, FUN_14001ffa0@14001ffa0, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, AfxMessageBox@140037e04, _Throw_C_error@140036372, _Throw_Cpp_error@140036378
- Referenced strings: `1400473a8` `/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;`, `1400473d8` `/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;`, `140047410` `/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`, `140047480` `/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`, `1400474f0` `/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`, `140047520` `/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;`, `140047550` `/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;`, `140047580` `/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;`, `1400475b0` `/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`, `1400475e0` `/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`, `140047618` `/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`, `140047650` `CLolaLibController: type of message unknown.`
- Incoming callers: `14001f4ce` from `FUN_14001f390@14001f390`, `140032b67` from `FUN_1400329a0@1400329a0`, `140032c33` from `FUN_1400329a0@1400329a0`, `14002c1c9` from `FUN_14002c100@14002c100`, `14002b7de` from `FUN_14002b650@14002b650`, `14002bc1e` from `FUN_14002b9b0@14002b9b0`, `14002f5bb` from `FUN_14002f3d0@14002f3d0`, `14002fa59` from `FUN_14002f3d0@14002f3d0`, `14002faaf` from `FUN_14002f3d0@14002f3d0`, `140030e66` from `FUN_140030d60@140030d60`, `14003107c` from `FUN_140030f50@140030f50`
- Decompiler signals: connect, SRCIP, DSTIP, SID, /MESG_CHECKLOLASTATUS, /MESG_CHECKLOLASTATUS_ACK, /MESG_QUICKCONN, /MESG_QUICKCONN_ACK, /MESG_REJECT, /MESG_DISCONNECT, /MESG_SWITCH_ON_BB, /MESG_SWITCH_OFF_BB, /MESG_CHAT, /MESG_SEND_AUDIO_SIGNAL, /MESG_STOP_AUDIO_SIGNAL, quick, chat
- Signal lines:
  - `"/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d"`
  - `pcVar9 = "/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;";`
  - `(local_res8,"/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s",*(undefined8 *)param_3,`
  - `"/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d"`
  - `pcVar9 = "/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;";`
  - `pcVar9 = "/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;";`
  - `pcVar9 = "/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;";`
  - `pcVar9 = "/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;";`
  - `(local_res8,"/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s",*(undefined8 *)param_3,`
  - `pcVar9 = "/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d";`
  - `pcVar9 = "/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d";`

### `140020ba0`
- Function: `FUN_140020ba0@140020ba0`
- Body: `140020ba0..140020d61`
- Calls: Ordinal_9@EXTERNAL:000002c8, memcpy@140039b1e, FUN_140020a80@140020a80, FUN_140020a10@140020a10
- Referenced strings: (none)
- Incoming callers: `140009ec7` from `FUN_140009bf0@140009bf0`, `1400118ff` from `FUN_1400115c0@1400115c0`, `140011a18` from `FUN_1400115c0@1400115c0`, `140012162` from `FUN_140011c10@140011c10`, `140012277` from `FUN_140011c10@140011c10`
- Decompiler signals: 0x2a, 0x1337
- Signal lines:
  - `uVar3 = Ordinal_9(0x1337);`
  - `memcpy((void *)(*param_1 + 0x2a),param_8,(ulonglong)param_9);`

### `140020d70`
- Function: `FUN_140020d70@140020d70`
- Body: `140020d70..140020dfe`
- Calls: pcap_open@14003614d, pcap_sendpacket@140036141, pcap_close@14003613b, __security_check_cookie@1400364d0
- Referenced strings: (none)
- Incoming callers: (none)
- Decompiler signals: pcap_open, pcap_sendpacket, 0x2a
- Signal lines:
  - `uVar1 = pcap_open(*(undefined8 *)(param_2 + 8),0xffff,0x10);`
  - `pcap_sendpacket(uVar1,*param_1,*(int *)(param_1 + 1) + 0x2a);`

### `14002a6e0`
- Function: `FUN_14002a6e0@14002a6e0`
- Body: `14002a6e0..14002b585`
- Calls: PathFileExistsA@EXTERNAL:00000247, FUN_14001cdf0@14001cdf0, FUN_14001d680@14001d680, FUN_14001dc70@14001dc70, operator=@EXTERNAL:000001a2, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, FUN_14001d5e0@14001d5e0, FUN_14001d400@14001d400, FUN_14001ce40@14001ce40, operator=@EXTERNAL:000001a1, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, operator+=@EXTERNAL:000000e2
- Referenced strings: `14004baa0` `.\\LolaGui.ini`, `14004bab0` `LolaPriority`, `14004bac0` `General`, `14004bad0` `InputAudioDevName`, `14004bae4` `Audio`, `14004baf0` `OutputAudioDevName`, `14004bb08` `SamplingRate`, `14004bb18` `NumOfChannels`, `14004bb28` `bitPerSample`, `14004bb38` `AudioIOSuggLat`, `14004bb48` `AudioInputOffset`, `14004bb60` `AudioOutputLevel`, `14004bb78` `AudioBuffersWarning`, `14004bb90` `0;1;2;3;4;5;6;7;`, `14004bba8` `InputChannels`, `14004bbb8` `1;3;5;7;`, `14004bbc8` `OutputChannels`, `14004bbd8` `InputVideoBoardType`, `14004bbec` `Video`, `14004bbf8` `InputVideoBoardName`, `14004bc10` `InputVideoCameraFile`, `14004bc28` `FrameRate`, `14004bc38` `Exposure`, `14004bc48` `bitPerPixel`, `14004bc54` `FrameX`, `14004bc5c` `FrameY`, `14004bc68` `BayerDec`, `14004bc78` `Compression`, ... +51 more
- Incoming callers: `140029410` from `FUN_140029370@140029370`
- Decompiler signals: pcap_setmintocopy, socket, WinPcap_SetMinToCopy, RxPacketFiltering, audioport, videoport, socketport, quick, Session, 0x40
- Signal lines:
  - `*(undefined8 *)(param_1 + 0x1938) = 0x40e5888000000000;`
  - `*(undefined8 *)(param_1 + 0x1988) = 0x403e000000000000;`
  - `*(undefined8 *)(param_1 + 0x1990) = 0x4059000000000000;`
  - `*(undefined8 *)(param_1 + 0x19d8) = 0x40;`
  - `*(undefined8 *)(param_1 + 0x19e0) = 0x40;`
  - `*(undefined8 *)(param_1 + 0x19e8) = 0x40;`
  - `uVar6 = FUN_14001d400((longlong)local_48,"Video","UseQuickCxpStartup",1);`
  - `uVar2 = FUN_14001d680((longlong)local_48,"ColorVideo","RedGain",0x40,10);`
  - `uVar2 = FUN_14001d680((longlong)local_48,"ColorVideo","GreenGain",0x40,10);`
  - `uVar2 = FUN_14001d680((longlong)local_48,"ColorVideo","BlueGain",0x40,10);`
  - `uVar2 = FUN_14001d680((longlong)local_48,"Network","socketport",7000,10);`
  - `uVar2 = FUN_14001d680((longlong)local_48,"Network","audioport",0x4d4c,10);`
  - `uVar2 = FUN_14001d680((longlong)local_48,"Network","videoport",0x4d56,10);`
  - `uVar2 = FUN_14001d680((longlong)local_48,"Network","WinPcap_SetMinToCopy",10,10);`
  - `uVar6 = FUN_14001d400((longlong)local_48,"Network","RxPacketFiltering",1);`
  - `(param_1 + 0x1a58),"LastSession");`
  - `pCVar3 = FUN_14001dc70((longlong)local_48,local_58,"Session","SessionName","LastSession");`

### `140031d70`
- Function: `FUN_140031d70@140031d70`
- Body: `140031d70..140032957`
- Calls: FUN_14001cdf0@14001cdf0, operator=@EXTERNAL:000001a1, FUN_140032cd0@140032cd0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, SendMessageA@EXTERNAL:00000225, Format@EXTERNAL:00000197, operator+=@EXTERNAL:00000181, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, operator=@EXTERNAL:000001a2, FUN_14001e590@14001e590, FUN_14001e670@14001e670, FUN_14001e4b0@14001e4b0, FUN_14001e3a0@14001e3a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, GetWindowTextA@1400382ba, Trim@EXTERNAL:00000159, GetManager@EXTERNAL:000001a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b9, Concatenate@EXTERNAL:000001bb, SetFocus@140037e40, FUN_14001ce40@14001ce40
- Referenced strings: `14004baa0` `.\\LolaGui.ini`, `14004bab0` `LolaPriority`, `14004bac0` `General`, `14004bad0` `InputAudioDevName`, `14004bae4` `Audio`, `14004baf0` `OutputAudioDevName`, `14004bb08` `SamplingRate`, `14004bb18` `NumOfChannels`, `14004bb28` `bitPerSample`, `14004bb38` `AudioIOSuggLat`, `14004bb48` `AudioInputOffset`, `14004bb60` `AudioOutputLevel`, `14004bb78` `AudioBuffersWarning`, `14004bba8` `InputChannels`, `14004bbc8` `OutputChannels`, `14004bbd8` `InputVideoBoardType`, `14004bbec` `Video`, `14004bbf8` `InputVideoBoardName`, `14004bc10` `InputVideoCameraFile`, `14004bc28` `FrameRate`, `14004bc38` `Exposure`, `14004bc48` `bitPerPixel`, `14004bc54` `FrameX`, `14004bc5c` `FrameY`, `14004bc68` `BayerDec`, `14004bc78` `Compression`, `14004bc88` `CompressionQuality`, `14004bca0` `OptimizeJpegDecompression`, ... +46 more
- Incoming callers: `140029ce1` from `FUN_140029ad0@140029ad0`
- Decompiler signals: Session, 0x40
- Signal lines:
  - `(param_1 + 0x1a58),"LastSession");`
  - `SendMessageA(*(HWND *)pCVar6,0x400,0,0);`
  - `SendMessageA(*(HWND *)pCVar6,0x400,0,0);`

## Network Import/Thunk Caller Surface

### `pcap_close@14003613b`
- `140009fac` from `FUN_140009bf0@140009bf0`
- `14000a845` from `FUN_14000a800@14000a800`
- `140011b9c` from `FUN_1400115c0@1400115c0`
- `14001241c` from `FUN_140011c10@140011c10`
- `14001294d` from `FUN_140012910@140012910`
- `140016039` from `FUN_1400152d0@1400152d0`
- `140020dd9` from `FUN_140020d70@140020d70`

### `pcap_sendpacket@140036141`
- `140009ee2` from `FUN_140009bf0@140009bf0`
- `140020dd1` from `FUN_140020d70@140020d70`

### `pcap_findalldevs@140036147`
- `14000a0b7` from `FUN_14000a000@14000a000`
- `14001254e` from `FUN_140012490@140012490`
- `140016fbf` from `FUN_140016f20@140016f20`
- `140028b45` from `FUN_140028af0@140028af0`

### `pcap_open@14003614d`
- `14000a297` from `FUN_14000a000@14000a000`
- `140012727` from `FUN_140012490@140012490`
- `140017178` from `FUN_140016f20@140016f20`
- `140020dbb` from `FUN_140020d70@140020d70`

### `pcap_sendqueue_alloc@140036153`
- `140011803` from `FUN_1400115c0@1400115c0`
- `140011a54` from `FUN_1400115c0@1400115c0`
- `14001205a` from `FUN_140011c10@140011c10`
- `1400122b3` from `FUN_140011c10@140011c10`
- `14001538f` from `FUN_1400152d0@1400152d0`

### `pcap_sendqueue_destroy@140036159`
- `140011a4b` from `FUN_1400115c0@1400115c0`
- `140011ae4` from `FUN_1400115c0@1400115c0`
- `1400122aa` from `FUN_140011c10@140011c10`
- `140012337` from `FUN_140011c10@140011c10`
- `14001602b` from `FUN_1400152d0@1400152d0`

### `pcap_sendqueue_queue@14003615f`
- `140011915` from `FUN_1400115c0@1400115c0`
- `140011a2e` from `FUN_1400115c0@1400115c0`
- `140011a6d` from `FUN_1400115c0@1400115c0`
- `140012178` from `FUN_140011c10@140011c10`
- `14001228d` from `FUN_140011c10@140011c10`
- `1400122cc` from `FUN_140011c10@140011c10`

### `pcap_sendqueue_transmit@140036165`
- `140011a42` from `FUN_1400115c0@1400115c0`
- `140011adb` from `FUN_1400115c0@1400115c0`
- `1400122a1` from `FUN_140011c10@140011c10`
- `14001232e` from `FUN_140011c10@140011c10`

### `pcap_next_ex@14003616b`
- `14001543c` from `FUN_1400152d0@1400152d0`

### `pcap_setfilter@140036171`
- `140017253` from `FUN_140016f20@140016f20`

### `pcap_compile@140036177`
- `140017233` from `FUN_140016f20@140016f20`

### `pcap_freealldevs@14003617d`
- `14001718d` from `FUN_140016f20@140016f20`
- `140017240` from `FUN_140016f20@140016f20`
- `140017263` from `FUN_140016f20@140016f20`
- `14001739e` from `FUN_140016f20@140016f20`
- `140028e4b` from `FUN_140028af0@140028af0`

### `pcap_setmintocopy@140036183`
- `1400171a4` from `FUN_140016f20@140016f20`

### `pcap_findalldevs_ex@140036189`
- `140020952` from `FUN_140020920@140020920`

### `SelectPalette@140038146`
- `140019ea0` from `FUN_140019c80@140019c80`
- `140019ee6` from `FUN_140019c80@140019c80`
- `14001c679` from `FUN_14001c550@14001c550`
- `14001aaf8` from `FUN_14001a9f0@14001a9f0`
- `14001ae41` from `FUN_14001ac90@14001ac90`
- `14001ae6d` from `FUN_14001ac90@14001ac90`
- `14001bb2f` from `FUN_14001b930@14001b930`

### `SelectGdiObject@140038170`
- `14001a92d` from `FUN_14001a760@14001a760`
- `14001a97c` from `FUN_14001a760@14001a760`
- `14001ade0` from `FUN_14001ac90@14001ac90`
- `14001b019` from `FUN_14001ac90@14001ac90`

### `GetAdaptersInfo@140039afa`
- `14002069c` from `FUN_140020660@140020660`

### `SendARP@140039b00`
- `14002063d` from `FUN_1400205b0@1400205b0`
- `140020734` from `FUN_140020660@140020660`

### `IcmpCreateFile@140039b06`
- `14002b6f6` from `FUN_14002b650@14002b650`

### `IcmpCloseHandle@140039b0c`
- `14002b739` from `FUN_14002b650@14002b650`

### `IcmpSendEcho@140039b12`
- `14002b72f` from `FUN_14002b650@14002b650`

## Target String Xrefs

### `140044f78` `ip and udp`
- `1400171c6` from `FUN_140016f20@140016f20`

### `140044f90` `ip and src host %s and dst host %s and (udp port %d or udp port %d)`
- `140017208` from `FUN_140016f20@140016f20`

### `140046838` `Unable to select foreground palette for realization`
- `14001c6a0` from `FUN_14001c550@14001c550`

### `1400473a8` `/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;`
- `14001fbeb` from `FUN_14001fb60@14001fb60`

### `1400473d8` `/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;`
- `14001fbf7` from `FUN_14001fb60@14001fb60`

### `140047410` `/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `14001fc66` from `FUN_14001fb60@14001fb60`

### `140047480` `/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `14001fcdf` from `FUN_14001fb60@14001fb60`

### `1400474f0` `/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`
- `14001fd0b` from `FUN_14001fb60@14001fb60`

### `140047520` `/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;`
- `14001fd1e` from `FUN_14001fb60@14001fb60`

### `140047550` `/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;`
- `14001fd27` from `FUN_14001fb60@14001fb60`

### `140047580` `/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;`
- `14001fd30` from `FUN_14001fb60@14001fb60`

### `1400475b0` `/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`
- `14001fd4f` from `FUN_14001fb60@14001fb60`

### `1400475e0` `/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`
- `14001fd62` from `FUN_14001fb60@14001fb60`

### `140047618` `/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`
- `14001fd6b` from `FUN_14001fb60@14001fb60`

### `140047680` `WSAStartup failed with error: %d\n`
- `14001ef90` from `FUN_14001eef0@14001eef0`

### `1400476a8` `SocketListeningThreadEnded`
- `14001f01f` from `FUN_14001efe0@14001efe0`

### `1400476c8` `Winsock error: Unable to start listening socket`
- `14002018a` from `FUN_140020110@140020110`

### `1400476f8` `Winsock error: Bind failed`
- `1400201d8` from `FUN_140020110@140020110`

### `14004771c` `SRCIP:`
- `14002fdac` from `FUN_14002fd70@14002fd70`
- `14002d0e2` from `FUN_14002d090@14002d090`
- `14002f126` from `FUN_14002f0e0@14002f0e0`
- `14001f3c8` from `FUN_14001f390@14001f390`
- `14002f436` from `FUN_14002f3d0@14002f3d0`
- `14002e5e7` from `FUN_14002e5b0@14002e5b0`

### `140047724` `DSTIP:`
- `14002fdee` from `FUN_14002fd70@14002fd70`
- `14002d124` from `FUN_14002d090@14002d090`
- `14002f168` from `FUN_14002f0e0@14002f0e0`
- `14001f406` from `FUN_14001f390@14001f390`
- `14002f478` from `FUN_14002f3d0@14002f3d0`
- `14002e632` from `FUN_14002e5b0@14002e5b0`

### `140047730` `/MESG_CHECKLOLASTATUS`
- `14001f45c` from `FUN_14001f390@14001f390`

### `140047748` `/MESG_CHECKLOLASTATUS_ACK`
- `14001f4d3` from `FUN_14001f390@14001f390`

### `140047768` `/MESG_QUICKCONN`
- `14001f4f0` from `FUN_14001f390@14001f390`

### `140047778` `/MESG_QUICKCONN_ACK`
- `14001f535` from `FUN_14001f390@14001f390`

### `1400477c8` `/MESG_DISCONNECT`
- `14001f8a4` from `FUN_14001f390@14001f390`

### `1400477e0` `/MESG_REJECT`
- `14001f8e9` from `FUN_14001f390@14001f390`

### `1400477f8` `/MESG_SWITCH_ON_BB`
- `14001f96b` from `FUN_14001f390@14001f390`

### `140047810` `/MESG_SWITCH_OFF_BB`
- `14001f9b0` from `FUN_14001f390@14001f390`

### `140047828` `/MESG_SEND_AUDIO_SIGNAL`
- `14001f9f5` from `FUN_14001f390@14001f390`

### `140047840` `/MESG_STOP_AUDIO_SIGNAL`
- `14001fa3a` from `FUN_14001f390@14001f390`

### `140047858` `/MESG_CHAT`
- `14001fa7f` from `FUN_14001f390@14001f390`

### `140047920` `SendARP Failed. No default gateway\n`
- `140020744` from `FUN_140020660@140020660`

### `1400498a0` `Please select a valid camera model/settings value`
- `140024984` from `FUN_1400248c0@1400248c0`

### `140049a30` `The number of audio channels and/or audio input offset exceed the maximum input channels of the selected audio device.\n\n`
- `140024d31` from `FUN_1400248c0@1400248c0`
- `140024d43` from `FUN_1400248c0@1400248c0`

### `140049ad0` `Lola is connected.\nTo apply changes please disconnect from remote host first.`
- `140024dcd` from `FUN_1400248c0@1400248c0`

### `14004a020` `LolaChatDlg`
- `140049cc0` from `<none>`

### `14004a080` `lola.ForceDisconnect();`
- `140025fc0` from `FUN_140025ea0@140025ea0`

### `14004b8f0` `It seems that your audio card has been configured with a Buffer Size of %d samples.\nIn order to work properly Lola requires 32 or 64 samples; please close Lola and check/modify...`
- `140029a13` from `FUN_140029370@140029370`

### `14004bd90` `UseQuickCxpStartup`
- `1400322f7` from `FUN_140031d70@140031d70`
- `14002acb4` from `FUN_14002a6e0@14002a6e0`

### `14004be30` `socketport`
- `14003244d` from `FUN_140031d70@140031d70`
- `14002ae28` from `FUN_14002a6e0@14002a6e0`

### `14004be48` `audioport`
- `140032473` from `FUN_140031d70@140031d70`
- `14002ae53` from `FUN_14002a6e0@14002a6e0`

### `14004be58` `videoport`
- `140032499` from `FUN_140031d70@140031d70`
- `14002ae7e` from `FUN_14002a6e0@14002a6e0`

### `14004be90` `WinPcap_SetMinToCopy`
- `140032521` from `FUN_140031d70@140031d70`
- `14002aef7` from `FUN_14002a6e0@14002a6e0`

### `14004beb8` `RxPacketFiltering`
- `14003255d` from `FUN_140031d70@140031d70`
- `14002af5d` from `FUN_14002a6e0@14002a6e0`

### `14004c040` `LastSession`
- `140032673` from `FUN_140031d70@140031d70`
- `14003043d` from `FUN_140030410@140030410`
- `14002b432` from `FUN_14002a6e0@14002a6e0`
- `14002b439` from `FUN_14002a6e0@14002a6e0`
- `14002b508` from `FUN_14002a6e0@14002a6e0`

### `14004c050` `SessionName`
- `1400328a7` from `FUN_140031d70@140031d70`
- `140030240` from `FUN_140030020@140030020`
- `140030247` from `FUN_140030020@140030020`
- `1400306e6` from `FUN_140030410@140030410`
- `14002b43e` from `FUN_14002a6e0@14002a6e0`
- `140030b4a` from `FUN_140030790@140030790`

### `14004c060` `Session`
- `1400328ae` from `FUN_140031d70@140031d70`
- `14003024c` from `FUN_140030020@140030020`
- `1400306ed` from `FUN_140030410@140030410`
- `14002b445` from `FUN_14002a6e0@14002a6e0`
- `140030b51` from `FUN_140030790@140030790`

### `14004c120` `Disconnect`
- `14002ba63` from `FUN_14002b9b0@14002b9b0`
- `14002bf1a` from `FUN_14002b9b0@14002b9b0`
- `14002fc92` from `FUN_14002f3d0@14002f3d0`

### `14004c130` `Connection already established on Session %d.`
- `14002bb49` from `FUN_14002b9b0@14002b9b0`

### `14004c160` `Connection to localhost not allowed. Type a valid remote host address.`
- `14002c0a3` from `FUN_14002b9b0@14002b9b0`

### `14004c1d8` `Connecting ...`
- `14002bbab` from `FUN_14002b9b0@14002b9b0`

### `14004c1f0` `Session %d connection info:\nNo reply from remote host (%s) within 3 sec! Try again.`
- `14002c014` from `FUN_14002b9b0@14002b9b0`

### `14004c250` `Session %d connection info.\n\nRemote host (%s) replied with the following message:    \n\n%s`
- `14002c05a` from `FUN_14002b9b0@14002b9b0`

### `14004c2b0` `Connected to `
- `14002bf9c` from `FUN_14002b9b0@14002b9b0`
- `14002bfb3` from `FUN_14002b9b0@14002b9b0`
- `14002fd09` from `FUN_14002f3d0@14002f3d0`
- `14002fd1a` from `FUN_14002f3d0@14002f3d0`

### `14004c2c0` `Unable to establish a valid connection due to the following reason(s):    \n`
- `140029196` from `FUN_140029150@140029150`

### `14004c428` `Connect`
- `14002f288` from `FUN_14002f0e0@14002f0e0`
- `14002c26a` from `FUN_14002c100@14002c100`

### `14004c488` `Session %d: Lola on remote host (%s) refused to connect.`
- `14002fef5` from `FUN_14002fd70@14002fd70`

### `14004c5a0` `_[SESSION_%d]`
- `14002cbb2` from `FUN_14002c400@14002c400`

### `14004c738` `Session `
- `14002d4d8` from `FUN_14002d090@14002d090`

### `14004c770` `=== [Lola Info] ===\r\n%s\r\n=== [HW/SW Info] ===\r\n%s\r\nNICs: %sOS: %s\r\n=== [HW/SW Settings] ===\r\n%s\r\nASIO Buffer size: %d samples\r\nCamera File: %s\r\nVideo FpS: %d\r...`
- `14002d7d5` from `FUN_14002d090@14002d090`

### `14004c928` `lola.ForceDisconnect(`
- `14002da4b` from `FUN_14002d090@14002d090`
- `14002da68` from `FUN_14002d090@14002d090`
- `14002da82` from `FUN_14002d090@14002d090`

### `14004c940` `[Remote %s has disconnected successfully]\r\n`
- `14002db07` from `FUN_14002d090@14002d090`

### `14004ca90` `Session config file (*.ssn)`
- `1400300b7` from `FUN_140030020@140030020`
- `1400300be` from `FUN_140030020@140030020`
- `140030a55` from `FUN_140030790@140030790`
- `140030a5c` from `FUN_140030790@140030790`

### `14004cab8` `Open session info file`
- `1400300e6` from `FUN_140030020@140030020`
- `1400300ed` from `FUN_140030020@140030020`

### `14004cad8` ` Lola - Open session file warning`
- `140030388` from `FUN_140030020@140030020`

### `14004cb28` `Save session info on file %s?`
- `140030682` from `FUN_140030410@140030410`

### `14004cb48` ` Lola - Save session file`
- `140030697` from `FUN_140030410@140030410`

### `14004cb68` `Save session info file`
- `140030a82` from `FUN_140030790@140030790`
- `140030a89` from `FUN_140030790@140030790`

### `14004d510` `Session %d`
- `140034422` from `FUN_1400342e0@1400342e0`

### `14004d548` `Audio RX frames`
- `14003450f` from `FUN_1400342e0@1400342e0`

### `14004d578` `Audio Dropped packets`
- `14003455d` from `FUN_1400342e0@1400342e0`

### `14004d5a8` `Video RX frames`
- `1400345ab` from `FUN_1400342e0@1400342e0`

### `14004d5b8` `Video Dropped frames`
- `1400345d2` from `FUN_1400342e0@1400342e0`

### `14004d5d0` `Video Dropped start_frames`
- `1400345f9` from `FUN_1400342e0@1400342e0`

### `14004d610` `Video Dropped sub_frames`
- `140034647` from `FUN_1400342e0@1400342e0`

### `14004d758` `Not Connected`
- `140034987` from `FUN_140034770@140034770`

### `14004d770` `[Remote Network Monitor Info - Session %d]\r\nAudio Incomplete Packets: %d\r\nAudio Dropped Packets: %d\r\nAudio Realigned Buffers: %d\r\nVideo Dropped Frames: %d\r\nVideo Dropp...`
- `140033f24` from `FUN_140033dd0@140033dd0`

### `14004dd50` `CPropertySessionPage`
- `14004d9a0` from `<none>`
