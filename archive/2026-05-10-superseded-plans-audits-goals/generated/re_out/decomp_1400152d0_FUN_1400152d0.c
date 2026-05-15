
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_1400152d0(longlong param_1)

{
  char cVar1;
  bool bVar2;
  bool bVar3;
  bool bVar4;
  bool bVar5;
  u_short uVar6;
  u_short uVar7;
  int iVar8;
  undefined4 uVar9;
  int iVar10;
  BOOL BVar11;
  undefined8 *puVar12;
  undefined8 *puVar13;
  undefined8 *_Memory;
  longlong lVar14;
  void *pvVar15;
  void *_Src;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar16;
  IAtlStringMgr *pIVar17;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar18;
  longlong lVar19;
  uint uVar20;
  ulonglong _Size;
  ulonglong uVar21;
  undefined8 *puVar22;
  byte *pbVar23;
  undefined1 auStackY_458 [32];
  uint local_424;
  int local_420;
  uint local_41c;
  int local_418;
  uint local_414;
  undefined4 local_410;
  int local_40c;
  int local_408;
  uint local_404;
  undefined4 local_400;
  uint local_3fc;
  int local_3f8;
  undefined4 local_3f4;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_3f0 [8];
  undefined8 local_3e8 [3];
  undefined4 local_3d0 [2];
  undefined8 local_3c8;
  longlong local_3c0;
  void *local_3b8;
  undefined8 *local_3b0;
  char *local_3a8;
  undefined8 *local_3a0;
  undefined8 local_398;
  undefined8 local_390;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_388 [8];
  undefined1 local_380 [8];
  longlong local_378;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_370 [8];
  undefined8 *local_368;
  undefined8 local_360;
  undefined1 local_358 [16];
  undefined8 local_348;
  longlong local_340;
  int local_2d4;
  uint local_2d0;
  int local_2c8;
  uint local_2b0;
  undefined1 local_e8 [176];
  ulonglong local_38;
  
  local_360 = 0xfffffffffffffffe;
  local_38 = DAT_1400630d8 ^ (ulonglong)auStackY_458;
  puVar22 = (undefined8 *)0x0;
  local_41c = 0;
  local_418 = 0;
  local_414 = 0;
  local_3a0 = operator_new(0x48);
  puVar12 = puVar22;
  if (local_3a0 != (undefined8 *)0x0) {
    puVar12 = FUN_140006bd0(local_3a0);
  }
  local_3b0 = puVar12;
  local_3a0 = operator_new(0x48);
  puVar13 = puVar22;
  if (local_3a0 != (undefined8 *)0x0) {
    puVar13 = FUN_140006bd0(local_3a0);
  }
  FUN_1400049f0(local_3e8);
  bVar4 = false;
  *(undefined1 *)(param_1 + 0x24c) = 1;
  ResetEvent(*(HANDLE *)(param_1 + 0x318));
  local_3a0 = (undefined8 *)pcap_sendqueue_alloc(100000);
  _Memory = operator_new(0x10);
  _Memory[1] = 0;
  *_Memory = 0;
  bVar3 = true;
  bVar5 = true;
  local_420 = 0;
  local_40c = 0;
  local_408 = 0;
  local_3d0[0] = 0;
  local_3f8 = 0;
  local_368 = _Memory;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_3f0);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_3a8
             ,"Jpeg decoding (CPU): ");
  local_3b8 = operator_new((longlong)
                           (((int)(*(int *)(param_1 + 0x2c0) +
                                  (*(int *)(param_1 + 0x2c0) >> 0x1f & 7U)) >> 3) *
                            *(int *)(param_1 + 0x2c8) * *(int *)(param_1 + 0x2c4)));
  cVar1 = *(char *)(param_1 + 0x24c);
  while (cVar1 != '\0') {
    iVar10 = (int)puVar22;
    iVar8 = pcap_next_ex(*(undefined8 *)(param_1 + 0x50),local_358,&local_378);
    lVar14 = local_378;
    puVar12 = local_3b0;
    _Memory = local_368;
    if (iVar8 < 0) break;
    if (iVar8 == 0) goto LAB_140015fb9;
    pbVar23 = (byte *)(local_378 + 0xe);
    lVar19 = (ulonglong)(*pbVar23 & 0xf) * 4;
    ntohs(*(u_short *)(pbVar23 + lVar19));
    uVar6 = ntohs(*(u_short *)(pbVar23 + lVar19 + 2));
    uVar7 = ntohs(*(u_short *)(pbVar23 + lVar19 + 4));
    uVar21 = (ulonglong)(*(uint *)(lVar14 + 0x1a) >> 8 & 0xff);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
              (local_3f0,"%d.%d.%d.%d",(ulonglong)(*(uint *)(lVar14 + 0x1a) & 0xff));
    pbVar23 = pbVar23 + lVar19 + 8;
    if (((uint)uVar6 == *(uint *)(*(longlong *)(param_1 + 600) + 0x100)) &&
       (iVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                Compare(local_3f0,*(char **)(param_1 + 0x48)), puVar12 = local_3b0, iVar8 == 0)) {
      uVar21 = 1;
      FUN_140006f00((longlong)local_3b0,*(undefined4 *)(pbVar23 + 0xc),
                    *(int *)(param_1 + 0x2b0) * 0x80 + 8,1);
      FUN_140007200((longlong)puVar12,(longlong)pbVar23);
      local_398 = 0;
      local_410 = 0;
      FUN_140006e90((longlong)puVar12,&local_398,&local_410);
      FUN_140004dd0((longlong)local_3e8,local_398,local_410);
      FUN_140004d60((longlong)local_3e8,&local_40c,1);
      if ((!bVar3) && (local_40c - local_408 != 1)) {
        *(int *)(param_1 + 0x278) = *(int *)(param_1 + 0x278) + 1;
      }
      local_408 = local_40c;
      FUN_140004d60((longlong)local_3e8,&local_404,1);
      if ((local_404 != 0) &&
         (lVar14 = *(longlong *)(param_1 + 0x330), local_404 <= *(uint *)(lVar14 + 0xc18))) {
        if (-1 < *(int *)(lVar14 + 0x1280 + (longlong)*(int *)(param_1 + 0x348) * 4)) {
          lVar19 = *(longlong *)(param_1 + 0x330);
          if (bVar3) {
            iVar8 = *(int *)(param_1 + 0x348);
LAB_140015659:
            bVar3 = false;
            *(int *)((longlong)*(int *)(param_1 + 0x348) * 0x330 + 0xf40 +
                    *(longlong *)(param_1 + 0x330)) =
                 (*(int *)((longlong)iVar8 * 0x330 + 0xf44 + lVar19) +
                 *(int *)(*(longlong *)(param_1 + 0x330) + 0x1280 +
                         (longlong)*(int *)(param_1 + 0x348) * 4)) % 100;
            iVar8 = *(int *)(param_1 + 0x348);
            lVar19 = *(longlong *)(param_1 + 0x330);
          }
          else {
            iVar8 = *(int *)(param_1 + 0x348);
            if (*(int *)(lVar19 + 0x1280 + (longlong)iVar8 * 4) + 2 <
                (*(int *)((longlong)*(int *)(param_1 + 0x348) * 0x330 + 0xf40 +
                         *(longlong *)(param_1 + 0x330)) +
                (100 - *(int *)((longlong)*(int *)(param_1 + 0x348) * 0x330 + 0xf44 + lVar14))) %
                100) {
              *(int *)(param_1 + 0x27c) = *(int *)(param_1 + 0x27c) + 1;
              goto LAB_140015659;
            }
          }
          uVar21 = (longlong)*(int *)(param_1 + 0x348) * 0x66 +
                   (longlong)*(int *)((longlong)iVar8 * 0x330 + 0xf40 + lVar19);
          FUN_140004c40((longlong)local_3e8,
                        *(void **)(*(longlong *)(param_1 + 0x330) + 0xc20 + uVar21 * 8),local_404);
          *(int *)((longlong)*(int *)(param_1 + 0x348) * 0x330 + 0xf40 +
                  *(longlong *)(param_1 + 0x330)) =
               (*(int *)((longlong)*(int *)(param_1 + 0x348) * 0x330 + 0xf40 +
                        *(longlong *)(param_1 + 0x330)) + 1) % 100;
        }
        uVar9 = FUN_140006e80((longlong)puVar12);
        if ((char)uVar9 != '\0') {
          *(int *)(param_1 + 0x270) = *(int *)(param_1 + 0x270) + 1;
          goto LAB_140015768;
        }
      }
      *(int *)(param_1 + 0x274) = *(int *)(param_1 + 0x274) + 1;
    }
LAB_140015768:
    if ((((uint)uVar6 == *(uint *)(*(longlong *)(param_1 + 600) + 0xfc)) &&
        (iVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 Compare(local_3f0,*(char **)(param_1 + 0x48)), iVar8 == 0)) &&
       (*(int *)(param_1 + 0x250) == 0)) {
      if (!bVar4) {
        if (((*(int *)pbVar23 == -0x2020203) && (*(int *)(pbVar23 + 4) == -0x20202021)) &&
           (*(int *)(pbVar23 + 8) == -0x55555556)) {
          bVar2 = true;
        }
        else {
          bVar2 = false;
        }
        if ((uVar7 == 0x48) && (bVar2)) {
          iVar10 = *(int *)(pbVar23 + 0x10);
          local_414 = *(uint *)(pbVar23 + 0x1c);
          uVar21 = (ulonglong)local_414;
          local_418 = iVar10;
          FUN_140006f00((longlong)puVar13,iVar10,*(uint *)(pbVar23 + 0x14),local_414);
          if ((!bVar5) && (iVar10 - local_3f8 != 1)) {
            *(int *)(param_1 + 0x290) = *(int *)(param_1 + 0x290) + 1;
          }
          bVar5 = false;
          puVar22 = (undefined8 *)0x0;
          bVar4 = true;
          local_3f8 = iVar10;
        }
        goto LAB_1400158ea;
      }
      FUN_140007200((longlong)puVar13,(longlong)pbVar23);
      if (local_418 != *(int *)(pbVar23 + 0xc)) {
        *(int *)(param_1 + 0x294) = *(int *)(param_1 + 0x294) + 1;
      }
      if (iVar10 != *(int *)(pbVar23 + 0x14)) {
        *(int *)(param_1 + 0x298) = *(int *)(param_1 + 0x298) + 1;
        iVar10 = *(int *)(pbVar23 + 0x14);
      }
      puVar22 = (undefined8 *)(ulonglong)(iVar10 + 1);
      uVar9 = FUN_140006e80((longlong)puVar13);
      if ((char)uVar9 == '\0') {
        if (pbVar23[0x20] != 0) {
          if ((*(int *)(*(longlong *)(param_1 + 600) + 0xa8) != 0) &&
             (iVar10 = FUN_140006ed0((longlong)puVar13),
             100U - *(int *)(*(longlong *)(param_1 + 600) + 0xa8) <=
             (uint)(iVar10 * 100) / local_414)) goto LAB_140015831;
          *(int *)(param_1 + 0x28c) = *(int *)(param_1 + 0x28c) + 1;
          puVar22 = (undefined8 *)0x0;
          bVar4 = false;
        }
      }
      else {
LAB_140015831:
        bVar4 = false;
        local_390 = 0;
        local_400 = 0;
        FUN_140006e90((longlong)puVar13,&local_390,&local_400);
        FUN_140004dd0((longlong)local_3e8,local_390,local_400);
        FUN_140004d60((longlong)local_3e8,local_3d0,1);
        FUN_140004d60((longlong)local_3e8,&local_3fc,1);
        if (*(int *)(param_1 + 0x398) == 0) {
          if (((local_3fc == 0) || (*(uint *)(*(longlong *)(param_1 + 0x340) + 0x78) < local_3fc))
             && (local_420 == 0)) {
            *(int *)(param_1 + 0x28c) = *(int *)(param_1 + 0x28c) + 1;
          }
          else {
            lVar14 = *(longlong *)(param_1 + 0x340);
            if (local_420 == 0) {
              pvVar15 = *(void **)(*(longlong *)(lVar14 + 0x90) +
                                  (longlong)*(int *)(lVar14 + 0x98) * 8);
            }
            else {
              pvVar15 = *(void **)(lVar14 + 0x1e0);
            }
            FUN_140004c40((longlong)local_3e8,pvVar15,local_3fc);
            *(undefined4 *)(*(longlong *)(param_1 + 0x340) + 0x9c) =
                 *(undefined4 *)(*(longlong *)(param_1 + 0x340) + 0x98);
            lVar14 = *(longlong *)(param_1 + 0x340);
            uVar20 = *(uint *)(lVar14 + 0x1a0);
            if (1 < *(uint *)(lVar14 + 0x1a0)) {
              uVar20 = 1;
            }
            *(uint *)(lVar14 + 0x98) = (*(int *)(lVar14 + 0x98) + uVar20) % *(uint *)(lVar14 + 0x84)
            ;
            lVar14 = *(longlong *)(param_1 + 0x340);
            iVar10 = *(int *)(lVar14 + 0xa4) + 1;
            if (*(int *)(lVar14 + 0x84) <= iVar10) {
              iVar10 = *(int *)(lVar14 + 0x84);
            }
            *(int *)(lVar14 + 0xa4) = iVar10;
            SetEvent(*(HANDLE *)(*(longlong *)(param_1 + 0x340) + 8));
            if (*(int *)(param_1 + 0x380) != 0) {
              *(undefined8 *)(param_1 + 0x388) =
                   *(undefined8 *)
                    (*(longlong *)(*(longlong *)(param_1 + 0x340) + 0x90) +
                    (longlong)*(int *)(*(longlong *)(param_1 + 0x340) + 0x98) * 8);
              *(uint *)(param_1 + 0x390) = local_3fc;
              SetEvent(*(HANDLE *)(param_1 + 0x370));
            }
          }
          *(int *)(param_1 + 0x288) = *(int *)(param_1 + 0x288) + 1;
          goto LAB_1400158ea;
        }
        local_420 = *(int *)(param_1 + 0x394);
        *(undefined4 *)(param_1 + 0x398) = 0;
        *(int *)(param_1 + 0x288) = *(int *)(param_1 + 0x288) + 1;
      }
    }
    else {
LAB_1400158ea:
      if ((((uint)uVar6 == *(uint *)(*(longlong *)(param_1 + 600) + 0xfc)) &&
          (iVar10 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                    Compare(local_3f0,*(char **)(param_1 + 0x48)), iVar10 == 0)) &&
         (*(int *)(param_1 + 0x250) == 1)) {
        if (bVar4) {
          FUN_140007200((longlong)puVar13,(longlong)pbVar23);
          uVar9 = FUN_140006e80((longlong)puVar13);
          if ((char)uVar9 == '\0') {
            if (pbVar23[0x20] != 0) {
              *(int *)(param_1 + 0x28c) = *(int *)(param_1 + 0x28c) + 1;
              puVar22 = (undefined8 *)0x0;
              bVar4 = false;
            }
          }
          else {
            local_3c8 = 0;
            local_3f4 = 0;
            FUN_140006e90((longlong)puVar13,&local_3c8,&local_3f4);
            FUN_140004dd0((longlong)local_3e8,local_3c8,local_3f4);
            FUN_140004d60((longlong)local_3e8,local_380,1);
            FUN_140004d60((longlong)local_3e8,&local_424,1);
            if ((local_424 == 0) ||
               (lVar14 = *(longlong *)(param_1 + 0x340), *(uint *)(lVar14 + 0x78) < local_424)) {
              *(int *)(param_1 + 0x28c) = *(int *)(param_1 + 0x28c) + 1;
              *(int *)(param_1 + 0x288) = *(int *)(param_1 + 0x288) + 1;
              bVar4 = false;
            }
            else {
              if (*(int *)(param_1 + 0x380) != 0) {
                *(undefined8 *)(param_1 + 0x388) = local_3c8;
                *(uint *)(param_1 + 0x390) = local_424;
                SetEvent(*(HANDLE *)(param_1 + 0x370));
                lVar14 = *(longlong *)(param_1 + 0x340);
              }
              if (*(int *)(*(longlong *)(lVar14 + 0x1c8) + 0x2c8) != 0) {
                FUN_140020e20(param_1 + 0x350);
              }
              if (*(int *)(*(longlong *)(param_1 + 600) + 0xa0) == 0) {
                _Src = operator_new((ulonglong)local_424);
                FUN_140004c40((longlong)local_3e8,_Src,local_424);
                pvVar15 = local_3b8;
                uVar20 = local_424;
                if (*(int *)(param_1 + 0x380) != 0) {
                  memcpy(local_3b8,_Src,(ulonglong)local_424);
                  *(void **)(param_1 + 0x388) = pvVar15;
                  *(uint *)(param_1 + 0x390) = uVar20;
                  SetEvent(*(HANDLE *)(param_1 + 0x370));
                }
                local_348 = jpeg_std_error(local_e8);
                jpeg_CreateDecompress(&local_348,0x3e,600);
                jpeg_mem_src(&local_348,_Src,local_424);
                jpeg_read_header(&local_348,1);
                jpeg_start_decompress(&local_348);
                uVar20 = local_2c8 * local_2d4;
                uVar21 = 1;
                _Size = (ulonglong)uVar20;
                (**(code **)(local_340 + 0x10))(&local_348);
                EnterCriticalSection((LPCRITICAL_SECTION)(*(longlong *)(param_1 + 0x340) + 0x18));
                local_3c0 = *(longlong *)
                             (*(longlong *)(*(longlong *)(param_1 + 0x340) + 0x90) +
                             (longlong)*(int *)(*(longlong *)(param_1 + 0x340) + 0x98) * 8);
                if (local_2b0 < local_2d0) {
                  do {
                    _Size = 1;
                    jpeg_read_scanlines(&local_348);
                    local_3c0 = local_3c0 + (int)uVar20;
                  } while (local_2b0 < local_2d0);
                }
                jpeg_finish_decompress(&local_348);
                jpeg_destroy_decompress(&local_348);
                free(_Src);
              }
              else {
                BVar11 = TryEnterCriticalSection
                                   ((LPCRITICAL_SECTION)(*(longlong *)(param_1 + 0x340) + 0x18));
                lVar14 = *(longlong *)(param_1 + 0x340);
                if (BVar11 == 0) {
                  *(undefined4 *)(lVar14 + 0x9c) = *(undefined4 *)(lVar14 + 0x98);
                  lVar14 = *(longlong *)(param_1 + 0x340);
                  uVar20 = *(uint *)(lVar14 + 0x1a0);
                  if (1 < *(uint *)(lVar14 + 0x1a0)) {
                    uVar20 = 1;
                  }
                  *(uint *)(lVar14 + 0x98) =
                       (*(int *)(lVar14 + 0x98) + uVar20) % *(uint *)(lVar14 + 0x84);
                  lVar14 = *(longlong *)(param_1 + 0x340);
                  iVar10 = *(int *)(lVar14 + 0xa4) + 1;
                  if (*(int *)(lVar14 + 0x84) <= iVar10) {
                    iVar10 = *(int *)(lVar14 + 0x84);
                  }
                  *(int *)(lVar14 + 0xa4) = iVar10;
                  *(int *)(param_1 + 0x288) = *(int *)(param_1 + 0x288) + 1;
                  bVar4 = false;
                  goto LAB_140015fb9;
                }
                if (*(void **)(lVar14 + 0x1f8) != (void *)0x0) {
                  free(*(void **)(lVar14 + 0x1f8));
                  *(undefined8 *)(*(longlong *)(param_1 + 0x340) + 0x1f8) = 0;
                }
                pvVar15 = operator_new((ulonglong)local_424);
                *(void **)(*(longlong *)(param_1 + 0x340) + 0x1f8) = pvVar15;
                *(uint *)(*(longlong *)(param_1 + 0x340) + 500) = local_424;
                _Size = (ulonglong)local_424;
                FUN_140004c40((longlong)local_3e8,*(void **)(*(longlong *)(param_1 + 0x340) + 0x1f8)
                              ,local_424);
                pvVar15 = local_3b8;
                uVar20 = local_424;
                if (*(int *)(param_1 + 0x380) != 0) {
                  _Size = (ulonglong)local_424;
                  memcpy(local_3b8,*(void **)(*(longlong *)(param_1 + 0x340) + 0x1f8),_Size);
                  *(void **)(param_1 + 0x388) = pvVar15;
                  *(uint *)(param_1 + 0x390) = uVar20;
                  SetEvent(*(HANDLE *)(param_1 + 0x370));
                }
              }
              lVar14 = *(longlong *)(param_1 + 0x340);
              if (*(int *)(*(longlong *)(lVar14 + 0x1c8) + 0x2c8) != 0) {
                pCVar16 = FUN_140020e30(param_1 + 0x350,local_370,_Size,uVar21);
                pIVar17 = ATL::
                          CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          ::GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                        *)&local_3a8);
                pCVar18 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)ATL::
                             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             ::
                             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                       (local_388,pIVar17);
                uVar20 = local_41c;
                local_41c = local_41c | 1;
                ATL::CSimpleStringT<char,1>::Concatenate
                          ((CSimpleStringT<char,1> *)local_388,local_3a8,*(int *)(local_3a8 + -0x10)
                           ,*(char **)pCVar16,*(int *)(*(char **)pCVar16 + -0x10));
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                operator=((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)(*(longlong *)(*(longlong *)(param_1 + 0x340) + 0x1c8) + 0x350),pCVar18
                         );
                local_41c = uVar20 & 0xfffffffe;
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          (local_388);
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          (local_370);
                lVar14 = *(longlong *)(param_1 + 0x340);
              }
              *(undefined4 *)(lVar14 + 0x9c) = *(undefined4 *)(lVar14 + 0x98);
              lVar14 = *(longlong *)(param_1 + 0x340);
              uVar20 = *(uint *)(lVar14 + 0x1a0);
              if (1 < *(uint *)(lVar14 + 0x1a0)) {
                uVar20 = 1;
              }
              *(uint *)(lVar14 + 0x98) =
                   (*(int *)(lVar14 + 0x98) + uVar20) % *(uint *)(lVar14 + 0x84);
              lVar14 = *(longlong *)(param_1 + 0x340);
              iVar10 = *(int *)(lVar14 + 0xa4) + 1;
              if (*(int *)(lVar14 + 0x84) <= iVar10) {
                iVar10 = *(int *)(lVar14 + 0x84);
              }
              *(int *)(lVar14 + 0xa4) = iVar10;
              LeaveCriticalSection((LPCRITICAL_SECTION)(*(longlong *)(param_1 + 0x340) + 0x18));
              SetEvent(*(HANDLE *)(*(longlong *)(param_1 + 0x340) + 8));
              *(int *)(param_1 + 0x288) = *(int *)(param_1 + 0x288) + 1;
              bVar4 = false;
            }
          }
        }
        else {
          if (((*(int *)pbVar23 == -0x2020203) && (*(int *)(pbVar23 + 4) == -0x20202021)) &&
             (*(int *)(pbVar23 + 8) == -0x55555556)) {
            bVar2 = true;
          }
          else {
            bVar2 = false;
          }
          if ((uVar7 == 0x48) && (bVar2)) {
            local_418 = *(int *)(pbVar23 + 0x10);
            local_414 = *(uint *)(pbVar23 + 0x1c);
            FUN_140006f00((longlong)puVar13,local_418,*(uint *)(pbVar23 + 0x14),local_414);
            bVar4 = true;
          }
        }
      }
    }
LAB_140015fb9:
    _Memory = local_368;
    puVar12 = local_3b0;
    cVar1 = *(char *)(param_1 + 0x24c);
  }
  pvVar15 = local_3b8;
  *(undefined1 *)(param_1 + 0x24d) = 0;
  if (puVar12 != (undefined8 *)0x0) {
    (**(code **)*puVar12)(puVar12,1);
  }
  if (puVar13 != (undefined8 *)0x0) {
    (**(code **)*puVar13)(puVar13,1);
  }
  free(_Memory);
  if (pvVar15 != (void *)0x0) {
    free(pvVar15);
  }
  if (local_3a0 != (undefined8 *)0x0) {
    pcap_sendqueue_destroy(local_3a0);
  }
  if (*(longlong *)(param_1 + 0x50) != 0) {
    pcap_close();
    *(undefined8 *)(param_1 + 0x50) = 0;
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x48),"");
  SetEvent(*(HANDLE *)(param_1 + 0x318));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_3a8
            );
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_3f0);
  FUN_140004a30(local_3e8);
  return;
}

