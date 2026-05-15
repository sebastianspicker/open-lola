
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_140028af0(longlong param_1)

{
  longlong *plVar1;
  undefined8 uVar2;
  undefined8 *puVar3;
  int iVar4;
  undefined8 *puVar5;
  char *pcVar6;
  undefined8 *puVar7;
  undefined8 *puVar8;
  undefined8 *puVar9;
  longlong lVar10;
  uint uVar11;
  int iVar12;
  undefined8 *puVar13;
  longlong lVar14;
  undefined1 auStack_568 [32];
  undefined8 *local_548;
  LPARAM local_538;
  int local_530;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_528 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_520 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_518 [8];
  longlong *local_510;
  undefined8 *local_508;
  undefined8 local_500;
  undefined8 local_4f8 [60];
  undefined1 local_318 [480];
  undefined1 local_138 [256];
  ulonglong local_38;
  
  local_500 = 0xfffffffffffffffe;
  local_38 = DAT_1400630d8 ^ (ulonglong)auStack_568;
  iVar12 = 0;
  local_530 = 0;
  pcap_findalldevs(&local_510,local_138);
  puVar5 = operator_new(0x7800);
  puVar13 = puVar5;
  local_508 = puVar5;
  for (plVar1 = local_510; plVar1 != (longlong *)0x0; plVar1 = (longlong *)*plVar1) {
    pcVar6 = strstr((char *)plVar1[1],"Dialup");
    if ((pcVar6 == (char *)0x0) &&
       (pcVar6 = strstr((char *)plVar1[1],"NdisWan"), pcVar6 == (char *)0x0)) {
      puVar7 = (undefined8 *)FUN_140020660(local_318,(longlong)plVar1);
      lVar10 = 3;
      puVar3 = local_4f8;
      do {
        puVar9 = puVar3;
        puVar8 = puVar7;
        uVar2 = puVar8[1];
        *puVar9 = *puVar8;
        puVar9[1] = uVar2;
        uVar2 = puVar8[3];
        puVar9[2] = puVar8[2];
        puVar9[3] = uVar2;
        uVar2 = puVar8[5];
        puVar9[4] = puVar8[4];
        puVar9[5] = uVar2;
        uVar2 = puVar8[7];
        puVar9[6] = puVar8[6];
        puVar9[7] = uVar2;
        uVar2 = puVar8[9];
        puVar9[8] = puVar8[8];
        puVar9[9] = uVar2;
        uVar2 = puVar8[0xb];
        puVar9[10] = puVar8[10];
        puVar9[0xb] = uVar2;
        uVar2 = puVar8[0xd];
        puVar9[0xc] = puVar8[0xc];
        puVar9[0xd] = uVar2;
        uVar2 = puVar8[0xf];
        puVar9[0xe] = puVar8[0xe];
        puVar9[0xf] = uVar2;
        lVar10 = lVar10 + -1;
        puVar7 = puVar8 + 0x10;
        puVar3 = puVar9 + 0x10;
      } while (lVar10 != 0);
      uVar2 = puVar8[0x11];
      puVar9[0x10] = puVar8[0x10];
      puVar9[0x11] = uVar2;
      uVar2 = puVar8[0x13];
      puVar9[0x12] = puVar8[0x12];
      puVar9[0x13] = uVar2;
      uVar2 = puVar8[0x15];
      puVar9[0x14] = puVar8[0x14];
      puVar9[0x15] = uVar2;
      uVar2 = puVar8[0x17];
      puVar9[0x16] = puVar8[0x16];
      puVar9[0x17] = uVar2;
      uVar2 = puVar8[0x19];
      puVar9[0x18] = puVar8[0x18];
      puVar9[0x19] = uVar2;
      uVar2 = puVar8[0x1b];
      puVar9[0x1a] = puVar8[0x1a];
      puVar9[0x1b] = uVar2;
      lVar10 = 3;
      puVar7 = puVar13;
      puVar3 = local_4f8;
      do {
        puVar9 = puVar3;
        puVar8 = puVar7;
        uVar2 = puVar9[1];
        *puVar8 = *puVar9;
        puVar8[1] = uVar2;
        uVar2 = puVar9[3];
        puVar8[2] = puVar9[2];
        puVar8[3] = uVar2;
        uVar2 = puVar9[5];
        puVar8[4] = puVar9[4];
        puVar8[5] = uVar2;
        uVar2 = puVar9[7];
        puVar8[6] = puVar9[6];
        puVar8[7] = uVar2;
        uVar2 = puVar9[9];
        puVar8[8] = puVar9[8];
        puVar8[9] = uVar2;
        uVar2 = puVar9[0xb];
        puVar8[10] = puVar9[10];
        puVar8[0xb] = uVar2;
        uVar2 = puVar9[0xd];
        puVar8[0xc] = puVar9[0xc];
        puVar8[0xd] = uVar2;
        uVar2 = puVar9[0xf];
        puVar8[0xe] = puVar9[0xe];
        puVar8[0xf] = uVar2;
        lVar10 = lVar10 + -1;
        puVar7 = puVar8 + 0x10;
        puVar3 = puVar9 + 0x10;
      } while (lVar10 != 0);
      uVar2 = puVar9[0x11];
      puVar8[0x10] = puVar9[0x10];
      puVar8[0x11] = uVar2;
      uVar2 = puVar9[0x13];
      puVar8[0x12] = puVar9[0x12];
      puVar8[0x13] = uVar2;
      uVar2 = puVar9[0x15];
      puVar8[0x14] = puVar9[0x14];
      puVar8[0x15] = uVar2;
      uVar2 = puVar9[0x17];
      puVar8[0x16] = puVar9[0x16];
      puVar8[0x17] = uVar2;
      uVar2 = puVar9[0x19];
      puVar8[0x18] = puVar9[0x18];
      puVar8[0x19] = uVar2;
      uVar2 = puVar9[0x1b];
      puVar8[0x1a] = puVar9[0x1a];
      puVar8[0x1b] = uVar2;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_538,"");
      lVar10 = (longlong)iVar12;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_538,"%s",(longlong)puVar5 + lVar10 * 0x1e0 + 0x11c);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_518,"");
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                (local_518,"%s",puVar5 + lVar10 * 0x3c + 3);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_520,"");
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                (local_520,"%s",puVar5 + lVar10 * 0x3c + 0x34);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_528,"");
      local_548 = puVar5 + lVar10 * 0x3c + 0x38;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                (local_528,"GUID: %s\nIP: %s\nMask: %s",puVar5 + lVar10 * 0x3c + 3,
                 puVar5 + lVar10 * 0x3c + 0x34);
      lVar10 = lVar10 * 0x20;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (param_1 + 0x2b90 + lVar10),
                 (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_538);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (param_1 + 0x2b98 + lVar10),local_518);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (param_1 + 0x2ba0 + lVar10),local_528);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (param_1 + 0x2ba8 + lVar10),local_520);
      iVar12 = local_530 + 1;
      puVar13 = puVar13 + 0x3c;
      local_530 = iVar12;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_528);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_520);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_518);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_538);
      puVar5 = local_508;
    }
  }
  pcap_freealldevs(local_510);
  free(puVar5);
  uVar11 = 0;
  puVar5 = (undefined8 *)(param_1 + 0x5c0);
  puVar13 = puVar5;
  do {
    SendMessageA((HWND)*puVar13,0x143,0,0x14004c108);
    uVar11 = uVar11 + 1;
    puVar13 = puVar13 + 0x14f;
  } while (uVar11 < 2);
  lVar10 = (longlong)iVar12;
  if (0 < iVar12) {
    puVar13 = (undefined8 *)(param_1 + 0x2ba8);
    lVar14 = lVar10;
    do {
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_538,"");
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_538,"%s - %s",*puVar13,puVar13[-3]);
      uVar11 = 0;
      puVar7 = puVar5;
      do {
        SendMessageA((HWND)*puVar7,0x143,0,local_538);
        uVar11 = uVar11 + 1;
        puVar7 = puVar7 + 0x14f;
      } while (uVar11 < 2);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_538);
      puVar13 = puVar13 + 4;
      lVar14 = lVar14 + -1;
    } while (lVar14 != 0);
  }
  uVar11 = 0;
  do {
    SendMessageA((HWND)*puVar5,0x14e,0,0);
    FUN_14002a0a0(param_1,(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_538,uVar11);
    if (*(int *)(local_538 + -0x10) != 0) {
      iVar12 = 0;
      lVar14 = 0;
      if (0 < lVar10) {
        puVar13 = (undefined8 *)(param_1 + 0x2b98);
        do {
          iVar12 = iVar12 + 1;
          iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                  Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_538,(char *)*puVar13);
          if (iVar4 == 0) {
            SendMessageA((HWND)*puVar5,0x14e,(longlong)iVar12,0);
            FUN_14002cf20(param_1,uVar11);
            break;
          }
          lVar14 = lVar14 + 1;
          puVar13 = puVar13 + 4;
        } while (lVar14 < lVar10);
      }
    }
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_538);
    uVar11 = uVar11 + 1;
    puVar5 = puVar5 + 0x14f;
    if (1 < uVar11) {
      return;
    }
  } while( true );
}

