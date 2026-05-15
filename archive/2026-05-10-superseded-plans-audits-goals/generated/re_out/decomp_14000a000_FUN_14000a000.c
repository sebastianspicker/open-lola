
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_14000a000(void *param_1,int param_2,longlong param_3,CSimpleStringT<char,1> *param_4,
                  undefined2 param_5,int param_6)

{
  undefined8 *puVar1;
  char *pcVar2;
  undefined8 *puVar3;
  undefined8 *puVar4;
  undefined8 uVar5;
  CWinThread *pCVar6;
  undefined8 *puVar7;
  longlong lVar8;
  longlong lVar9;
  size_t sVar10;
  longlong lVar11;
  undefined1 auStackY_648 [32];
  undefined8 local_608 [60];
  undefined1 local_428 [480];
  undefined1 local_248 [512];
  ulonglong local_48;
  
  local_48 = DAT_1400630d8 ^ (ulonglong)auStackY_648;
  lVar9 = (longlong)param_2;
  pcVar2 = ATL::CSimpleStringT<char,1>::GetBuffer(param_4);
  sVar10 = 0xffffffffffffffff;
  do {
    sVar10 = sVar10 + 1;
  } while (pcVar2[sVar10] != '\0');
  FUN_14000ab60((longlong *)((longlong)param_1 + lVar9 * 0x220 + 0x1b68),pcVar2,sVar10);
  *(int *)(lVar9 * 0x330 + 0xf48 + (longlong)param_1) = param_6 + -1;
  *(undefined2 *)((longlong)param_1 + 0x1910) = param_5;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ((longlong)param_1 + 0x18e0),
             (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_3 + 8));
  pcap_findalldevs((longlong)param_1 + lVar9 * 0x220 + 0x1d68,local_248);
  if (*(int *)(*(longlong *)((longlong)param_1 + 0x18e0) + -0x10) != 0) {
    for (puVar3 = *(undefined8 **)((longlong)param_1 + lVar9 * 0x220 + 0x1d68);
        puVar3 != (undefined8 *)0x0; puVar3 = (undefined8 *)*puVar3) {
      pcVar2 = strstr((char *)puVar3[1],*(char **)((longlong)param_1 + 0x18e0));
      if (pcVar2 != (char *)0x0) {
        *(undefined8 **)((longlong)param_1 + lVar9 * 0x220 + 0x1d68) = puVar3;
        break;
      }
    }
  }
  puVar3 = (undefined8 *)
           FUN_140020660(local_428,*(longlong *)((longlong)param_1 + lVar9 * 0x220 + 0x1d68));
  lVar11 = 3;
  lVar8 = 3;
  puVar1 = local_608;
  do {
    puVar7 = puVar1;
    puVar4 = puVar3;
    uVar5 = puVar4[1];
    *puVar7 = *puVar4;
    puVar7[1] = uVar5;
    uVar5 = puVar4[3];
    puVar7[2] = puVar4[2];
    puVar7[3] = uVar5;
    uVar5 = puVar4[5];
    puVar7[4] = puVar4[4];
    puVar7[5] = uVar5;
    uVar5 = puVar4[7];
    puVar7[6] = puVar4[6];
    puVar7[7] = uVar5;
    uVar5 = puVar4[9];
    puVar7[8] = puVar4[8];
    puVar7[9] = uVar5;
    uVar5 = puVar4[0xb];
    puVar7[10] = puVar4[10];
    puVar7[0xb] = uVar5;
    uVar5 = puVar4[0xd];
    puVar7[0xc] = puVar4[0xc];
    puVar7[0xd] = uVar5;
    uVar5 = puVar4[0xf];
    puVar7[0xe] = puVar4[0xe];
    puVar7[0xf] = uVar5;
    lVar8 = lVar8 + -1;
    puVar3 = puVar4 + 0x10;
    puVar1 = puVar7 + 0x10;
  } while (lVar8 != 0);
  uVar5 = puVar4[0x11];
  puVar7[0x10] = puVar4[0x10];
  puVar7[0x11] = uVar5;
  uVar5 = puVar4[0x13];
  puVar7[0x12] = puVar4[0x12];
  puVar7[0x13] = uVar5;
  uVar5 = puVar4[0x15];
  puVar7[0x14] = puVar4[0x14];
  puVar7[0x15] = uVar5;
  uVar5 = puVar4[0x17];
  puVar7[0x16] = puVar4[0x16];
  puVar7[0x17] = uVar5;
  uVar5 = puVar4[0x19];
  puVar7[0x18] = puVar4[0x18];
  puVar7[0x19] = uVar5;
  uVar5 = puVar4[0x1b];
  puVar7[0x1a] = puVar4[0x1a];
  puVar7[0x1b] = uVar5;
  puVar3 = local_608;
  puVar1 = (undefined8 *)((longlong)param_1 + lVar9 * 0x220 + 0x1b88);
  do {
    puVar7 = puVar1;
    puVar4 = puVar3;
    uVar5 = puVar4[1];
    *puVar7 = *puVar4;
    puVar7[1] = uVar5;
    uVar5 = puVar4[3];
    puVar7[2] = puVar4[2];
    puVar7[3] = uVar5;
    uVar5 = puVar4[5];
    puVar7[4] = puVar4[4];
    puVar7[5] = uVar5;
    uVar5 = puVar4[7];
    puVar7[6] = puVar4[6];
    puVar7[7] = uVar5;
    uVar5 = puVar4[9];
    puVar7[8] = puVar4[8];
    puVar7[9] = uVar5;
    uVar5 = puVar4[0xb];
    puVar7[10] = puVar4[10];
    puVar7[0xb] = uVar5;
    uVar5 = puVar4[0xd];
    puVar7[0xc] = puVar4[0xc];
    puVar7[0xd] = uVar5;
    uVar5 = puVar4[0xf];
    puVar7[0xe] = puVar4[0xe];
    puVar7[0xf] = uVar5;
    lVar11 = lVar11 + -1;
    puVar3 = puVar4 + 0x10;
    puVar1 = puVar7 + 0x10;
  } while (lVar11 != 0);
  uVar5 = puVar4[0x11];
  puVar7[0x10] = puVar4[0x10];
  puVar7[0x11] = uVar5;
  uVar5 = puVar4[0x13];
  puVar7[0x12] = puVar4[0x12];
  puVar7[0x13] = uVar5;
  uVar5 = puVar4[0x15];
  puVar7[0x14] = puVar4[0x14];
  puVar7[0x15] = uVar5;
  uVar5 = puVar4[0x17];
  puVar7[0x16] = puVar4[0x16];
  puVar7[0x17] = uVar5;
  uVar5 = puVar4[0x19];
  puVar7[0x18] = puVar4[0x18];
  puVar7[0x19] = uVar5;
  uVar5 = puVar4[0x1b];
  puVar7[0x1a] = puVar4[0x1a];
  puVar7[0x1b] = uVar5;
  if (*(char *)((longlong)param_1 + lVar9 * 0x220 + 0x1b88) != '\0') {
    FUN_1400205b0((char *)((longlong)param_1 + lVar9 * 0x220 + 0x1b68));
    EnterCriticalSection((LPCRITICAL_SECTION)((longlong)param_1 + 8));
    if (*(longlong *)((longlong)param_1 + lVar9 * 0x220 + 0x1d70) == 0) {
      uVar5 = pcap_open(*(undefined8 *)
                         (*(longlong *)((longlong)param_1 + lVar9 * 0x220 + 0x1d68) + 8),0xffff,0);
      *(undefined8 *)((longlong)param_1 + lVar9 * 0x220 + 0x1d70) = uVar5;
      *(undefined1 *)((longlong)param_1 + lVar9 * 0x220 + 0x1d80) = 1;
    }
    LeaveCriticalSection((LPCRITICAL_SECTION)((longlong)param_1 + 8));
    if (*(int *)((longlong)param_1 + 0x18ec) == 0) {
      pCVar6 = AfxBeginThread(FUN_140009be0,param_1,2,0,0,(_SECURITY_ATTRIBUTES *)0x0);
      *(CWinThread **)((longlong)param_1 + 0x1fa8) = pCVar6;
    }
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)param_4);
  return;
}

