# LoLa Video Deep Dive: LolaGui_XIMEA_x64.exe

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
- Decompiler signals: (none)

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
- Decompiler signals: 0x21
- Signal lines:
  - `(void *)(param_2 + 0x21),(ulonglong)*(uint *)(param_2 + 0x1c));`

### `140007250`
- Function: `FUN_140007250@140007250`
- Body: `140007250..1400072c2`
- Calls: free@1400363fc, FUN_1400072d0@1400072d0
- Referenced strings: (none)
- Incoming callers: `140009c77` from `FUN_140009bf0@140009bf0`, `14001163a` from `FUN_1400115c0@1400115c0`, `140011c9d` from `FUN_140011c10@140011c10`
- Decompiler signals: (none)

### `14000efc0`
- Function: `FUN_14000efc0@14000efc0`
- Body: `14000efc0..14000f6c9`
- Calls: `eh_vector_constructor_iterator'@140036d30, create@140039a76, ResetEvent@EXTERNAL:000001ee, xiGetImage@EXTERNAL:0000025d, _interlockedExchangeAdd@140039aa0, deallocate@140039a7c, copySize@140039a82, fastFree@140039a58, _OutputArray@140039a64, _InputArray@140039a5e, resize@140039aa6, rectangle@140039a88, snprintf@140014820, FUN_14000ab60@14000ab60, putText@140039a94, free@1400363fc, Mat@140039a6a, copyTo@140039a70, FUN_1400190f0@1400190f0, _invalid_parameter_noinfo_noreturn@EXTERNAL:000002a5, MessageBoxA@EXTERNAL:00000228, SetEvent@EXTERNAL:000001ef, ... +2 more
- Referenced strings: `140044ce8` `CAM %d`, `140044b18` `CBFVideoServer Class`, `140044cf0` `Couldn't update camera preview surface window.`
- Incoming callers: `14000efb4` from `FUN_14000efb0@14000efb0`
- Decompiler signals: xiGetImage, Camera Preview, resize
- Signal lines:
  - `xiGetImage(*plVar8,1000,param_1 + 0x38 + (longlong)(int)uVar6 * 0xe8);`
  - `cv::resize(&local_2c8,&local_3b0,&local_3e0,0);`
  - `MessageBoxA((HWND)0x0,"Couldn\\'t update camera preview surface window.",`

### `14000fb40`
- Function: `FUN_14000fb40@14000fb40`
- Body: `14000fb40..14001079d`
- Calls: FUN_14001cbf0@14001cbf0, Create@140037e46, SetWindowTextA@140037e0a, xiStopAcquisition@EXTERNAL:0000025e, xiCloseDevice@EXTERNAL:00000260, ShowWindow@140037e10, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, Format@EXTERNAL:00000197, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b7, FUN_14001cda0@14001cda0, xiOpenDevice@EXTERNAL:00000261, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, xiSetParamInt@EXTERNAL:00000266, Find@EXTERNAL:00000192, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, FUN_140020ee0@140020ee0, xiGetParamInt@EXTERNAL:00000264, PathFileExistsA@EXTERNAL:00000247, FUN_14001cdf0@14001cdf0, FUN_14001d680@14001d680, FUN_14001d400@14001d400, xiSetParamFloat@EXTERNAL:00000263, ... +24 more
- Referenced strings: `140044928` `Lola - CXP/GenICam Info`, `140044940` `Lola - Info`, `140044950` `Initializing USB3 camera #%d. Please wait ...`, `1400449d8` `exposure`, `1400449e4` `RGB24`, `1400449f0` `imgdataformat`, `140044a00` `width`, `140044a08` `height`, `140044a10` `offsetX`, `140044a18` `offsetY`, `140044a28` `auto_wb`, `140044a30` `.\\XimeaColors.ini`, `140044a48` `m_RedGain`, `140044a54` `Colors`, `140044a60` `m_GreenGain`, `140044a70` `m_BlueGain`, `140044a80` `m_GainAll`, `140044a90` `m_Luminosity`, `140044aa0` `m_Chromaticity`, `140044ab0` `m_BadPixelsCorrection`, `140044ac8` `m_RawColorCorrection`, `140044ae0` `wb_kr`, ... +11 more
- Incoming callers: `14002f095` from `FUN_14002ee30@14002ee30`
- Decompiler signals: xiGetImage, xiOpenDevice, xiSetParam, xiStartAcquisition, xiCloseDevice, XimeaColors.ini, wb_kr, wb_kg, wb_kb, gammaY, gammaC, exposure, imgdataformat, RGB24, width, height, offsetX, offsetY, display surface, 0x1e
- Signal lines:
  - `xiCloseDevice(*plVar26);`
  - `iVar8 = xiOpenDevice(pCVar19,(void *)((longlong)param_1 + (longlong)(local_410 + 0x7b) * 8));`
  - `xiSetParamInt(*plVar26,"exposure");`
  - `((longlong)param_1 + (ulonglong)local_3d8 * 8 + 0x890),"RGB24",0);`
  - `xiSetParamInt(*plVar26,"imgdataformat");`
  - `xiGetParamInt(*plVar26,"width",&local_408);`
  - `xiGetParamInt(*plVar26,"height",&local_3d4);`
  - `xiSetParamInt(*plVar26,"width",local_418);`
  - `xiSetParamInt(*plVar26,"height",local_414);`
  - `xiSetParamInt(*plVar26,"offsetX",iVar8 - iVar9);`
  - `xiSetParamInt(*plVar26,"offsetY",iVar10 - iVar11);`
  - `xiSetParamInt(*plVar26,&DAT_140044a20,0);`
  - `xiSetParamInt(*plVar26,"auto_wb",0);`
  - `BVar12 = PathFileExistsA(".\\\\XimeaColors.ini");`
  - `xiSetParamFloat(*plVar26,"wb_kr",fVar3);`
  - `xiSetParamFloat(*plVar26,"wb_kg",fVar3);`
  - `xiSetParamFloat(*plVar26,"wb_kb",fVar3);`
  - `xiSetParamInt(*plVar26,&DAT_140044af8,0);`
  - `xiSetParamFloat(*plVar26,"gammaY",uVar4);`
  - `xiSetParamFloat(*plVar26,"gammaC",uVar5);`
  - `xiSetParamInt(*plVar26,&DAT_140044b10,0);`
  - `FUN_14001cdf0(local_3f0,".\\\\XimeaColors.ini");`
  - `xiSetParamFloat(*plVar26,"wb_kr",(float)local_3e0 * fVar2);`
  - `xiSetParamFloat(*plVar26,"wb_kg",(float)uVar23 * fVar2);`
  - `xiSetParamFloat(*plVar26,"wb_kb",(float)uVar18 * fVar2);`
  - `xiSetParamInt(*plVar26,&DAT_140044af8,uVar13);`
  - `xiSetParamFloat(*plVar26,"gammaY",fVar29);`
  - `xiSetParamFloat(*plVar26,"gammaC",(float)uVar15 / fVar6);`
  - `xiSetParamInt(*plVar26,&DAT_140044b10);`
  - `xiStartAcquisition(*plVar26);`

### `1400107c0`
- Function: `FUN_1400107c0@1400107c0`
- Body: `1400107c0..140011578`
- Calls: CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, ResetEvent@EXTERNAL:000001ee, WaitForSingleObject@EXTERNAL:000001fa, FUN_140020e20@140020e20, Format@EXTERNAL:00000197, GetManager@EXTERNAL:000001a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b9, Concatenate@EXTERNAL:000001bb, FUN_14000ab60@14000ab60, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, _InputArray@140039a5e, imwrite@140039ab2, free@1400363fc, _interlockedExchangeAdd@140039aa0, deallocate@140039a7c, fastFree@140039a58, basic_ios<char,struct_std::char_traits<char>_>@EXTERNAL:00000056, basic_ostream<char,struct_std::char_traits<char>_>@EXTERNAL:00000055, basic_streambuf<char,struct_std::char_traits<char>_>@EXTERNAL:00000060, _Init@EXTERNAL:0000005c, _Fiopen@14003635a, ... +28 more
- Referenced strings: `140044ca0` `Video Recording: `, `140044cb8` `_Local_%07d.bmp`, `140044cc8` `_Local_%07d.jpg`
- Incoming callers: `140011584` from `FUN_140011580@140011580`
- Decompiler signals: imwrite, jpeg_CreateCompress, jpeg_mem_dest, jpeg_set_quality, jpeg_write_scanlines, _Local_%07d, .bmp, .jpg
- Signal lines:
  - `&local_580,"_Local_%07d.bmp",(ulonglong)uVar21);`
  - `cv::imwrite(&local_168,local_390,pvVar19);`
  - `&local_580,"_Local_%07d.jpg",(ulonglong)uVar21);`
  - `jpeg_CreateCompress(local_368,0x3e,0x1f8);`
  - `jpeg_set_quality(local_368,local_574,1);`
  - `jpeg_mem_dest(local_368,&local_560,&local_578);`
  - `jpeg_write_scanlines(local_368,&local_500,1);`
  - `&local_580,"_Local_%07d.jpg",(ulonglong)uVar21);`

### `1400115c0`
- Function: `FUN_1400115c0@1400115c0`
- Body: `1400115c0..140011c09`
- Calls: operator_new@140036e9c, FUN_140006c50@140006c50, FUN_140007250@140007250, FUN_140006ef0@140006ef0, FUN_1400209e0@1400209e0, FUN_140004a10@140004a10, ResetEvent@EXTERNAL:000001ee, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, WaitForSingleObject@EXTERNAL:000001fa, SetEvent@EXTERNAL:000001ef, FUN_140004dc0@140004dc0, FUN_140004ff0@140004ff0, FUN_140004e40@140004e40, FUN_140004bf0@140004bf0, FUN_1400070b0@1400070b0, pcap_sendqueue_alloc@140036153, FUN_140006eb0@140006eb0, FUN_140006ec0@140006ec0, Ordinal_11@EXTERNAL:000002cd, FUN_140020ba0@140020ba0, pcap_sendqueue_queue@14003615f, FUN_140006ee0@140006ee0, ... +10 more
- Referenced strings: `140044ca0` `Video Recording: `
- Incoming callers: `1400115a9` from `FUN_140011590@140011590`
- Decompiler signals: pcap_sendqueue_alloc, pcap_sendqueue_queue, pcap_sendqueue_transmit, pcap_sendqueue_destroy, 0x1e, 0x21, 0x2a
- Signal lines:
  - `iVar5 = (uVar6 + 0x32) * 0x1e;`
  - `uVar10 = pcap_sendqueue_alloc(iVar5);`
  - `plVar11 = (longlong *)(pcVar12 + -0x218);`
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
- Calls: operator_new@140036e9c, FUN_140006c50@140006c50, FUN_140007250@140007250, FUN_140006ef0@140006ef0, FUN_1400209e0@1400209e0, FUN_140004a10@140004a10, ResetEvent@EXTERNAL:000001ee, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, WaitForSingleObject@EXTERNAL:000001fa, SetEvent@EXTERNAL:000001ef, FUN_140004dc0@140004dc0, FUN_140004ff0@140004ff0, FUN_140004e40@140004e40, FUN_140004bf0@140004bf0, FUN_1400070b0@1400070b0, pcap_sendqueue_alloc@140036153, FUN_140006eb0@140006eb0, FUN_140006ec0@140006ec0, Ordinal_11@EXTERNAL:000002cd, FUN_140020ba0@140020ba0, pcap_sendqueue_queue@14003615f, FUN_140006ee0@140006ee0, ... +10 more
- Referenced strings: `140044ca0` `Video Recording: `
- Incoming callers: `1400115a9` from `FUN_140011590@140011590`
- Decompiler signals: pcap_sendqueue_alloc, pcap_sendqueue_queue, pcap_sendqueue_transmit, pcap_sendqueue_destroy, 0x1e, 0x21, 0x2a
- Signal lines:
  - `iVar5 = (uVar6 + 0x32) * 0x1e;`
  - `uVar10 = pcap_sendqueue_alloc(iVar5);`
  - `plVar11 = (longlong *)(pcVar12 + -0x218);`
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
- Calls: operator_new@140036e9c, FUN_140006c50@140006c50, FUN_140007250@140007250, FUN_140006ef0@140006ef0, FUN_1400209e0@1400209e0, FUN_140004a10@140004a10, ResetEvent@EXTERNAL:000001ee, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, malloc@EXTERNAL:000002af, memset@140039b36, jpeg_std_error@140036051, jpeg_CreateCompress@140036081, WaitForSingleObject@EXTERNAL:000001fa, FUN_140020e20@140020e20, jpeg_set_defaults@140036093, jpeg_set_quality@140036099, jpeg_mem_dest@14003608d, jpeg_start_compress@14003609f, jpeg_write_scanlines@1400360a5, jpeg_finish_compress@1400360ab, FUN_140020e30@140020e30, GetManager@EXTERNAL:000001a0, ... +28 more
- Referenced strings: `140044cd8` `Jpeg encoding: `
- Incoming callers: `14001159d` from `FUN_140011590@140011590`
- Decompiler signals: jpeg_CreateCompress, jpeg_mem_dest, jpeg_set_quality, jpeg_write_scanlines, pcap_sendqueue_alloc, pcap_sendqueue_queue, pcap_sendqueue_transmit, pcap_sendqueue_destroy, 0x1e, 0x21, 0x2a
- Signal lines:
  - `jpeg_CreateCompress(&local_328,0x3e,0x1f8);`
  - `jpeg_set_quality(&local_328,local_3a0,1);`
  - `jpeg_mem_dest(&local_328,&local_3a8);`
  - `jpeg_write_scanlines(&local_328,&local_378);`
  - `iVar5 = (uVar13 + 0x32) * 0x1e;`
  - `uVar11 = pcap_sendqueue_alloc(iVar5);`
  - `plVar12 = (longlong *)(pcVar15 + -0x218);`
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

### `140012c00`
- Function: `FUN_140012c00@140012c00`
- Body: `140012c00..140012eb5`
- Calls: WaitForSingleObject@EXTERNAL:000001fa, FUN_140018f30@140018f30, operator_new@140036e9c, FUN_1400181e0@1400181e0, FUN_140014910@140014910, FUN_1400196c0@1400196c0, FUN_140018f60@140018f60, MessageBoxA@EXTERNAL:00000228, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, FUN_140019790@140019790, GetWindowRect@EXTERNAL:00000226, FUN_140019610@140019610, thunk_FUN_14001c720@140019810, AfxBeginThread@140037dfe, __security_check_cookie@1400364d0
- Referenced strings: `140044b18` `CBFVideoServer Class`, `140044d20` `Couldn't create camera preview surface`, `140044d48` `Camera Preview`
- Incoming callers: `14002eaeb` from `FUN_14002e700@14002e700`, `14002ed08` from `FUN_14002ece0@14002ece0`
- Decompiler signals: Camera Preview
- Signal lines:
  - `MessageBoxA((HWND)0x0,"Couldn\\'t create camera preview surface","CBFVideoServer Class",0x40)`
  - `*)&local_38,"Camera Preview");`

### `140012ec0`
- Function: `FUN_140012ec0@140012ec0`
- Body: `140012ec0..140013a20`
- Calls: free@EXTERNAL:000002ae, operator_new@14003643c, memset@140039b36, rectangle@140039a88, ResetEvent@EXTERNAL:000001ee, xiGetParamInt@EXTERNAL:00000264, xiGetImage@EXTERNAL:0000025d, FUN_140020e20@140020e20, memcpy@140039b1e, FUN_140020e30@140020e30, GetManager@EXTERNAL:000001a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b9, Concatenate@EXTERNAL:000001bb, operator=@EXTERNAL:000001a2, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, _time64@EXTERNAL:0000028f, _localtime64@EXTERNAL:00000291, strftime@EXTERNAL:00000290, FUN_14000ab60@14000ab60, getTextSize@140039a9a, free@1400363fc, putText@140039a94, ... +11 more
- Referenced strings: `140044ba0` `FrameBufferFill: `, `140044bb8` `LoLa AV Test - %#x - %X`, `140044b18` `CBFVideoServer Class`, `140044bd0` `Couldn't update display surface window.`
- Incoming callers: `140013a34` from `FUN_140013a30@140013a30`
- Decompiler signals: xiGetImage, display surface, 0x1e
- Signal lines:
  - `iVar10 = (*(int *)(param_1 + 0x1870) + 1) % 0x1e;`
  - `xiGetImage(lVar21,1000,param_1 + 0x38 + (longlong)*(int *)(param_1 + 0x30) * 0xe8);`
  - `0x1eU) % 0x1e) * 8),(undefined1 *)(ulonglong)uVar11,`
  - `MessageBoxA((HWND)0x0,"Couldn\\'t update display surface window.","CBFVideoServer Class",0x40`

### `140014910`
- Function: `FUN_140014910@140014910`
- Body: `140014910..140014946`
- Calls: FUN_140014980@140014980
- Referenced strings: (none)
- Incoming callers: `14000b32a` from `FUN_14000b100@14000b100`, `14000b4d0` from `FUN_14000b350@14000b350`, `140018580` from `FUN_1400181e0@1400181e0`, `14000d557` from `FUN_14000d440@14000d440`, `14001016d` from `FUN_14000fb40@14000fb40`, `1400103fa` from `FUN_14000fb40@14000fb40`, `140012d3b` from `FUN_140012c00@140012c00`, `140017e30` from `FUN_140017c10@140017c10`, `140022975` from `FUN_1400227d0@1400227d0`
- Decompiler signals: (none)

### `1400152d0`
- Function: `FUN_1400152d0@1400152d0`
- Body: `1400152d0..1400160b5`
- Calls: operator_new@140036e9c, FUN_140006bd0@140006bd0, FUN_1400049f0@1400049f0, ResetEvent@EXTERNAL:000001ee, pcap_sendqueue_alloc@140036153, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, operator_new@14003643c, pcap_next_ex@14003616b, Ordinal_15@EXTERNAL:000002cc, Format@EXTERNAL:00000197, Compare@EXTERNAL:0000019f, FUN_140006f00@140006f00, FUN_140007200@140007200, FUN_140006e90@140006e90, FUN_140004dd0@140004dd0, FUN_140004d60@140004d60, FUN_140004c40@140004c40, FUN_140006e80@140006e80, FUN_140006ed0@140006ed0, SetEvent@EXTERNAL:000001ef, FUN_140020e20@140020e20, ... +25 more
- Referenced strings: `140044410` `Jpeg decoding (CPU): `, `140045020` `%d.%d.%d.%d`
- Incoming callers: `1400160c4` from `FUN_1400160c0@1400160c0`
- Decompiler signals: jpeg_CreateDecompress, jpeg_mem_src, jpeg_read_scanlines, pcap_next_ex, pcap_sendqueue_alloc, pcap_sendqueue_destroy, 0x1e
- Signal lines:
  - `local_3a0 = (undefined8 *)pcap_sendqueue_alloc(100000);`
  - `iVar8 = pcap_next_ex(*(undefined8 *)(param_1 + 0x50),local_358,&local_378);`
  - `pvVar15 = *(void **)(lVar14 + 0x1e0);`
  - `jpeg_CreateDecompress(&local_348,0x3e,600);`
  - `jpeg_mem_src(&local_348,_Src,local_424);`
  - `jpeg_read_scanlines(&local_348);`
  - `pcap_sendqueue_destroy(local_3a0);`

### `1400161a0`
- Function: `FUN_1400161a0@1400161a0`
- Body: `1400161a0..140016ed5`
- Calls: CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, Format@EXTERNAL:00000197, operator+=@EXTERNAL:00000181, ResetEvent@EXTERNAL:000001ee, WaitForSingleObject@EXTERNAL:000001fa, GetManager@EXTERNAL:000001a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b9, Concatenate@EXTERNAL:000001bb, FUN_14000ab60@14000ab60, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, _InputArray@140039a5e, imwrite@140039ab2, free@1400363fc, _interlockedExchangeAdd@140039aa0, deallocate@140039a7c, fastFree@140039a58, basic_ios<char,struct_std::char_traits<char>_>@EXTERNAL:00000056, basic_ostream<char,struct_std::char_traits<char>_>@EXTERNAL:00000055, basic_streambuf<char,struct_std::char_traits<char>_>@EXTERNAL:00000060, _Init@EXTERNAL:0000005c, _Fiopen@14003635a, ... +26 more
- Referenced strings: `140044ca0` `Video Recording: `, `14004502c` `_%dfps`, `140045038` `_Remote_%07d.bmp`, `140045050` `_Remote_%07d.jpg`
- Incoming callers: `140016ee4` from `FUN_140016ee0@140016ee0`
- Decompiler signals: imwrite, jpeg_CreateCompress, jpeg_mem_dest, jpeg_set_quality, jpeg_write_scanlines, _Remote_%07d, .bmp, .jpg
- Signal lines:
  - `&local_570,"_Remote_%07d.bmp",(ulonglong)uVar17);`
  - `cv::imwrite(&local_168,local_390,(vector<int,class_std::allocator<int>_> *)&local_4e8);`
  - `&local_570,"_Remote_%07d.jpg",(ulonglong)uVar17);`
  - `jpeg_CreateCompress(local_368,0x3e,0x1f8);`
  - `jpeg_set_quality(local_368,local_560,1);`
  - `jpeg_mem_dest(local_368,&local_558,&local_568);`
  - `jpeg_write_scanlines(local_368,&local_500,1);`
  - `&local_570,"_Remote_%07d.jpg",(ulonglong)uVar17);`

### `140016f20`
- Function: `FUN_140016f20@140016f20`
- Body: `140016f20..1400174cf`
- Calls: operator=@EXTERNAL:000001a2, pcap_findalldevs@140036147, strstr@140039b2a, FUN_140020660@140020660, pcap_open@14003614d, pcap_freealldevs@14003617d, pcap_setmintocopy@140036183, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, Format@EXTERNAL:00000197, pcap_compile@140036177, pcap_setfilter@140036171, _time64@EXTERNAL:0000028f, _localtime64_s@EXTERNAL:00000293, strftime@EXTERNAL:00000290, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, AfxBeginThread@140037dfe, __security_check_cookie@1400364d0, FUN_140015270@140015270
- Referenced strings: `140044f78` `ip and udp`, `140044f90` `ip and src host %s and dst host %s and (udp port %d or udp port %d)`, `140044fd8` `%H:%M:%S`
- Incoming callers: `14002bef3` from `FUN_14002b9b0@14002b9b0`, `14002fc57` from `FUN_14002f3d0@14002f3d0`
- Decompiler signals: (none)

### `1400181e0`
- Function: `FUN_1400181e0@1400181e0`
- Body: `1400181e0..140018600`
- Calls: CDialog@14003806e, FUN_140020e00@140020e00, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, CStringT<wchar_t,class_StrTraitMFC_DLL<wchar_t,class_ATL::ChTraitsCRT<wchar_t>_>_>@EXTERNAL:000000e1, _time64@EXTERNAL:0000028f, srand@EXTERNAL:000002ba, operator_new@140036e9c, FUN_14000b060@14000b060, FUN_140014880@140014880, FUN_14000caf0@14000caf0, FUN_14000cb00@14000cb00, FUN_140014910@140014910, FUN_14000cae0@14000cae0, GetDC@EXTERNAL:0000021c, GetDeviceCaps@EXTERNAL:00000233, ReleaseDC@EXTERNAL:0000022d
- Referenced strings: (none)
- Incoming callers: `14000cffc` from `FUN_14000cf10@14000cf10`, `14000d1eb` from `FUN_14000d150@14000d150`, `14000d50a` from `FUN_14000d440@14000d440`, `14001037a` from `FUN_14000fb40@14000fb40`, `140012ca7` from `FUN_140012c00@140012c00`
- Decompiler signals: 0x1e, 0x21, 0x2a
- Signal lines:
  - `*(undefined8 *)(param_1 + 0x210) = 0;`
  - `*(undefined4 *)(param_1 + 0x21c) = 0;`
  - `*(undefined8 *)(param_1 + 0x2a0) = 0;`
  - `*(undefined ***)(param_1 + 0x2a8) = CPalette::vftable;`
  - `*(undefined4 *)(param_1 + 0x1e4) = 0;`

### `1400190f0`
- Function: `FUN_1400190f0@1400190f0`
- Body: `1400190f0..14001951a`
- Calls: FUN_140018aa0@140018aa0, FUN_140020e20@140020e20, FUN_140018610@140018610, _OutputArray@140039a64, _InputArray@140039a5e, cvtColor@140039aac, FUN_14000ecf0@14000ecf0, FUN_14000c120@14000c120, memcpy@140039b1e, FUN_140020e30@140020e30, GetManager@EXTERNAL:000001a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b9, Concatenate@EXTERNAL:000001bb, operator=@EXTERNAL:000001a2, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, FUN_140018ef0@140018ef0, __security_check_cookie@1400364d0
- Referenced strings: `140046668` `DSFormatBlit-Bayer: `
- Incoming callers: `14000de65` from `FUN_14000db70@14000db70`, `14000dea8` from `FUN_14000db70@14000db70`, `14000deca` from `FUN_14000db70@14000db70`, `14000f5db` from `FUN_14000efc0@14000efc0`, `1400138f1` from `FUN_140012ec0@140012ec0`
- Decompiler signals: Bayer, cvtColor, 0x1e, 0x21
- Signal lines:
  - `if ((*(int *)(param_1 + 0x21c) == 0) || (uVar10 != 8)) {`
  - `cv::cvtColor(local_b8,local_d8,*(uint *)(param_1 + 0x160),0);`
  - `if (uVar10 == 0x1e) {`
  - `if (0xf < uVar10 - 0x21) {`
  - `} while ("DSFormatBlit-Bayer: "[lVar1] != '\\0');`
  - `((CSimpleStringT<char,1> *)local_f0,"DSFormatBlit-Bayer: ",(int)lVar4,*(char **)this,`

### `1400196c0`
- Function: `FUN_1400196c0@1400196c0`
- Body: `1400196c0..14001974c`
- Calls: FUN_14000cb00@14000cb00
- Referenced strings: (none)
- Incoming callers: `14000d569` from `FUN_14000d440@14000d440`, `14001040d` from `FUN_14000fb40@14000fb40`, `140012d4d` from `FUN_140012c00@140012c00`
- Decompiler signals: (none)

### `140019790`
- Function: `FUN_140019790@140019790`
- Body: `140019790..1400197da`
- Calls: SetWindowTextA@140037e0a, operator=@EXTERNAL:000001a2
- Referenced strings: (none)
- Incoming callers: `14000d344` from `FUN_14000d150@14000d150`, `14000d6be` from `FUN_14000d440@14000d440`, `140010548` from `FUN_14000fb40@14000fb40`, `140012e09` from `FUN_140012c00@140012c00`
- Decompiler signals: (none)

### `140019810`
- Function: `thunk_FUN_14001c720@140019810`
- Body: `140019810..140019814`
- Calls: (none)
- Referenced strings: (none)
- Incoming callers: `14000d0c8` from `FUN_14000cf10@14000cf10`, `14000d2a1` from `FUN_14000d150@14000d150`, `14000d629` from `FUN_14000d440@14000d440`, `1400105a4` from `FUN_14000fb40@14000fb40`, `140012e60` from `FUN_140012c00@140012c00`, `14001be4b` from `FUN_14001bda0@14001bda0`, `140032fab` from `FUN_140032e40@140032e40`, `1400312a6` from `FUN_1400310e0@1400310e0`, `14003130e` from `FUN_1400310e0@1400310e0`, `1400314d4` from `FUN_140031370@140031370`, `140031650` from `FUN_140031370@140031370`, `1400318b7` from `FUN_140031710@140031710`, `140031b88` from `FUN_1400319a0@1400319a0`
- Decompiler signals: (none)

### `140019c80`
- Function: `FUN_140019c80@140019c80`
- Body: `140019c80..14001a0fe`
- Calls: GetDC@EXTERNAL:0000021c, FromHandle@14003812e, DeleteObject@EXTERNAL:00000232, malloc@EXTERNAL:000002af, ReleaseDC@EXTERNAL:0000022d, MessageBoxA@1400381c4, FUN_140018eb0@140018eb0, GetPaletteEntries@EXTERNAL:00000236, free@EXTERNAL:000002ae, SelectPalette@140038146, RealizePalette@EXTERNAL:0000023e, CreateDIBSection@EXTERNAL:00000235, _interlockedExchangeAdd@140039aa0, deallocate@140039a7c, copySize@140039a82, fastFree@140039a58, FUN_140019a60@140019a60, __security_check_cookie@1400364d0
- Referenced strings: `140046750` `Unable to create temporary palette`, `140046728` `Cannot allocate DIBSection object`, `140046778` `Unable to create DIB Section.`
- Incoming callers: `1400195bf` from `FUN_140019580@140019580`, `14001a88e` from `FUN_14001a760@14001a760`
- Decompiler signals: CreateDIBSection, 0x2a
- Signal lines:
  - `pBVar9[*(longlong *)(param_1 + 0x1b0) + 0x2a + lVar10] =`
  - `pHVar5 = CreateDIBSection(*(HDC *)(this_00 + 8),*(BITMAPINFO **)(param_1 + 0x1b0),0,`

### `14001ac90`
- Function: `FUN_14001ac90@14001ac90`
- Body: `14001ac90..14001b567`
- Calls: FUN_140020e20@140020e20, CPaintDC@140038176, GetClientRect@EXTERNAL:00000219, IsIconic@EXTERNAL:00000222, GetDC@EXTERNAL:0000021c, FromHandle@14003812e, DrawIcon@EXTERNAL:0000021d, ReleaseDC@EXTERNAL:0000022d, CDC@14003813a, CreateCompatibleDC@EXTERNAL:00000230, Attach@140038134, MessageBoxA@1400381c4, FUN_140018eb0@140018eb0, ~CDC@14003816a, FromHandle@140038116, SelectGdiObject@140038170, SetDIBColorTable@EXTERNAL:0000023a, SelectPalette@140038146, RealizePalette@EXTERNAL:0000023e, SetStretchBltMode@140038152, FillSolidRect@140038164, BitBlt@EXTERNAL:00000234, ... +19 more
- Referenced strings: `1400466a0` `Cannot create CompatibleDC`, `1400466c0` `DirectX`, `1400466d0` `Rendering mode: %s\nSIMD Acceleration: %s\nFps: %.2f\nZoom: %.2f %%`, `140046718` `Rendering: `
- Incoming callers: (none)
- Decompiler signals: CreateCompatibleDC, SetDIBColorTable, StretchBlt, 0x21
- Signal lines:
  - `pHVar4 = CreateCompatibleDC(local_c0);`
  - `SetDIBColorTable(local_148,0,0x100,(RGBQUAD *)(*(longlong *)(param_1 + 0x1b0) + 0x28));`
  - `SetDIBColorTable(local_c0,0,0x100,(RGBQUAD *)(*(longlong *)(param_1 + 0x1b0) + 0x28));`
  - `CDC::SetStretchBltMode(local_150,3);`
  - `CDC::SetStretchBltMode((CDC *)local_c8,(*(int *)(param_1 + 0x2dc) == 3) + 3);`
  - `if (*(int *)(param_1 + 0x21c) != 0) {`
  - `StretchBlt(local_c0,*(int *)(param_1 + 0x310),*(int *)(param_1 + 0x314),`
  - `*(int *)(param_1 + 0x214) = *(int *)(param_1 + 0x214) + 1;`
  - `if (1000 < DVar3 - *(int *)(param_1 + 0x210)) {`
  - `fVar19 = ((float)*(int *)(param_1 + 0x214) * (float)(DVar3 - *(int *)(param_1 + 0x210))) /`
  - `*(undefined4 *)(param_1 + 0x214) = 0;`
  - `*(DWORD *)(param_1 + 0x210) = DVar3;`
  - `*(float *)(param_1 + 0x218) = fVar19;`

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
- Decompiler signals: 0x1e, 0x2a, 0x1337
- Signal lines:
  - `uVar3 = Ordinal_9(0x1337);`
  - `*(undefined4 *)(*param_1 + 0x1e) = param_5;`
  - `memcpy((void *)(*param_1 + 0x2a),param_8,(ulonglong)param_9);`

### `140009820`
- Function: `FUN_1400093a0@1400093a0`
- Body: `1400093a0..140009ac8`
- Calls: Pa_IsStreamActive@14003612f, Pa_CloseStream@140036117, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b7, Compare@EXTERNAL:0000019f, Pa_HostApiDeviceIndexToDeviceIndex@140036105, Pa_GetDeviceInfo@14003610b, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, operator_new@14003643c, operator=@EXTERNAL:000001a2, Pa_OpenStream@140036111, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, Pa_GetErrorText@1400360e7, Format@EXTERNAL:00000197, MessageBoxA@EXTERNAL:00000228, free@1400364f4, memset@140039b36
- Referenced strings: `140044110` `ASIOAudio: dev open stream error (+%s)`, `140044138` `ASIOAudio`
- Incoming callers: `14002ef0f` from `FUN_14002ee30@14002ee30`
- Decompiler signals: (none)

### `14000b4a0`
- Function: `FUN_14000b350@14000b350`
- Body: `14000b350..14000b4ed`
- Calls: FUN_14000ca20@14000ca20, FUN_14000c970@14000c970, FUN_14000cb20@14000cb20, FUN_140014910@140014910, __security_check_cookie@1400364d0
- Referenced strings: (none)
- Incoming callers: `14001a70f` from `FUN_14001a680@14001a680`
- Decompiler signals: (none)

### `14000e980`
- Function: `FUN_14000e960@14000e960`
- Body: `14000e960..14000ece1`
- Calls: WaitForSingleObject@EXTERNAL:000001fa, CloseHandle@EXTERNAL:00000206, FUN_140018f30@140018f30, xiCloseDevice@EXTERNAL:00000260, SetEvent@EXTERNAL:000001ef, free@1400364f4, free@EXTERNAL:000002ae, FUN_140020a00@140020a00, free@1400363fc, FUN_140014890@140014890, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, `eh_vector_destructor_iterator'@140036da8, FUN_140004a40@140004a40, FUN_140020e10@140020e10, _invalid_parameter_noinfo_noreturn@EXTERNAL:000002a5
- Referenced strings: (none)
- Incoming callers: `14000eedf` from `FUN_14000eed0@14000eed0`
- Decompiler signals: xiCloseDevice, 0x1e, 0x21
- Signal lines:
  - `xiCloseDevice();`
  - `if ((void *)param_1[0x21f] != (void *)0x0) {`
  - `free((void *)param_1[0x21f]);`
  - `lVar3 = 0x1e;`
  - `pvVar1 = (void *)param_1[0x213];`

### `140011210`
- Function: `FUN_1400107c0@1400107c0`
- Body: `1400107c0..140011578`
- Calls: CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001ba, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b0, ResetEvent@EXTERNAL:000001ee, WaitForSingleObject@EXTERNAL:000001fa, FUN_140020e20@140020e20, Format@EXTERNAL:00000197, GetManager@EXTERNAL:000001a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b9, Concatenate@EXTERNAL:000001bb, FUN_14000ab60@14000ab60, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, _InputArray@140039a5e, imwrite@140039ab2, free@1400363fc, _interlockedExchangeAdd@140039aa0, deallocate@140039a7c, fastFree@140039a58, basic_ios<char,struct_std::char_traits<char>_>@EXTERNAL:00000056, basic_ostream<char,struct_std::char_traits<char>_>@EXTERNAL:00000055, basic_streambuf<char,struct_std::char_traits<char>_>@EXTERNAL:00000060, _Init@EXTERNAL:0000005c, _Fiopen@14003635a, ... +28 more
- Referenced strings: `140044ca0` `Video Recording: `, `140044cb8` `_Local_%07d.bmp`, `140044cc8` `_Local_%07d.jpg`
- Incoming callers: `140011584` from `FUN_140011580@140011580`
- Decompiler signals: imwrite, jpeg_CreateCompress, jpeg_mem_dest, jpeg_set_quality, jpeg_write_scanlines, _Local_%07d, .bmp, .jpg
- Signal lines:
  - `&local_580,"_Local_%07d.bmp",(ulonglong)uVar21);`
  - `cv::imwrite(&local_168,local_390,pvVar19);`
  - `&local_580,"_Local_%07d.jpg",(ulonglong)uVar21);`
  - `jpeg_CreateCompress(local_368,0x3e,0x1f8);`
  - `jpeg_set_quality(local_368,local_574,1);`
  - `jpeg_mem_dest(local_368,&local_560,&local_578);`
  - `jpeg_write_scanlines(local_368,&local_500,1);`
  - `&local_580,"_Local_%07d.jpg",(ulonglong)uVar21);`

### `1400138f0`
- Function: `FUN_140012ec0@140012ec0`
- Body: `140012ec0..140013a20`
- Calls: free@EXTERNAL:000002ae, operator_new@14003643c, memset@140039b36, rectangle@140039a88, ResetEvent@EXTERNAL:000001ee, xiGetParamInt@EXTERNAL:00000264, xiGetImage@EXTERNAL:0000025d, FUN_140020e20@140020e20, memcpy@140039b1e, FUN_140020e30@140020e30, GetManager@EXTERNAL:000001a0, CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001b9, Concatenate@EXTERNAL:000001bb, operator=@EXTERNAL:000001a2, ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>@EXTERNAL:000001af, _time64@EXTERNAL:0000028f, _localtime64@EXTERNAL:00000291, strftime@EXTERNAL:00000290, FUN_14000ab60@14000ab60, getTextSize@140039a9a, free@1400363fc, putText@140039a94, ... +11 more
- Referenced strings: `140044ba0` `FrameBufferFill: `, `140044bb8` `LoLa AV Test - %#x - %X`, `140044b18` `CBFVideoServer Class`, `140044bd0` `Couldn't update display surface window.`
- Incoming callers: `140013a34` from `FUN_140013a30@140013a30`
- Decompiler signals: xiGetImage, display surface, 0x1e
- Signal lines:
  - `iVar10 = (*(int *)(param_1 + 0x1870) + 1) % 0x1e;`
  - `xiGetImage(lVar21,1000,param_1 + 0x38 + (longlong)*(int *)(param_1 + 0x30) * 0xe8);`
  - `0x1eU) % 0x1e) * 8),(undefined1 *)(ulonglong)uVar11,`
  - `MessageBoxA((HWND)0x0,"Couldn\\'t update display surface window.","CBFVideoServer Class",0x40`

## Target String Xrefs

### `140044200` `Error determining the next pixel. Unable to apply bayer filter.`
- `14000c0fc` from `FUN_14000ba70@14000ba70`
- `14000c6ce` from `FUN_14000c120@14000c120`

### `1400443a0` `VideoFrameReady%d`
- `14000cc99` from `FUN_14000cc20@14000cc20`

### `140044838` `VideoWriteEvent`
- `14000e5bb` from `FUN_14000e1a0@14000e1a0`

### `140044848` `RecFrameReadyEvent`
- `14000e5d6` from `FUN_14000e1a0@14000e1a0`

### `1400449d8` `exposure`
- `14000fd54` from `FUN_14000fb40@14000fb40`

### `1400449e4` `RGB24`
- `14000fd7d` from `FUN_14000fb40@14000fb40`

### `1400449f0` `imgdataformat`
- `14000fd9e` from `FUN_14000fb40@14000fb40`
- `14002269b` from `FUN_140022670@140022670`

### `140044a00` `width`
- `14000fdfa` from `FUN_14000fb40@14000fb40`
- `14000fe72` from `FUN_14000fb40@14000fb40`

### `140044a08` `height`
- `14000fe20` from `FUN_14000fb40@14000fb40`
- `14000fe88` from `FUN_14000fb40@14000fb40`

### `140044a10` `offsetX`
- `14000fe9c` from `FUN_14000fb40@14000fb40`

### `140044a18` `offsetY`
- `14000feb0` from `FUN_14000fb40@14000fb40`

### `140044a30` `.\\XimeaColors.ini`
- `14000fee9` from `FUN_14000fb40@14000fb40`
- `14000fefe` from `FUN_14000fb40@14000fb40`
- `1400221d7` from `FUN_1400220e0@1400220e0`
- `1400221ec` from `FUN_1400220e0@1400220e0`
- `1400224c7` from `FUN_1400224b0@1400224b0`

### `140044ae0` `wb_kr`
- `1400100b2` from `FUN_14000fb40@14000fb40`
- `140010191` from `FUN_14000fb40@14000fb40`
- `140021cfa` from `FUN_140021cc0@140021cc0`
- `1400227f2` from `FUN_1400227d0@1400227d0`

### `140044ae8` `wb_kg`
- `1400100c7` from `FUN_14000fb40@14000fb40`
- `1400101a6` from `FUN_14000fb40@14000fb40`
- `140021d2b` from `FUN_140021cc0@140021cc0`
- `1400228a8` from `FUN_1400227d0@1400227d0`

### `140044af0` `wb_kb`
- `1400100dc` from `FUN_14000fb40@14000fb40`
- `1400101bb` from `FUN_14000fb40@14000fb40`
- `140021d44` from `FUN_140021cc0@140021cc0`
- `1400228bf` from `FUN_1400227d0@1400227d0`

### `140044b00` `gammaY`
- `140010104` from `FUN_14000fb40@14000fb40`
- `1400101e4` from `FUN_14000fb40@14000fb40`
- `140022910` from `FUN_1400227d0@1400227d0`

### `140044b08` `gammaC`
- `140010118` from `FUN_14000fb40@14000fb40`
- `1400101f9` from `FUN_14000fb40@14000fb40`
- `140022928` from `FUN_1400227d0@1400227d0`

### `140044b30` `Couldn't create display surface`
- `1400104cf` from `FUN_14000fb40@14000fb40`

### `140044b78` `No display surface available`
- `1400105d9` from `FUN_14000fb40@14000fb40`

### `140044bd0` `Couldn't update display surface window.`
- `14001395a` from `FUN_140012ec0@140012ec0`

### `140044cb8` `_Local_%07d.bmp`
- `1400109a3` from `FUN_1400107c0@1400107c0`

### `140044cc8` `_Local_%07d.jpg`
- `140010bb0` from `FUN_1400107c0@1400107c0`
- `1400110dd` from `FUN_1400107c0@1400107c0`

### `140044cf0` `Couldn't update camera preview surface window.`
- `14000f606` from `FUN_14000efc0@14000efc0`

### `140044d20` `Couldn't create camera preview surface`
- `140012dd9` from `FUN_140012c00@140012c00`

### `140044d48` `Camera Preview`
- `140012ded` from `FUN_140012c00@140012c00`

### `140044f20` `RemRecFrameReadyEvent%d`
- `14001509c` from `FUN_140014f30@140014f30`

### `140045038` `_Remote_%07d.bmp`
- `1400163a7` from `FUN_1400161a0@1400161a0`

### `140045050` `_Remote_%07d.jpg`
- `14001659d` from `FUN_1400161a0@1400161a0`
- `140016aed` from `FUN_1400161a0@1400161a0`

### `140046600` `Lola DSCreate: Cannot create a valid display surface`
- `1400190b6` from `FUN_140018f60@140018f60`

### `140046638` `Cannot change display surface to new size.`
- `1400195d2` from `FUN_140019580@140019580`

### `140046668` `DSFormatBlit-Bayer: `
- `14001948a` from `FUN_1400190f0@1400190f0`
- `1400194a3` from `FUN_1400190f0@1400190f0`

### `140046680` `Aborting this display surface`
- `140018ebc` from `FUN_140018eb0@140018eb0`

### `140046908` `Lola - Software Color Correction (LOCAL)`
- `14001a606` from `FUN_14001a590@14001a590`
- `14001a61b` from `FUN_14001a590@14001a590`

### `140046938` `Lola - Software Color Correction (REMOTE)`
- `14001a60d` from `FUN_14001a590@14001a590`

### `140047410` `/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `14001fc66` from `FUN_14001fb60@14001fb60`

### `140047480` `/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `14001fcdf` from `FUN_14001fb60@14001fb60`

### `1400477c0` `BAYER:`
- `14001f82b` from `FUN_14001f390@14001f390`
- `14002f970` from `FUN_14002f3d0@14002f3d0`

### `140048950` `GPUJPEG Library (CUDA-JPEG) is Copyright (c) 2011 by CESNET z.s.p.o.`
- `1400231ee` from `FUN_140022e10@140022e10`
- `1400231f8` from `FUN_140022e10@140022e10`

### `140049920` `Lola - Compression Quality error`
- `140024e46` from `FUN_1400248c0@1400248c0`

### `140049950` `Compression Quality must be an integer value between 40 and 100`
- `140024e4d` from `FUN_1400248c0@1400248c0`

### `140049b40` `Estimated TX Bandwidth (Mbit): %2.2f`
- `140023e45` from `FUN_140023b00@140023b00`

### `14004bc38` `Exposure`
- `1400320df` from `FUN_140031d70@140031d70`
- `14002aa56` from `FUN_14002a6e0@14002a6e0`

### `14004bc68` `BayerDec`
- `14003216f` from `FUN_140031d70@140031d70`
- `14002aaf9` from `FUN_14002a6e0@14002a6e0`

### `14004bc78` `Compression`
- `140032195` from `FUN_140031d70@140031d70`
- `14002ab21` from `FUN_14002a6e0@14002a6e0`

### `14004bc88` `CompressionQuality`
- `1400321bb` from `FUN_140031d70@140031d70`
- `14002ab4c` from `FUN_14002a6e0@14002a6e0`

### `14004bca0` `OptimizeJpegDecompression`
- `1400321d9` from `FUN_140031d70@140031d70`
- `14002ab6f` from `FUN_14002a6e0@14002a6e0`

### `14004bcd0` `IncompleteFramesThreshold`
- `140032225` from `FUN_140031d70@140031d70`
- `14002abbf` from `FUN_14002a6e0@14002a6e0`

### `14004bd08` `UseGpuJpegDecOnCuda`
- `140032261` from `FUN_140031d70@140031d70`
- `14002ac05` from `FUN_14002a6e0@14002a6e0`

### `14004bd40` `AutomaticBayerDecoding`
- `14003229d` from `FUN_140031d70@140031d70`
- `14002ac4b` from `FUN_14002a6e0@14002a6e0`

### `14004be10` `BayerMatrix`
- `140032401` from `FUN_140031d70@140031d70`
- `14002add5` from `FUN_14002a6e0@14002a6e0`

### `14004be20` `BayerAlgorithm`
- `140032427` from `FUN_140031d70@140031d70`
- `14002adfd` from `FUN_14002a6e0@14002a6e0`

### `14004bed0` `VideoPacketSize`
- `140032583` from `FUN_140031d70@140031d70`
- `14002af88` from `FUN_14002a6e0@14002a6e0`

### `14004bf78` `RecPref_ColorBayerDecoding`
- `140032619` from `FUN_140031d70@140031d70`
- `14002b06d` from `FUN_14002a6e0@14002a6e0`

### `14004c770` `=== [Lola Info] ===\r\n%s\r\n=== [HW/SW Info] ===\r\n%s\r\nNICs: %sOS: %s\r\n=== [HW/SW Settings] ===\r\n%s\r\nASIO Buffer size: %d samples\r\nCamera File: %s\r\nVideo FpS: %d\r...`
- `14002d7d5` from `FUN_14002d090@14002d090`

### `14004d5a8` `Video RX frames`
- `1400345ab` from `FUN_1400342e0@1400342e0`

### `14004d5b8` `Video Dropped frames`
- `1400345d2` from `FUN_1400342e0@1400342e0`

### `14004d770` `[Remote Network Monitor Info - Session %d]\r\nAudio Incomplete Packets: %d\r\nAudio Dropped Packets: %d\r\nAudio Realigned Buffers: %d\r\nVideo Dropped Frames: %d\r\nVideo Dropp...`
- `140033f24` from `FUN_140033dd0@140033dd0`
