
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_140011c10(longlong param_1,undefined8 param_2,undefined8 param_3,char *param_4)

{
  int *piVar1;
  u_short uVar2;
  uint uVar3;
  int iVar4;
  undefined4 uVar5;
  ulong uVar6;
  undefined8 *puVar7;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar8;
  IAtlStringMgr *pIVar9;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar10;
  undefined8 uVar11;
  char *pcVar12;
  uint uVar13;
  undefined8 *puVar14;
  longlong *plVar15;
  char *pcVar16;
  longlong lVar17;
  uint *puVar18;
  longlong lVar19;
  undefined4 *puVar20;
  undefined1 auStackY_418 [32];
  uint local_3c8;
  uint local_3c4;
  uint local_3c0;
  uint local_3bc;
  uint local_3b8;
  uint local_3b4;
  uint local_3b0;
  void *local_3a8;
  undefined4 local_3a0;
  int local_39c;
  int local_398;
  uint local_394;
  char *local_390;
  undefined8 *local_388;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_380 [8];
  longlong local_378;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_370 [8];
  void *local_368;
  undefined8 *local_360;
  void *local_358;
  undefined8 local_350 [4];
  undefined8 local_330;
  undefined8 local_328;
  undefined1 local_320 [40];
  int local_2f8;
  uint local_2f4;
  uint local_2f0;
  int local_2ec;
  uint local_208;
  undefined1 local_128 [176];
  undefined8 local_78;
  undefined8 uStack_70;
  undefined8 local_68;
  undefined8 uStack_60;
  ulonglong local_38;
  undefined8 *_Size;
  
  local_330 = 0xfffffffffffffffe;
  local_38 = DAT_1400630d8 ^ (ulonglong)auStackY_418;
  puVar14 = (undefined8 *)0x0;
  local_3b0 = 0;
  local_3c4 = 0;
  *(undefined4 *)(param_1 + 0x1188) = 0;
  local_388 = operator_new(0x30);
  puVar7 = puVar14;
  if (local_388 != (undefined8 *)0x0) {
    puVar7 = FUN_140006c50(local_388);
  }
  *(undefined8 **)(param_1 + 0x11b8) = puVar7;
  FUN_140007250((longlong)puVar7,*(uint *)(param_1 + 0x1204));
  iVar4 = FUN_140006ef0(*(longlong *)(param_1 + 0x11b8));
  *(int *)(param_1 + 0x11b4) = iVar4;
  local_388 = operator_new(0x10);
  puVar7 = puVar14;
  if (local_388 != (undefined8 *)0x0) {
    puVar7 = FUN_1400209e0(local_388,iVar4);
  }
  *(undefined8 **)(param_1 + 0x1828) = puVar7;
  puVar7 = operator_new(0x10);
  *(undefined8 *)(param_1 + 0x15f8) = 0;
  *(undefined8 *)(param_1 + 0x1818) = 0;
  local_360 = puVar7;
  FUN_140004a10(local_350);
  if (*(int *)(param_1 + 0x1110) == 0) {
    local_3c0 = *(uint *)(param_1 + 0x10d0);
  }
  else {
    local_3c0 = *(uint *)(param_1 + 0x10d4);
  }
  ResetEvent(*(HANDLE *)(param_1 + 0x468));
  *(undefined4 *)(param_1 + 0x118c) = 1;
  uVar13 = (uint)(*(int *)(param_1 + 0x10c8) * *(int *)(param_1 + 0x10cc) *
                 *(int *)(param_1 + 0x10dc)) >> 3;
  _Size = (undefined8 *)(ulonglong)uVar13;
  local_3a0 = *(undefined4 *)(*(longlong *)(param_1 + 0x440) + 0x9c);
  local_388 = _Size;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_390
             ,"Jpeg encoding: ");
  local_3a8 = malloc((size_t)_Size);
  local_3c8 = uVar13;
  memset(local_320,0,0x1f0);
  memset(local_128,0,0xa8);
  local_328 = jpeg_std_error(local_128);
  jpeg_CreateCompress(&local_328,0x3e,0x1f8);
  local_2f8 = *(int *)(param_1 + 0x10c8);
  local_2f4 = *(uint *)(param_1 + 0x10cc);
  local_2f0 = *(uint *)(param_1 + 0x10dc) >> 3;
  local_2ec = (local_2f0 == 3) + 1;
  iVar4 = *(int *)(param_1 + 0x118c);
  while (iVar4 != 0) {
    lVar19 = 2;
    WaitForSingleObject(*(HANDLE *)(param_1 + 0x450),0xffffffff);
    if (*(int *)(param_1 + 0x118c) == 0) break;
    ResetEvent(*(HANDLE *)(param_1 + 0x450));
    if (*(int *)(*(longlong *)(param_1 + 0x1840) + 0x2c8) != 0) {
      FUN_140020e20(param_1 + 0x1158);
    }
    local_3c8 = (uint)_Size;
    jpeg_set_defaults(&local_328);
    jpeg_set_quality(&local_328,local_3a0,1);
    puVar18 = &local_3c8;
    jpeg_mem_dest(&local_328,&local_3a8);
    jpeg_start_compress(&local_328,1);
    iVar4 = local_2f0 * local_2f8;
    if (local_208 < local_2f4) {
      do {
        local_378 = (ulonglong)(local_208 * iVar4) + *(longlong *)(param_1 + 0x1838);
        puVar18 = (uint *)0x1;
        jpeg_write_scanlines(&local_328,&local_378);
      } while (local_208 < local_2f4);
    }
    jpeg_finish_compress(&local_328);
    if (*(int *)(*(longlong *)(param_1 + 0x1840) + 0x2c8) != 0) {
      pCVar8 = FUN_140020e30(param_1 + 0x1158,local_370,puVar18,param_4);
      pIVar9 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_390);
      pCVar10 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          (local_380,pIVar9);
      local_3c4 = (uint)puVar14 | 1;
      param_4 = *(char **)pCVar8;
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_380,local_390,*(int *)(local_390 + -0x10),param_4,
                 *(int *)(param_4 + -0x10));
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (*(longlong *)(param_1 + 0x1840) + 0x350),pCVar10);
      local_3b0 = (uint)puVar14 & 0xfffffffe;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_380);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_370);
    }
    puVar14 = (undefined8 *)(param_1 + 0x15f8);
    FUN_140004dc0((longlong)local_350);
    FUN_140004ff0((longlong)local_350,(void *)(param_1 + 0x1188),1);
    local_3c0 = local_3c8;
    FUN_140004ff0((longlong)local_350,&local_3c0,1);
    FUN_140004e40((longlong)local_350,local_3a8,local_3c0);
    if (*(int *)(param_1 + 0x1980) != 0) {
      *(void **)(param_1 + 0x1988) = local_3a8;
      *(uint *)(param_1 + 0x1990) = local_3c8;
      SetEvent(*(HANDLE *)(param_1 + 0x458));
    }
    FUN_140004bf0((longlong)local_350,&local_368,&local_3bc);
    uVar13 = FUN_140006ef0(*(longlong *)(param_1 + 0x11b8));
    local_3b8 = uVar13;
    FUN_1400070b0(*(longlong *)(param_1 + 0x11b8),local_368,local_3bc);
    iVar4 = (uVar13 + 0x32) * 0x1e;
    lVar17 = 2;
    local_39c = iVar4;
    do {
      uVar11 = pcap_sendqueue_alloc(iVar4);
      *puVar14 = uVar11;
      puVar14 = puVar14 + 0x44;
      lVar17 = lVar17 + -1;
    } while (lVar17 != 0);
    uVar5 = FUN_140006eb0(*(longlong *)(param_1 + 0x11b8));
    *(undefined4 *)(param_1 + 0x11d0) = uVar5;
    *(uint *)(param_1 + 0x11d8) = uVar13;
    *(uint *)(param_1 + 0x11d4) = local_3bc;
    local_3c4 = FUN_140006ec0(*(longlong *)(param_1 + 0x11b8));
    puVar7 = local_360;
    *(uint *)(param_1 + 0x11dc) = local_3c4;
    local_78 = *(undefined8 *)(param_1 + 0x11c0);
    uStack_70 = *(undefined8 *)(param_1 + 0x11c8);
    local_68 = *(undefined8 *)(param_1 + 0x11d0);
    uStack_60 = *(undefined8 *)(param_1 + 0x11d8);
    local_360[1] = 0x6a;
    *local_360 = 0;
    pcVar16 = (char *)(param_1 + 0x1600);
    puVar20 = (undefined4 *)(param_1 + 0x141a);
    do {
      if (((*pcVar16 != '\0') && (*(longlong *)(pcVar16 + -0x10) != 0)) && (pcVar16[1] == '\0')) {
        pcVar12 = pcVar16 + -0x218;
        if (0xf < *(ulonglong *)(pcVar16 + -0x200)) {
          pcVar12 = *(char **)pcVar12;
        }
        uVar2 = *(u_short *)(param_1 + 0x11b0);
        plVar15 = *(longlong **)(param_1 + 0x1828);
        uVar6 = inet_addr(pcVar12);
        param_4 = (char *)(ulonglong)*(uint *)(pcVar16 + -500);
        FUN_140020ba0(plVar15,puVar20,(undefined4 *)((longlong)puVar20 + -6),
                      *(uint *)(pcVar16 + -500),uVar6,uVar2,uVar2,&local_78,0x40);
        pcap_sendqueue_queue
                  (*(undefined8 *)(pcVar16 + -8),puVar7,**(undefined8 **)(param_1 + 0x1828));
      }
      puVar20 = puVar20 + 0x88;
      pcVar16 = pcVar16 + 0x220;
      lVar19 = lVar19 + -1;
    } while (lVar19 != 0);
    local_3b4 = 0;
    if (local_3c4 != 0) {
      local_394 = local_3c4 - 1;
      local_398 = local_3b8 + 0x2a;
      do {
        uVar3 = local_394;
        iVar4 = local_398;
        uVar13 = local_3b4;
        local_358 = (void *)FUN_140006ee0(*(longlong *)(param_1 + 0x11b8),local_3b4);
        if (uVar13 == uVar3) {
          *(undefined1 *)((longlong)local_358 + 0x20) = 1;
        }
        *(int *)((longlong)puVar7 + 0xc) = iVar4;
        *(int *)(puVar7 + 1) = iVar4;
        *puVar7 = 0;
        pcVar16 = (char *)(param_1 + 0x1600);
        puVar20 = (undefined4 *)(param_1 + 0x141a);
        lVar19 = 2;
        do {
          if (((*pcVar16 != '\0') && (*(longlong *)(pcVar16 + -0x10) != 0)) && (pcVar16[1] == '\0'))
          {
            pcVar12 = pcVar16 + -0x218;
            if (0xf < *(ulonglong *)(pcVar16 + -0x200)) {
              pcVar12 = *(char **)pcVar12;
            }
            uVar2 = *(u_short *)(param_1 + 0x11b0);
            plVar15 = *(longlong **)(param_1 + 0x1828);
            uVar6 = inet_addr(pcVar12);
            param_4 = (char *)(ulonglong)*(uint *)(pcVar16 + -500);
            FUN_140020ba0(plVar15,puVar20,(undefined4 *)((longlong)puVar20 + -6),
                          *(uint *)(pcVar16 + -500),uVar6,uVar2,uVar2,local_358,local_3b8);
            iVar4 = pcap_sendqueue_queue
                              (*(undefined8 *)(pcVar16 + -8),puVar7,
                               **(undefined8 **)(param_1 + 0x1828));
            if (iVar4 != 0) {
              pcap_sendqueue_transmit
                        (*(undefined8 *)(pcVar16 + -0x10),*(undefined8 *)(pcVar16 + -8),0);
              pcap_sendqueue_destroy(*(undefined8 *)(pcVar16 + -8));
              uVar11 = pcap_sendqueue_alloc(local_39c);
              *(undefined8 *)(pcVar16 + -8) = uVar11;
              pcap_sendqueue_queue(uVar11,puVar7,**(undefined8 **)(param_1 + 0x1828));
            }
          }
          puVar20 = puVar20 + 0x88;
          pcVar16 = pcVar16 + 0x220;
          lVar19 = lVar19 + -1;
        } while (lVar19 != 0);
        local_3b4 = local_3b4 + 1;
      } while (local_3b4 < local_3c4);
    }
    plVar15 = (longlong *)(param_1 + 0x15f0);
    lVar19 = 2;
    do {
      if ((((char)plVar15[2] != '\0') && (*plVar15 != 0)) &&
         (*(char *)((longlong)plVar15 + 0x11) == '\0')) {
        pcap_sendqueue_transmit(*plVar15,plVar15[1],0);
      }
      pcap_sendqueue_destroy(plVar15[1]);
      plVar15 = plVar15 + 0x44;
      lVar19 = lVar19 + -1;
    } while (lVar19 != 0);
    if (*(char *)(param_1 + 0x19d0) == '\0') {
      piVar1 = (int *)(*(longlong *)(param_1 + 0x448) + 0x1c);
      *piVar1 = *piVar1 + 1;
    }
    puVar14 = (undefined8 *)(ulonglong)local_3b0;
    _Size = local_388;
    iVar4 = *(int *)(param_1 + 0x118c);
  }
  lVar19 = 2;
  jpeg_destroy_compress(&local_328);
  if (local_3a8 != (void *)0x0) {
    free(local_3a8);
    local_3a8 = (void *)0x0;
  }
  puVar14 = *(undefined8 **)(param_1 + 0x1828);
  if (puVar14 != (undefined8 *)0x0) {
    FUN_140020a00(puVar14);
    free(puVar14);
    *(undefined8 *)(param_1 + 0x1828) = 0;
  }
  if (puVar7 != (undefined8 *)0x0) {
    free(puVar7);
  }
  puVar14 = *(undefined8 **)(param_1 + 0x11b8);
  if (puVar14 != (undefined8 *)0x0) {
    (**(code **)*puVar14)(puVar14,1);
    *(undefined8 *)(param_1 + 0x11b8) = 0;
  }
  EnterCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  plVar15 = (longlong *)(param_1 + 0x15f0);
  do {
    *(undefined1 *)(plVar15 + 2) = 0;
    if (*plVar15 != 0) {
      pcap_close();
      *plVar15 = 0;
    }
    plVar15 = plVar15 + 0x44;
    lVar19 = lVar19 + -1;
  } while (lVar19 != 0);
  LeaveCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  SetEvent(*(HANDLE *)(param_1 + 0x468));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_390
            );
  FUN_140004a40(local_350);
  return;
}

