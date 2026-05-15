
void FUN_140009bf0(longlong param_1)

{
  u_short uVar1;
  undefined1 auVar2 [16];
  ulong uVar3;
  undefined8 *puVar4;
  undefined8 *puVar5;
  __uint64 _Var6;
  undefined2 *_Dst;
  void *pvVar7;
  char *cp;
  uint uVar8;
  longlong lVar9;
  char *pcVar10;
  longlong *plVar11;
  int *piVar12;
  longlong lVar13;
  undefined4 *puVar14;
  uint local_res8 [2];
  undefined8 *local_res10;
  uint local_res18;
  void *local_res20;
  
  *(undefined4 *)(param_1 + 0x18ec) = 1;
  local_res10 = operator_new(0x30);
  puVar5 = (undefined8 *)0x0;
  puVar4 = puVar5;
  if (local_res10 != (undefined8 *)0x0) {
    puVar4 = FUN_140006c50(local_res10);
  }
  *(undefined8 **)(param_1 + 0x1920) = puVar4;
  if ((*(int *)(*(longlong *)(param_1 + 0x1fd8) + 0x108) == 0) || (7 < *(int *)(param_1 + 0x54))) {
    uVar8 = *(int *)(param_1 + 0x54) * 0x80 + 0x2a;
  }
  else {
    uVar8 = 0x42a;
  }
  *(uint *)(param_1 + 0x196c) = uVar8;
  FUN_140007250(*(longlong *)(param_1 + 0x1920),uVar8);
  *(uint *)(param_1 + 0x1968) = (uint)*(ushort *)(param_1 + 0x3a) << 7;
  *(undefined4 *)(param_1 + 0x1934) = 0;
  local_res10 = operator_new(0x10);
  if (local_res10 != (undefined8 *)0x0) {
    puVar5 = FUN_1400209e0(local_res10,*(int *)(param_1 + 0x196c));
  }
  *(undefined8 **)(param_1 + 0x1b60) = puVar5;
  *(undefined4 *)(param_1 + 0x18e8) = 0;
  local_res18 = FUN_140006ef0(*(longlong *)(param_1 + 0x1920));
  *(uint *)(param_1 + 0x1914) = local_res18;
  local_res8[0] = (uint)*(ushort *)(param_1 + 0x3a) << 7;
  auVar2._8_8_ = 0;
  auVar2._0_8_ = (longlong)(*(int *)(param_1 + 0x54) << 6);
  _Var6 = SUB168(ZEXT816(2) * auVar2,0);
  if (SUB168(ZEXT816(2) * auVar2,8) != 0) {
    _Var6 = 0xffffffffffffffff;
  }
  _Dst = operator_new(_Var6);
  memset(_Dst,0,(longlong)(*(int *)(param_1 + 0x54) << 6) * 2);
  FUN_140008b10(param_1,_Dst,*(int *)(param_1 + 0x54));
  ResetEvent(*(HANDLE *)(param_1 + 0x1fb0));
  ResetEvent(*(HANDLE *)(param_1 + 0x30));
  *(undefined4 *)(param_1 + 0x18ec) = 1;
  do {
    lVar13 = 2;
    piVar12 = (int *)(param_1 + 0x18e8);
    lVar9 = param_1 + 0x1948;
    FUN_140004dc0(lVar9);
    FUN_140004ff0(lVar9,piVar12,1);
    *piVar12 = *piVar12 + 1;
    WaitForSingleObject(*(HANDLE *)(param_1 + 0x30),0xffffffff);
    if (*(int *)(param_1 + 0x18ec) == 0) break;
    ResetEvent(*(HANDLE *)(param_1 + 0x30));
    if (*(int *)(param_1 + 0x1fe8) != 0) {
      *(undefined2 **)(param_1 + 0x1288) = _Dst;
    }
    FUN_140004ff0(lVar9,local_res8,1);
    FUN_140004e40(lVar9,*(void **)(param_1 + 0x1288),local_res8[0]);
    FUN_140004bf0(lVar9,&local_res20,(undefined4 *)&local_res10);
    FUN_1400070b0(*(longlong *)(param_1 + 0x1920),local_res20,(uint)local_res10);
    pvVar7 = (void *)FUN_140006ee0(*(longlong *)(param_1 + 0x1920),0);
    *(undefined1 *)((longlong)pvVar7 + 0x20) = 1;
    pcVar10 = (char *)(param_1 + 0x1d80);
    puVar14 = (undefined4 *)(param_1 + 0x1b9a);
    do {
      EnterCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
      if (((*pcVar10 != '\0') && (*(longlong *)(pcVar10 + -0x10) != 0)) && (pcVar10[1] == '\0')) {
        cp = pcVar10 + -0x218;
        if (0xf < *(ulonglong *)(pcVar10 + -0x200)) {
          cp = *(char **)cp;
        }
        uVar1 = *(u_short *)(param_1 + 0x1910);
        plVar11 = *(longlong **)(param_1 + 0x1b60);
        uVar3 = inet_addr(cp);
        FUN_140020ba0(plVar11,puVar14,(undefined4 *)((longlong)puVar14 + -6),
                      *(undefined4 *)(pcVar10 + -500),uVar3,uVar1,uVar1,pvVar7,local_res18);
        pcap_sendpacket(*(undefined8 *)(pcVar10 + -0x10),**(undefined8 **)(param_1 + 0x1b60),
                        *(int *)(*(undefined8 **)(param_1 + 0x1b60) + 1) + 0x2a);
      }
      LeaveCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
      puVar14 = puVar14 + 0x88;
      pcVar10 = pcVar10 + 0x220;
      lVar13 = lVar13 + -1;
    } while (lVar13 != 0);
    if (*(char *)(param_1 + 0x2010) == '\0') {
      piVar12 = (int *)(*(longlong *)(param_1 + 0x1fe0) + 4);
      *piVar12 = *piVar12 + 1;
    }
  } while (*(int *)(param_1 + 0x18ec) != 0);
  lVar9 = 2;
  puVar4 = *(undefined8 **)(param_1 + 0x1b60);
  if (puVar4 != (undefined8 *)0x0) {
    FUN_140020a00(puVar4);
    free(puVar4);
    *(undefined8 *)(param_1 + 0x1b60) = 0;
  }
  puVar4 = *(undefined8 **)(param_1 + 0x1920);
  if (puVar4 != (undefined8 *)0x0) {
    (**(code **)*puVar4)(puVar4,1);
    *(undefined8 *)(param_1 + 0x1920) = 0;
  }
  EnterCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  plVar11 = (longlong *)(param_1 + 0x1d70);
  do {
    *(undefined1 *)(plVar11 + 2) = 0;
    if (*plVar11 != 0) {
      pcap_close();
      *plVar11 = 0;
    }
    plVar11 = plVar11 + 0x44;
    lVar9 = lVar9 + -1;
  } while (lVar9 != 0);
  LeaveCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  if (_Dst != (undefined2 *)0x0) {
    free(_Dst);
  }
  SetEvent(*(HANDLE *)(param_1 + 0x1fb0));
  return;
}

