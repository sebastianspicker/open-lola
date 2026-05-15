
undefined8 * FUN_140007980(undefined8 *param_1,longlong param_2,undefined8 param_3)

{
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *this;
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  HANDLE pvVar4;
  longlong lVar5;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar6;
  undefined8 *puVar7;
  int iVar8;
  int iVar9;
  longlong lVar10;
  longlong *plVar11;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_res10 [8];
  
  *param_1 = ASIOAudio::vftable;
  _eh_vector_constructor_iterator_
            (param_1 + 0x19,8,0x40,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  _eh_vector_constructor_iterator_
            (param_1 + 0x59,8,0x40,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  _eh_vector_constructor_iterator_
            (param_1 + 0x99,8,0x40,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x31c));
  iVar9 = 0;
  param_1[800] = 0;
  param_1[0x321] = 0xf;
  *(undefined1 *)(param_1 + 0x31e) = 0;
  *(undefined4 *)(param_1 + 0x325) = 0xfdfdfdfd;
  *(undefined4 *)((longlong)param_1 + 0x192c) = 0xdfdfdfdf;
  *(undefined4 *)(param_1 + 0x326) = 0xaaaaaaaa;
  *(undefined8 *)((longlong)param_1 + 0x1934) = 0;
  *(undefined8 *)((longlong)param_1 + 0x193c) = 0;
  iVar8 = 0;
  *(undefined4 *)((longlong)param_1 + 0x1944) = 0;
  FUN_140004a10(param_1 + 0x329);
  plVar11 = param_1 + 0x36d;
  lVar10 = 2;
  _eh_vector_constructor_iterator_(plVar11,0x220,2,FUN_140008660,FUN_140008a20);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x3f9));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x3fa));
  param_1[0x16] = param_2;
  param_1[0x3fb] = param_2 + 0x1910;
  param_1[0x3fc] = param_3;
  param_1[0x13] = 0;
  param_1[0x119] = 0x3ff0000000000000;
  *(undefined4 *)(param_1 + 0x3fd) = 0;
  InitializeCriticalSection((LPCRITICAL_SECTION)(param_1 + 1));
  pvVar4 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,0,0,"WriteEvent");
  param_1[6] = pvVar4;
  pvVar4 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,1,1,"AudSndThreadEnded");
  param_1[0x3f6] = pvVar4;
  pvVar4 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,1,1,"LocRecThreadEnded");
  param_1[0x3f7] = pvVar4;
  pvVar4 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,1,1,"RemRecThreadEnded");
  param_1[0x3f8] = pvVar4;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x3f9),"LOLA_REC");
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x3fa),"LOLA_REC");
  param_1[0x3fe] = 0;
  param_1[0x3ff] = 0;
  param_1[0x12] = 0;
  Pa_Initialize();
  *(undefined8 *)((longlong)param_1 + 0xbc) = 0;
  *(undefined4 *)((longlong)param_1 + 0xc4) = 0;
  *(undefined4 *)(param_1 + 0x17) = 0xffffffff;
  iVar1 = Pa_GetHostApiCount();
  iVar2 = iVar9;
  if (0 < iVar1) {
    do {
      iVar8 = iVar2;
      lVar5 = Pa_GetHostApiInfo(iVar8);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                (local_res10,*(char **)(lVar5 + 8));
      iVar2 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
              Compare(local_res10,"ASIO");
      if (iVar2 == 0) {
        *(undefined4 *)((longlong)param_1 + 0xbc) = *(undefined4 *)(lVar5 + 0x10);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res10);
        break;
      }
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res10);
      iVar8 = iVar8 + 1;
      iVar2 = iVar8;
    } while (iVar8 < iVar1);
  }
  *(int *)(param_1 + 0x17) = iVar8;
  if (0 < *(int *)((longlong)param_1 + 0xbc)) {
    do {
      uVar3 = Pa_HostApiDeviceIndexToDeviceIndex(*(undefined4 *)(param_1 + 0x17),iVar9);
      lVar5 = Pa_GetDeviceInfo(uVar3);
      pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_res10,*(char **)(lVar5 + 8));
      this = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + (longlong)iVar9 + 0x19);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                (this,pCVar6);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res10);
      iVar2 = *(int *)(lVar5 + 0x14);
      iVar1 = *(int *)(lVar5 + 0x18);
      if (0 < iVar2) {
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   (param_1 + (longlong)*(int *)(param_1 + 0x18) + 0x59),this);
        *(int *)((longlong)param_1 + (longlong)*(int *)(param_1 + 0x18) * 4 + 0x6c8) = iVar2;
        *(int *)(param_1 + 0x18) = *(int *)(param_1 + 0x18) + 1;
      }
      if (0 < iVar1) {
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   (param_1 + (longlong)*(int *)((longlong)param_1 + 0xc4) + 0x99),this);
        *(int *)((longlong)param_1 + (longlong)*(int *)((longlong)param_1 + 0xc4) * 4 + 0x7c8) =
             iVar1;
        *(int *)((longlong)param_1 + 0xc4) = *(int *)((longlong)param_1 + 0xc4) + 1;
      }
      iVar9 = iVar9 + 1;
    } while (iVar9 < *(int *)((longlong)param_1 + 0xbc));
  }
  *(undefined2 *)(param_1 + 0x322) = 0;
  *(undefined4 *)((longlong)param_1 + 0x1914) = 0;
  puVar7 = param_1 + 0x3ae;
  lVar5 = 2;
  do {
    puVar7[-1] = 0;
    *puVar7 = 0;
    puVar7[1] = 0;
    FUN_14000ab60(plVar11,&DAT_1400439ac,0);
    *(undefined2 *)(puVar7 + 2) = 0;
    plVar11 = plVar11 + 0x44;
    puVar7 = puVar7 + 0x44;
    lVar5 = lVar5 + -1;
  } while (lVar5 != 0);
  *(undefined1 *)(param_1 + 0x402) = 0;
  param_1[0x36c] = 0;
  *(undefined4 *)(param_1 + 0x250) = 1;
  *(undefined4 *)((longlong)param_1 + 0x1284) = 1;
  *(undefined4 *)(param_1 + 0x183) = 0;
  *(undefined4 *)(param_1 + 0x11a) = 0;
  param_1[0x11c] = 0;
  param_1[0x11d] = 0;
  puVar7 = param_1 + 0x185;
  do {
    puVar7[-1] = 0;
    *puVar7 = 0;
    puVar7[1] = 0;
    puVar7[2] = 0;
    puVar7[3] = 0;
    puVar7[4] = 0;
    puVar7[5] = 0;
    puVar7[6] = 0;
    puVar7[7] = 0;
    puVar7[8] = 0;
    puVar7[9] = 0;
    puVar7[10] = 0;
    puVar7[0xb] = 0;
    puVar7[0xc] = 0;
    puVar7[0xd] = 0;
    puVar7[0xe] = 0;
    puVar7[0xf] = 0;
    puVar7[0x10] = 0;
    puVar7[0x11] = 0;
    puVar7[0x12] = 0;
    puVar7[0x13] = 0;
    puVar7[0x14] = 0;
    puVar7[0x15] = 0;
    puVar7[0x16] = 0;
    puVar7[0x17] = 0;
    puVar7[0x18] = 0;
    puVar7[0x19] = 0;
    puVar7[0x1a] = 0;
    puVar7[0x1b] = 0;
    puVar7[0x1c] = 0;
    puVar7[0x1d] = 0;
    puVar7[0x1e] = 0;
    puVar7[0x1f] = 0;
    puVar7[0x20] = 0;
    puVar7[0x21] = 0;
    puVar7[0x22] = 0;
    puVar7[0x23] = 0;
    puVar7[0x24] = 0;
    puVar7[0x25] = 0;
    puVar7[0x26] = 0;
    puVar7[0x27] = 0;
    puVar7[0x28] = 0;
    puVar7[0x29] = 0;
    puVar7[0x2a] = 0;
    puVar7[0x2b] = 0;
    puVar7[0x2c] = 0;
    puVar7[0x2d] = 0;
    puVar7[0x2e] = 0;
    puVar7[0x2f] = 0;
    puVar7[0x30] = 0;
    puVar7[0x31] = 0;
    puVar7[0x32] = 0;
    puVar7[0x33] = 0;
    puVar7[0x34] = 0;
    puVar7[0x35] = 0;
    puVar7[0x36] = 0;
    puVar7[0x37] = 0;
    puVar7[0x38] = 0;
    puVar7[0x39] = 0;
    puVar7[0x3a] = 0;
    puVar7[0x3b] = 0;
    puVar7[0x3c] = 0;
    puVar7[0x3d] = 0;
    puVar7[0x3e] = 0;
    puVar7[0x3f] = 0;
    puVar7[0x40] = 0;
    puVar7[0x41] = 0;
    puVar7[0x42] = 0;
    puVar7[0x43] = 0;
    puVar7[0x44] = 0;
    puVar7[0x45] = 0;
    puVar7[0x46] = 0;
    puVar7[0x47] = 0;
    puVar7[0x48] = 0;
    puVar7[0x49] = 0;
    puVar7[0x4a] = 0;
    puVar7[0x4b] = 0;
    puVar7[0x4c] = 0;
    puVar7[0x4d] = 0;
    puVar7[0x4e] = 0;
    puVar7[0x4f] = 0;
    puVar7[0x50] = 0;
    puVar7[0x51] = 0;
    puVar7[0x52] = 0;
    puVar7[0x53] = 0;
    puVar7[0x54] = 0;
    puVar7[0x55] = 0;
    puVar7[0x56] = 0;
    puVar7[0x57] = 0;
    puVar7[0x58] = 0;
    puVar7[0x59] = 0;
    puVar7[0x5a] = 0;
    puVar7[0x5b] = 0;
    puVar7[0x5c] = 0;
    puVar7[0x5d] = 0;
    puVar7[0x5e] = 0;
    puVar7[0x5f] = 0;
    puVar7[0x60] = 0;
    puVar7[0x61] = 0;
    puVar7[0x62] = 0;
    puVar7 = puVar7 + 0x66;
    lVar10 = lVar10 + -1;
  } while (lVar10 != 0);
  param_1[0x252] = 0;
  param_1[0x253] = 0;
  param_1[0x254] = 0;
  param_1[0x255] = 0;
  param_1[0x256] = 0;
  param_1[599] = 0;
  param_1[600] = 0;
  param_1[0x259] = 0;
  param_1[0x25a] = 0;
  param_1[0x25b] = 0;
  param_1[0x25c] = 0;
  param_1[0x25d] = 0;
  param_1[0x25e] = 0;
  param_1[0x25f] = 0;
  param_1[0x260] = 0;
  param_1[0x261] = 0;
  param_1[0x262] = 0;
  param_1[0x263] = 0;
  param_1[0x264] = 0;
  param_1[0x265] = 0;
  param_1[0x266] = 0;
  param_1[0x267] = 0;
  param_1[0x268] = 0;
  param_1[0x269] = 0;
  param_1[0x26a] = 0;
  param_1[0x26b] = 0;
  param_1[0x26c] = 0;
  param_1[0x26d] = 0;
  param_1[0x26e] = 0;
  param_1[0x26f] = 0;
  param_1[0x270] = 0;
  param_1[0x271] = 0;
  param_1[0x272] = 0;
  param_1[0x273] = 0;
  param_1[0x274] = 0;
  param_1[0x275] = 0;
  param_1[0x276] = 0;
  param_1[0x277] = 0;
  param_1[0x278] = 0;
  param_1[0x279] = 0;
  param_1[0x27a] = 0;
  param_1[0x27b] = 0;
  param_1[0x27c] = 0;
  param_1[0x27d] = 0;
  param_1[0x27e] = 0;
  param_1[0x27f] = 0;
  param_1[0x280] = 0;
  param_1[0x281] = 0;
  param_1[0x282] = 0;
  param_1[0x283] = 0;
  param_1[0x284] = 0;
  param_1[0x285] = 0;
  param_1[0x286] = 0;
  param_1[0x287] = 0;
  param_1[0x288] = 0;
  param_1[0x289] = 0;
  param_1[0x28a] = 0;
  param_1[0x28b] = 0;
  param_1[0x28c] = 0;
  param_1[0x28d] = 0;
  param_1[0x28e] = 0;
  param_1[0x28f] = 0;
  param_1[0x290] = 0;
  param_1[0x291] = 0;
  param_1[0x292] = 0;
  param_1[0x293] = 0;
  param_1[0x294] = 0;
  param_1[0x295] = 0;
  param_1[0x296] = 0;
  param_1[0x297] = 0;
  param_1[0x298] = 0;
  param_1[0x299] = 0;
  param_1[0x29a] = 0;
  param_1[0x29b] = 0;
  param_1[0x29c] = 0;
  param_1[0x29d] = 0;
  param_1[0x29e] = 0;
  param_1[0x29f] = 0;
  param_1[0x2a0] = 0;
  param_1[0x2a1] = 0;
  param_1[0x2a2] = 0;
  param_1[0x2a3] = 0;
  param_1[0x2a4] = 0;
  param_1[0x2a5] = 0;
  param_1[0x2a6] = 0;
  param_1[0x2a7] = 0;
  param_1[0x2a8] = 0;
  param_1[0x2a9] = 0;
  param_1[0x2aa] = 0;
  param_1[0x2ab] = 0;
  param_1[0x2ac] = 0;
  param_1[0x2ad] = 0;
  param_1[0x2ae] = 0;
  param_1[0x2af] = 0;
  param_1[0x2b0] = 0;
  param_1[0x2b1] = 0;
  param_1[0x2b2] = 0;
  param_1[0x2b3] = 0;
  param_1[0x2b4] = 0;
  param_1[0x2b5] = 0;
  param_1[0x2b7] = 0;
  param_1[0x2b8] = 0;
  param_1[0x2b9] = 0;
  param_1[0x2ba] = 0;
  param_1[699] = 0;
  param_1[700] = 0;
  param_1[0x2bd] = 0;
  param_1[0x2be] = 0;
  param_1[0x2bf] = 0;
  param_1[0x2c0] = 0;
  param_1[0x2c1] = 0;
  param_1[0x2c2] = 0;
  param_1[0x2c3] = 0;
  param_1[0x2c4] = 0;
  param_1[0x2c5] = 0;
  param_1[0x2c6] = 0;
  param_1[0x2c7] = 0;
  param_1[0x2c8] = 0;
  param_1[0x2c9] = 0;
  param_1[0x2ca] = 0;
  param_1[0x2cb] = 0;
  param_1[0x2cc] = 0;
  param_1[0x2cd] = 0;
  param_1[0x2ce] = 0;
  param_1[0x2cf] = 0;
  param_1[0x2d0] = 0;
  param_1[0x2d1] = 0;
  param_1[0x2d2] = 0;
  param_1[0x2d3] = 0;
  param_1[0x2d4] = 0;
  param_1[0x2d5] = 0;
  param_1[0x2d6] = 0;
  param_1[0x2d7] = 0;
  param_1[0x2d8] = 0;
  param_1[0x2d9] = 0;
  param_1[0x2da] = 0;
  param_1[0x2db] = 0;
  param_1[0x2dc] = 0;
  param_1[0x2dd] = 0;
  param_1[0x2de] = 0;
  param_1[0x2df] = 0;
  param_1[0x2e0] = 0;
  param_1[0x2e1] = 0;
  param_1[0x2e2] = 0;
  param_1[0x2e3] = 0;
  param_1[0x2e4] = 0;
  param_1[0x2e5] = 0;
  param_1[0x2e6] = 0;
  param_1[0x2e7] = 0;
  param_1[0x2e8] = 0;
  param_1[0x2e9] = 0;
  param_1[0x2ea] = 0;
  param_1[0x2eb] = 0;
  param_1[0x2ec] = 0;
  param_1[0x2ed] = 0;
  param_1[0x2ee] = 0;
  param_1[0x2ef] = 0;
  param_1[0x2f0] = 0;
  param_1[0x2f1] = 0;
  param_1[0x2f2] = 0;
  param_1[0x2f3] = 0;
  param_1[0x2f4] = 0;
  param_1[0x2f5] = 0;
  param_1[0x2f6] = 0;
  param_1[0x2f7] = 0;
  param_1[0x2f8] = 0;
  param_1[0x2f9] = 0;
  param_1[0x2fa] = 0;
  param_1[0x2fb] = 0;
  param_1[0x2fc] = 0;
  param_1[0x2fd] = 0;
  param_1[0x2fe] = 0;
  param_1[0x2ff] = 0;
  param_1[0x300] = 0;
  param_1[0x301] = 0;
  param_1[0x302] = 0;
  param_1[0x303] = 0;
  param_1[0x304] = 0;
  param_1[0x305] = 0;
  param_1[0x306] = 0;
  param_1[0x307] = 0;
  param_1[0x308] = 0;
  param_1[0x309] = 0;
  param_1[0x30a] = 0;
  param_1[0x30b] = 0;
  param_1[0x30c] = 0;
  param_1[0x30d] = 0;
  param_1[0x30e] = 0;
  param_1[0x30f] = 0;
  param_1[0x310] = 0;
  param_1[0x311] = 0;
  param_1[0x312] = 0;
  param_1[0x313] = 0;
  param_1[0x314] = 0;
  param_1[0x315] = 0;
  param_1[0x316] = 0;
  param_1[0x317] = 0;
  param_1[0x318] = 0;
  param_1[0x319] = 0;
  param_1[0x31a] = 0;
  *(undefined8 *)((longlong)param_1 + 0xa4) = 0;
  *(undefined4 *)((longlong)param_1 + 0x18ec) = 0;
  *(undefined4 *)(param_1 + 0x14) = 0;
  param_1[0x3f5] = 0;
  param_1[0x324] = 0;
  param_1[0x400] = 0;
  param_1[0x401] = 0;
  return param_1;
}

