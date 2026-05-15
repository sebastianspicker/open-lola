
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_140016f20(void *param_1,longlong param_2,
                  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_3
                  ,undefined4 param_4)

{
  undefined4 uVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined8 *puVar4;
  int iVar5;
  errno_t eVar6;
  char *pcVar7;
  undefined8 *puVar8;
  undefined8 *puVar9;
  size_t sVar10;
  CWinThread *pCVar11;
  undefined8 uVar12;
  undefined8 *puVar13;
  longlong lVar14;
  longlong lVar15;
  undefined1 auStackY_628 [32];
  undefined8 local_5f8;
  undefined8 local_5f0;
  __time64_t local_5e8;
  undefined8 local_5e0;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_5d8;
  undefined1 local_5d0 [24];
  undefined8 local_5b8 [60];
  undefined1 local_3d8 [480];
  tm local_1f8;
  char local_1c8 [128];
  undefined1 local_148 [256];
  ulonglong local_48;
  
  local_5e0 = 0xfffffffffffffffe;
  local_48 = DAT_1400630d8 ^ (ulonglong)auStackY_628;
  local_5d8 = param_3;
  if (*(char *)((longlong)param_1 + 0x24c) != '\0') goto LAB_140017493;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ((longlong)param_1 + 0x48),param_3);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ((longlong)param_1 + 800),
             (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_2 + 8));
  *(longlong *)((longlong)param_1 + 0x328) = param_2;
  *(undefined4 *)((longlong)param_1 + 0x250) = param_4;
  *(undefined4 *)((longlong)param_1 + 0x2dc) = param_4;
  *(undefined8 *)((longlong)param_1 + 0x58) = 0;
  iVar5 = pcap_findalldevs((longlong)param_1 + 0x58,local_148);
  if (iVar5 == -1) goto LAB_140017493;
  if (*(int *)(*(longlong *)((longlong)param_1 + 800) + -0x10) != 0) {
    for (puVar8 = *(undefined8 **)((longlong)param_1 + 0x58); puVar8 != (undefined8 *)0x0;
        puVar8 = (undefined8 *)*puVar8) {
      pcVar7 = strstr((char *)puVar8[1],*(char **)((longlong)param_1 + 800));
      if (pcVar7 != (char *)0x0) {
        *(undefined8 **)((longlong)param_1 + 0x58) = puVar8;
        break;
      }
    }
  }
  puVar8 = (undefined8 *)FUN_140020660(local_3d8,*(longlong *)((longlong)param_1 + 0x58));
  lVar15 = 3;
  lVar14 = 3;
  puVar4 = local_5b8;
  do {
    puVar13 = puVar4;
    puVar9 = puVar8;
    uVar12 = puVar9[1];
    *puVar13 = *puVar9;
    puVar13[1] = uVar12;
    uVar12 = puVar9[3];
    puVar13[2] = puVar9[2];
    puVar13[3] = uVar12;
    uVar12 = puVar9[5];
    puVar13[4] = puVar9[4];
    puVar13[5] = uVar12;
    uVar12 = puVar9[7];
    puVar13[6] = puVar9[6];
    puVar13[7] = uVar12;
    uVar12 = puVar9[9];
    puVar13[8] = puVar9[8];
    puVar13[9] = uVar12;
    uVar12 = puVar9[0xb];
    puVar13[10] = puVar9[10];
    puVar13[0xb] = uVar12;
    uVar12 = puVar9[0xd];
    puVar13[0xc] = puVar9[0xc];
    puVar13[0xd] = uVar12;
    uVar12 = puVar9[0xf];
    puVar13[0xe] = puVar9[0xe];
    puVar13[0xf] = uVar12;
    lVar14 = lVar14 + -1;
    puVar8 = puVar9 + 0x10;
    puVar4 = puVar13 + 0x10;
  } while (lVar14 != 0);
  uVar12 = puVar9[0x11];
  puVar13[0x10] = puVar9[0x10];
  puVar13[0x11] = uVar12;
  uVar12 = puVar9[0x13];
  puVar13[0x12] = puVar9[0x12];
  puVar13[0x13] = uVar12;
  uVar12 = puVar9[0x15];
  puVar13[0x14] = puVar9[0x14];
  puVar13[0x15] = uVar12;
  uVar12 = puVar9[0x17];
  puVar13[0x16] = puVar9[0x16];
  puVar13[0x17] = uVar12;
  uVar12 = puVar9[0x19];
  puVar13[0x18] = puVar9[0x18];
  puVar13[0x19] = uVar12;
  uVar12 = puVar9[0x1b];
  puVar13[0x1a] = puVar9[0x1a];
  puVar13[0x1b] = uVar12;
  lVar14 = 3;
  puVar8 = (undefined8 *)((longlong)param_1 + 0x60);
  puVar4 = local_5b8;
  do {
    puVar13 = puVar4;
    puVar9 = puVar8;
    uVar12 = puVar13[1];
    *puVar9 = *puVar13;
    puVar9[1] = uVar12;
    uVar12 = puVar13[3];
    puVar9[2] = puVar13[2];
    puVar9[3] = uVar12;
    uVar12 = puVar13[5];
    puVar9[4] = puVar13[4];
    puVar9[5] = uVar12;
    uVar12 = puVar13[7];
    puVar9[6] = puVar13[6];
    puVar9[7] = uVar12;
    uVar12 = puVar13[9];
    puVar9[8] = puVar13[8];
    puVar9[9] = uVar12;
    uVar12 = puVar13[0xb];
    puVar9[10] = puVar13[10];
    puVar9[0xb] = uVar12;
    uVar12 = puVar13[0xd];
    puVar9[0xc] = puVar13[0xc];
    puVar9[0xd] = uVar12;
    uVar12 = puVar13[0xf];
    puVar9[0xe] = puVar13[0xe];
    puVar9[0xf] = uVar12;
    lVar14 = lVar14 + -1;
    puVar8 = puVar9 + 0x10;
    puVar4 = puVar13 + 0x10;
  } while (lVar14 != 0);
  uVar12 = puVar13[0x11];
  puVar9[0x10] = puVar13[0x10];
  puVar9[0x11] = uVar12;
  uVar12 = puVar13[0x13];
  puVar9[0x12] = puVar13[0x12];
  puVar9[0x13] = uVar12;
  uVar12 = puVar13[0x15];
  puVar9[0x14] = puVar13[0x14];
  puVar9[0x15] = uVar12;
  uVar12 = puVar13[0x17];
  puVar9[0x16] = puVar13[0x16];
  puVar9[0x17] = uVar12;
  uVar1 = *(undefined4 *)((longlong)puVar13 + 0xc4);
  uVar2 = *(undefined4 *)(puVar13 + 0x19);
  uVar3 = *(undefined4 *)((longlong)puVar13 + 0xcc);
  *(undefined4 *)(puVar9 + 0x18) = *(undefined4 *)(puVar13 + 0x18);
  *(undefined4 *)((longlong)puVar9 + 0xc4) = uVar1;
  *(undefined4 *)(puVar9 + 0x19) = uVar2;
  *(undefined4 *)((longlong)puVar9 + 0xcc) = uVar3;
  uVar1 = *(undefined4 *)((longlong)puVar13 + 0xd4);
  uVar2 = *(undefined4 *)(puVar13 + 0x1b);
  uVar3 = *(undefined4 *)((longlong)puVar13 + 0xdc);
  *(undefined4 *)(puVar9 + 0x1a) = *(undefined4 *)(puVar13 + 0x1a);
  *(undefined4 *)((longlong)puVar9 + 0xd4) = uVar1;
  *(undefined4 *)(puVar9 + 0x1b) = uVar2;
  *(undefined4 *)((longlong)puVar9 + 0xdc) = uVar3;
  if (*(char *)((longlong)param_1 + 0x60) == '\0') goto LAB_140017493;
  *(undefined8 *)((longlong)param_1 + 0x50) = 0;
  lVar14 = pcap_open(*(undefined8 *)(*(longlong *)((longlong)param_1 + 0x58) + 8),0x10000,8,500);
  *(longlong *)((longlong)param_1 + 0x50) = lVar14;
  if (lVar14 == 0) {
    pcap_freealldevs(*(undefined8 *)((longlong)param_1 + 0x58));
    goto LAB_140017493;
  }
  pcap_setmintocopy(lVar14,*(undefined4 *)(*(longlong *)((longlong)param_1 + 600) + 0x10c));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_5f8
             ,"ip and udp");
  if (*(int *)(*(longlong *)((longlong)param_1 + 600) + 0x118) != 0) {
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_5f8,"ip and src host %s and dst host %s and (udp port %d or udp port %d)",
               *(undefined8 *)((longlong)param_1 + 0x48),(longlong)param_1 + 0x200);
  }
  iVar5 = pcap_compile(*(undefined8 *)((longlong)param_1 + 0x50),local_5d0,local_5f8,1);
  if (iVar5 < 0) {
    uVar12 = *(undefined8 *)((longlong)param_1 + 0x58);
LAB_140017240:
    pcap_freealldevs(uVar12);
  }
  else {
    iVar5 = pcap_setfilter(*(undefined8 *)((longlong)param_1 + 0x50),local_5d0);
    if (iVar5 < 0) {
      pcap_freealldevs(*(longlong *)((longlong)param_1 + 0x58));
    }
    else {
      puVar8 = (undefined8 *)FUN_140020660(local_3d8,*(longlong *)((longlong)param_1 + 0x58));
      lVar14 = 3;
      puVar4 = local_5b8;
      do {
        puVar13 = puVar4;
        puVar9 = puVar8;
        uVar12 = puVar9[1];
        *puVar13 = *puVar9;
        puVar13[1] = uVar12;
        uVar12 = puVar9[3];
        puVar13[2] = puVar9[2];
        puVar13[3] = uVar12;
        uVar12 = puVar9[5];
        puVar13[4] = puVar9[4];
        puVar13[5] = uVar12;
        uVar12 = puVar9[7];
        puVar13[6] = puVar9[6];
        puVar13[7] = uVar12;
        uVar12 = puVar9[9];
        puVar13[8] = puVar9[8];
        puVar13[9] = uVar12;
        uVar12 = puVar9[0xb];
        puVar13[10] = puVar9[10];
        puVar13[0xb] = uVar12;
        uVar12 = puVar9[0xd];
        puVar13[0xc] = puVar9[0xc];
        puVar13[0xd] = uVar12;
        uVar12 = puVar9[0xf];
        puVar13[0xe] = puVar9[0xe];
        puVar13[0xf] = uVar12;
        lVar14 = lVar14 + -1;
        puVar8 = puVar9 + 0x10;
        puVar4 = puVar13 + 0x10;
      } while (lVar14 != 0);
      uVar12 = puVar9[0x11];
      puVar13[0x10] = puVar9[0x10];
      puVar13[0x11] = uVar12;
      uVar12 = puVar9[0x13];
      puVar13[0x12] = puVar9[0x12];
      puVar13[0x13] = uVar12;
      uVar12 = puVar9[0x15];
      puVar13[0x14] = puVar9[0x14];
      puVar13[0x15] = uVar12;
      uVar12 = puVar9[0x17];
      puVar13[0x16] = puVar9[0x16];
      puVar13[0x17] = uVar12;
      uVar12 = puVar9[0x19];
      puVar13[0x18] = puVar9[0x18];
      puVar13[0x19] = uVar12;
      uVar12 = puVar9[0x1b];
      puVar13[0x1a] = puVar9[0x1a];
      puVar13[0x1b] = uVar12;
      puVar8 = (undefined8 *)((longlong)param_1 + 0x60);
      puVar4 = local_5b8;
      do {
        puVar13 = puVar4;
        puVar9 = puVar8;
        uVar12 = puVar13[1];
        *puVar9 = *puVar13;
        puVar9[1] = uVar12;
        uVar12 = puVar13[3];
        puVar9[2] = puVar13[2];
        puVar9[3] = uVar12;
        uVar12 = puVar13[5];
        puVar9[4] = puVar13[4];
        puVar9[5] = uVar12;
        uVar12 = puVar13[7];
        puVar9[6] = puVar13[6];
        puVar9[7] = uVar12;
        uVar12 = puVar13[9];
        puVar9[8] = puVar13[8];
        puVar9[9] = uVar12;
        uVar12 = puVar13[0xb];
        puVar9[10] = puVar13[10];
        puVar9[0xb] = uVar12;
        uVar12 = puVar13[0xd];
        puVar9[0xc] = puVar13[0xc];
        puVar9[0xd] = uVar12;
        uVar12 = puVar13[0xf];
        puVar9[0xe] = puVar13[0xe];
        puVar9[0xf] = uVar12;
        lVar15 = lVar15 + -1;
        puVar8 = puVar9 + 0x10;
        puVar4 = puVar13 + 0x10;
      } while (lVar15 != 0);
      uVar12 = puVar13[0x11];
      puVar9[0x10] = puVar13[0x10];
      puVar9[0x11] = uVar12;
      uVar12 = puVar13[0x13];
      puVar9[0x12] = puVar13[0x12];
      puVar9[0x13] = uVar12;
      uVar12 = puVar13[0x15];
      puVar9[0x14] = puVar13[0x14];
      puVar9[0x15] = uVar12;
      uVar12 = puVar13[0x17];
      puVar9[0x16] = puVar13[0x16];
      puVar9[0x17] = uVar12;
      uVar1 = *(undefined4 *)((longlong)puVar13 + 0xc4);
      uVar2 = *(undefined4 *)(puVar13 + 0x19);
      uVar3 = *(undefined4 *)((longlong)puVar13 + 0xcc);
      *(undefined4 *)(puVar9 + 0x18) = *(undefined4 *)(puVar13 + 0x18);
      *(undefined4 *)((longlong)puVar9 + 0xc4) = uVar1;
      *(undefined4 *)(puVar9 + 0x19) = uVar2;
      *(undefined4 *)((longlong)puVar9 + 0xcc) = uVar3;
      uVar1 = *(undefined4 *)((longlong)puVar13 + 0xd4);
      uVar2 = *(undefined4 *)(puVar13 + 0x1b);
      uVar3 = *(undefined4 *)((longlong)puVar13 + 0xdc);
      *(undefined4 *)(puVar9 + 0x1a) = *(undefined4 *)(puVar13 + 0x1a);
      *(undefined4 *)((longlong)puVar9 + 0xd4) = uVar1;
      *(undefined4 *)(puVar9 + 0x1b) = uVar2;
      *(undefined4 *)((longlong)puVar9 + 0xdc) = uVar3;
      uVar12 = *(undefined8 *)((longlong)param_1 + 0x58);
      if (*(char *)((longlong)param_1 + 0x60) == '\0') goto LAB_140017240;
      pcap_freealldevs();
      *(undefined8 *)((longlong)param_1 + 0x274) = 0;
      *(undefined4 *)((longlong)param_1 + 0x27c) = 0;
      *(undefined8 *)((longlong)param_1 + 0x28c) = 0;
      *(undefined8 *)((longlong)param_1 + 0x294) = 0;
      *(undefined4 *)((longlong)param_1 + 0x270) = 0;
      *(undefined4 *)((longlong)param_1 + 0x288) = 0;
      local_5e8 = _time64((__time64_t *)0x0);
      eVar6 = _localtime64_s(&local_1f8,&local_5e8);
      if (eVar6 != 0) {
                    /* WARNING: Subroutine does not return */
        FUN_140015270(-0x7ff8ffa9);
      }
      sVar10 = strftime(local_1c8,0x80,"%H:%M:%S",&local_1f8);
      if (sVar10 == 0) {
        local_1c8[0] = '\0';
      }
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_5f0,local_1c8);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 ((longlong)param_1 + 0x2f0),"%s",local_5f0);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_5f0);
      pCVar11 = AfxBeginThread(FUN_1400160c0,param_1,2,0,0,(_SECURITY_ATTRIBUTES *)0x0);
      *(CWinThread **)((longlong)param_1 + 0x310) = pCVar11;
    }
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_5f8
            );
LAB_140017493:
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_3);
  return;
}

