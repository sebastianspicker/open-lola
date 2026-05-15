
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_1400115c0(longlong param_1)

{
  int *piVar1;
  u_short uVar2;
  uint uVar3;
  int iVar4;
  uint uVar5;
  undefined4 uVar6;
  ulong uVar7;
  undefined8 *puVar8;
  undefined8 *puVar9;
  undefined8 uVar10;
  char *pcVar11;
  longlong *plVar12;
  char *pcVar13;
  longlong lVar14;
  longlong lVar15;
  undefined4 *puVar16;
  undefined1 auStackY_138 [32];
  uint local_e8;
  uint local_e4;
  uint local_e0;
  uint local_dc;
  uint local_d8;
  int local_d4;
  int local_d0;
  uint local_cc;
  undefined8 *local_c8;
  void *local_c0;
  undefined8 *local_b8;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_b0 [8];
  undefined8 local_a8 [4];
  undefined8 local_88;
  undefined8 local_78;
  undefined8 uStack_70;
  undefined8 local_68;
  undefined8 uStack_60;
  ulonglong local_38;
  
  local_88 = 0xfffffffffffffffe;
  local_38 = DAT_1400630d8 ^ (ulonglong)auStackY_138;
  puVar9 = (undefined8 *)0x0;
  *(undefined4 *)(param_1 + 0x1188) = 0;
  local_c8 = operator_new(0x30);
  puVar8 = puVar9;
  if (local_c8 != (undefined8 *)0x0) {
    puVar8 = FUN_140006c50(local_c8);
  }
  *(undefined8 **)(param_1 + 0x11b8) = puVar8;
  FUN_140007250((longlong)puVar8,*(uint *)(param_1 + 0x1204));
  iVar4 = FUN_140006ef0(*(longlong *)(param_1 + 0x11b8));
  *(int *)(param_1 + 0x11b4) = iVar4;
  local_c8 = operator_new(0x10);
  if (local_c8 != (undefined8 *)0x0) {
    puVar9 = FUN_1400209e0(local_c8,iVar4);
  }
  *(undefined8 **)(param_1 + 0x1828) = puVar9;
  puVar8 = operator_new(0x10);
  *(undefined8 *)(param_1 + 0x15f8) = 0;
  *(undefined8 *)(param_1 + 0x1818) = 0;
  local_b8 = puVar8;
  FUN_140004a10(local_a8);
  if (*(int *)(param_1 + 0x1110) == 0) {
    local_e8 = *(uint *)(param_1 + 0x10d0);
  }
  else {
    local_e8 = *(uint *)(param_1 + 0x10d4);
  }
  ResetEvent(*(HANDLE *)(param_1 + 0x468));
  *(undefined4 *)(param_1 + 0x118c) = 1;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            (local_b0,"Video Recording: ");
  iVar4 = *(int *)(param_1 + 0x118c);
  while (iVar4 != 0) {
    puVar9 = (undefined8 *)(param_1 + 0x15f8);
    lVar15 = 2;
    WaitForSingleObject(*(HANDLE *)(param_1 + 0x450),0xffffffff);
    if (*(int *)(param_1 + 0x118c) == 0) break;
    ResetEvent(*(HANDLE *)(param_1 + 0x450));
    if (*(int *)(param_1 + 0x1980) != 0) {
      *(undefined8 *)(param_1 + 0x1988) = *(undefined8 *)(param_1 + 0x1838);
      *(uint *)(param_1 + 0x1990) = local_e8;
      SetEvent(*(HANDLE *)(param_1 + 0x458));
    }
    FUN_140004dc0((longlong)local_a8);
    FUN_140004ff0((longlong)local_a8,(void *)(param_1 + 0x1188),1);
    FUN_140004ff0((longlong)local_a8,&local_e8,1);
    FUN_140004e40((longlong)local_a8,*(void **)(param_1 + 0x1838),local_e8);
    FUN_140004bf0((longlong)local_a8,&local_c0,&local_e4);
    uVar5 = FUN_140006ef0(*(longlong *)(param_1 + 0x11b8));
    local_e0 = uVar5;
    FUN_1400070b0(*(longlong *)(param_1 + 0x11b8),local_c0,local_e4);
    iVar4 = (uVar5 + 0x32) * 0x1e;
    lVar14 = 2;
    local_d4 = iVar4;
    do {
      uVar10 = pcap_sendqueue_alloc(iVar4);
      *puVar9 = uVar10;
      puVar9 = puVar9 + 0x44;
      lVar14 = lVar14 + -1;
    } while (lVar14 != 0);
    uVar6 = FUN_140006eb0(*(longlong *)(param_1 + 0x11b8));
    *(undefined4 *)(param_1 + 0x11d0) = uVar6;
    *(uint *)(param_1 + 0x11d8) = uVar5;
    *(uint *)(param_1 + 0x11d4) = local_e4;
    local_d8 = FUN_140006ec0(*(longlong *)(param_1 + 0x11b8));
    puVar8 = local_b8;
    *(uint *)(param_1 + 0x11dc) = local_d8;
    local_78 = *(undefined8 *)(param_1 + 0x11c0);
    uStack_70 = *(undefined8 *)(param_1 + 0x11c8);
    local_68 = *(undefined8 *)(param_1 + 0x11d0);
    uStack_60 = *(undefined8 *)(param_1 + 0x11d8);
    local_b8[1] = 0x6a;
    *local_b8 = 0;
    pcVar13 = (char *)(param_1 + 0x1600);
    puVar16 = (undefined4 *)(param_1 + 0x141a);
    do {
      if (((*pcVar13 != '\0') && (*(longlong *)(pcVar13 + -0x10) != 0)) && (pcVar13[1] == '\0')) {
        pcVar11 = pcVar13 + -0x218;
        if (0xf < *(ulonglong *)(pcVar13 + -0x200)) {
          pcVar11 = *(char **)pcVar11;
        }
        uVar2 = *(u_short *)(param_1 + 0x11b0);
        plVar12 = *(longlong **)(param_1 + 0x1828);
        uVar7 = inet_addr(pcVar11);
        FUN_140020ba0(plVar12,puVar16,(undefined4 *)((longlong)puVar16 + -6),
                      *(undefined4 *)(pcVar13 + -500),uVar7,uVar2,uVar2,&local_78,0x40);
        pcap_sendqueue_queue
                  (*(undefined8 *)(pcVar13 + -8),puVar8,**(undefined8 **)(param_1 + 0x1828));
      }
      puVar16 = puVar16 + 0x88;
      pcVar13 = pcVar13 + 0x220;
      lVar15 = lVar15 + -1;
    } while (lVar15 != 0);
    local_dc = 0;
    if (local_d8 != 0) {
      local_cc = local_d8 - 1;
      local_d0 = local_e0 + 0x2a;
      do {
        uVar3 = local_cc;
        iVar4 = local_d0;
        uVar5 = local_dc;
        local_c8 = (undefined8 *)FUN_140006ee0(*(longlong *)(param_1 + 0x11b8),local_dc);
        if (uVar5 == uVar3) {
          *(undefined1 *)(local_c8 + 4) = 1;
        }
        *(int *)((longlong)puVar8 + 0xc) = iVar4;
        *(int *)(puVar8 + 1) = iVar4;
        *puVar8 = 0;
        pcVar13 = (char *)(param_1 + 0x1600);
        puVar16 = (undefined4 *)(param_1 + 0x141a);
        lVar15 = 2;
        do {
          if (((*pcVar13 != '\0') && (*(longlong *)(pcVar13 + -0x10) != 0)) && (pcVar13[1] == '\0'))
          {
            pcVar11 = pcVar13 + -0x218;
            if (0xf < *(ulonglong *)(pcVar13 + -0x200)) {
              pcVar11 = *(char **)pcVar11;
            }
            uVar2 = *(u_short *)(param_1 + 0x11b0);
            plVar12 = *(longlong **)(param_1 + 0x1828);
            uVar7 = inet_addr(pcVar11);
            FUN_140020ba0(plVar12,puVar16,(undefined4 *)((longlong)puVar16 + -6),
                          *(undefined4 *)(pcVar13 + -500),uVar7,uVar2,uVar2,local_c8,local_e0);
            iVar4 = pcap_sendqueue_queue
                              (*(undefined8 *)(pcVar13 + -8),puVar8,
                               **(undefined8 **)(param_1 + 0x1828));
            if (iVar4 != 0) {
              pcap_sendqueue_transmit
                        (*(undefined8 *)(pcVar13 + -0x10),*(undefined8 *)(pcVar13 + -8),0);
              pcap_sendqueue_destroy(*(undefined8 *)(pcVar13 + -8));
              uVar10 = pcap_sendqueue_alloc(local_d4);
              *(undefined8 *)(pcVar13 + -8) = uVar10;
              pcap_sendqueue_queue(uVar10,puVar8,**(undefined8 **)(param_1 + 0x1828));
            }
          }
          puVar16 = puVar16 + 0x88;
          pcVar13 = pcVar13 + 0x220;
          lVar15 = lVar15 + -1;
        } while (lVar15 != 0);
        local_dc = local_dc + 1;
      } while (local_dc < local_d8);
    }
    plVar12 = (longlong *)(param_1 + 0x15f0);
    lVar15 = 2;
    do {
      if ((((char)plVar12[2] != '\0') && (*plVar12 != 0)) &&
         (*(char *)((longlong)plVar12 + 0x11) == '\0')) {
        pcap_sendqueue_transmit(*plVar12,plVar12[1],0);
      }
      pcap_sendqueue_destroy(plVar12[1]);
      plVar12 = plVar12 + 0x44;
      lVar15 = lVar15 + -1;
    } while (lVar15 != 0);
    if (*(char *)(param_1 + 0x19d0) == '\0') {
      piVar1 = (int *)(*(longlong *)(param_1 + 0x448) + 0x1c);
      *piVar1 = *piVar1 + 1;
    }
    iVar4 = *(int *)(param_1 + 0x118c);
  }
  lVar15 = 2;
  puVar9 = *(undefined8 **)(param_1 + 0x1828);
  if (puVar9 != (undefined8 *)0x0) {
    FUN_140020a00(puVar9);
    free(puVar9);
    *(undefined8 *)(param_1 + 0x1828) = 0;
  }
  if (puVar8 != (undefined8 *)0x0) {
    free(puVar8);
  }
  puVar8 = *(undefined8 **)(param_1 + 0x11b8);
  if (puVar8 != (undefined8 *)0x0) {
    (**(code **)*puVar8)(puVar8,1);
    *(undefined8 *)(param_1 + 0x11b8) = 0;
  }
  EnterCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  plVar12 = (longlong *)(param_1 + 0x15f0);
  do {
    *(undefined1 *)(plVar12 + 2) = 0;
    if (*plVar12 != 0) {
      pcap_close();
      *plVar12 = 0;
    }
    plVar12 = plVar12 + 0x44;
    lVar15 = lVar15 + -1;
  } while (lVar15 != 0);
  LeaveCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  SetEvent(*(HANDLE *)(param_1 + 0x468));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_b0);
  FUN_140004a40(local_a8);
  return;
}

