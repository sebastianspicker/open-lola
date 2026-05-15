
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_1400093a0(longlong param_1,
                  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_2
                  ,CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                   *param_3,uint param_4,int param_5)

{
  undefined1 auVar1 [16];
  undefined1 auVar2 [16];
  undefined1 auVar3 [16];
  ushort uVar4;
  int iVar5;
  int iVar6;
  int iVar7;
  int iVar8;
  uint uVar9;
  int iVar10;
  __uint64 _Var11;
  longlong lVar12;
  undefined4 *puVar13;
  undefined8 uVar14;
  void *pvVar15;
  __uint64 _Var16;
  int iVar17;
  longlong lVar18;
  undefined8 *puVar19;
  int iVar20;
  LPCSTR pCVar21;
  int *piVar22;
  undefined8 *puVar23;
  undefined4 *_Memory;
  LPCSTR pCVar24;
  ulonglong uVar25;
  longlong lVar26;
  LPCSTR local_res8;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_res10;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_res18;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_98 [8];
  longlong local_90;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_88;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_80;
  undefined8 *local_78;
  undefined4 local_70;
  undefined4 local_6c;
  undefined4 local_68;
  undefined4 local_64;
  undefined4 *local_60;
  undefined8 local_58;
  
  local_58 = 0xfffffffffffffffe;
  uVar25 = (ulonglong)(int)param_4;
  piVar22 = (int *)(param_1 + 0x50);
  piVar22[0] = 0;
  piVar22[1] = 0;
  *(undefined8 *)(param_1 + 0x58) = 0;
  *(undefined8 *)(param_1 + 0x60) = 0;
  *(undefined8 *)(param_1 + 0x68) = 0;
  *(undefined8 *)(param_1 + 0x70) = 0;
  *(undefined8 *)(param_1 + 0x78) = 0;
  *(undefined8 *)(param_1 + 0x80) = 0;
  *(undefined8 *)(param_1 + 0x88) = 0;
  local_res10 = param_2;
  local_res18 = param_3;
  local_88 = param_2;
  local_80 = param_3;
  Pa_IsStreamActive(*(undefined8 *)(param_1 + 0x90));
  if (*(int *)(param_1 + 0xa0) != 0) {
    Pa_CloseStream(*(undefined8 *)(param_1 + 0x90));
    *(undefined4 *)(param_1 + 0xa0) = 0;
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_98,param_2);
  iVar8 = -1;
  iVar20 = 0;
  if (0 < *(int *)(param_1 + 0xbc)) {
    puVar19 = (undefined8 *)(param_1 + 200);
    do {
      param_2 = local_88;
      if (iVar8 == 0) break;
      iVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
              Compare(local_98,(char *)*puVar19);
      iVar20 = iVar20 + 1;
      puVar19 = puVar19 + 1;
      param_2 = local_88;
    } while (iVar20 < *(int *)(param_1 + 0xbc));
  }
  iVar8 = Pa_HostApiDeviceIndexToDeviceIndex(*(undefined4 *)(param_1 + 0xb8),iVar20 + -1);
  local_90 = CONCAT44(local_90._4_4_,iVar8);
  Pa_GetDeviceInfo(iVar8);
  *piVar22 = iVar8;
  if (iVar8 == -1) {
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_98);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_2);
  }
  else {
    *(uint *)(param_1 + 0x54) = param_4;
    *(undefined4 *)(param_1 + 0x58) = 8;
    *(undefined8 *)(param_1 + 0x60) = 0x3f40624dd2f1a9fc;
    puVar13 = (undefined4 *)0x0;
    iVar20 = 0;
    _Memory = puVar13;
    if (0 < param_5) {
      auVar1._8_8_ = 0;
      auVar1._0_8_ = uVar25;
      _Var11 = SUB168(ZEXT816(4) * auVar1,0);
      if (SUB168(ZEXT816(4) * auVar1,8) != 0) {
        _Var11 = 0xffffffffffffffff;
      }
      local_60 = operator_new(_Var11);
      iVar7 = _UNK_1400441bc;
      iVar6 = _UNK_1400441b8;
      iVar5 = _UNK_1400441b4;
      iVar17 = _DAT_1400441b0;
      local_70 = 0x18;
      local_6c = 3;
      local_68 = 1;
      local_64 = 1;
      if ((0 < (int)param_4) && (0xf < param_4)) {
        uVar9 = param_4 & 0x8000000f;
        if ((int)uVar9 < 0) {
          uVar9 = (uVar9 - 1 | 0xfffffff0) + 1;
        }
        iVar8 = 8;
        piVar22 = local_60 + 8;
        do {
          piVar22[-8] = iVar20 + param_5 + iVar17;
          piVar22[-7] = iVar20 + param_5 + iVar5;
          piVar22[-6] = iVar20 + param_5 + iVar6;
          piVar22[-5] = iVar20 + param_5 + iVar7;
          iVar10 = iVar8 + -4;
          piVar22[-4] = iVar10 + param_5 + iVar17;
          piVar22[-3] = iVar10 + param_5 + iVar5;
          piVar22[-2] = iVar10 + param_5 + iVar6;
          piVar22[-1] = iVar10 + param_5 + iVar7;
          *piVar22 = iVar8 + param_5 + iVar17;
          piVar22[1] = iVar8 + param_5 + iVar5;
          piVar22[2] = iVar8 + param_5 + iVar6;
          piVar22[3] = iVar8 + param_5 + iVar7;
          *(ulonglong *)(piVar22 + 4) = CONCAT44(iVar8 + param_5 + 5,param_5 + 4 + iVar8);
          *(ulonglong *)(piVar22 + 6) = CONCAT44(iVar8 + param_5 + 7,param_5 + 6 + iVar8);
          iVar20 = iVar20 + 0x10;
          iVar8 = iVar8 + 0x10;
          piVar22 = piVar22 + 0x10;
        } while (iVar20 < (int)(param_4 - uVar9));
        iVar8 = (int)local_90;
      }
      lVar12 = (longlong)iVar20;
      if (lVar12 < (longlong)uVar25) {
        iVar20 = iVar20 + param_5;
        do {
          local_60[lVar12] = iVar20;
          iVar20 = iVar20 + 1;
          lVar12 = lVar12 + 1;
        } while (lVar12 < (longlong)uVar25);
      }
      puVar13 = &local_70;
      _Memory = local_60;
    }
    param_3 = local_80;
    iVar17 = 0;
    *(undefined4 **)(param_1 + 0x68) = puVar13;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
              (local_98,local_80);
    iVar20 = -1;
    if (0 < *(int *)(param_1 + 0xbc)) {
      puVar19 = (undefined8 *)(param_1 + 200);
      do {
        if (iVar20 == 0) break;
        iVar20 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 Compare(local_98,(char *)*puVar19);
        iVar17 = iVar17 + 1;
        puVar19 = puVar19 + 1;
      } while (iVar17 < *(int *)(param_1 + 0xbc));
    }
    *(int *)(param_1 + 0x70) = iVar8;
    *(uint *)(param_1 + 0x74) = param_4;
    *(undefined4 *)(param_1 + 0x78) = 8;
    *(undefined8 *)(param_1 + 0x80) = 0x3f40624dd2f1a9fc;
    *(undefined8 *)(param_1 + 0x88) = 0;
    iVar8 = Pa_OpenStream(param_1 + 0x90,param_1 + 0x50,(int *)(param_1 + 0x70),DAT_140044198,0x40,0
                          ,FUN_14000acb0,param_1);
    if (iVar8 == 0) {
      if (_Memory != (undefined4 *)0x0) {
        free(_Memory);
      }
      *(int *)(param_1 + 0x1918) = *(int *)(param_1 + 0x54) << 7;
      *(undefined4 *)(param_1 + 0xa0) = 1;
      puVar19 = (undefined8 *)(param_1 + 0x8e0);
      lVar12 = 2;
      do {
        if ((void *)*puVar19 != (void *)0x0) {
          free((void *)*puVar19);
          *puVar19 = 0;
        }
        puVar19 = puVar19 + 1;
        lVar12 = lVar12 + -1;
      } while (lVar12 != 0);
      pCVar24 = (LPCSTR)(param_1 + 0xc20);
      lVar12 = 100;
      lVar26 = 2;
      local_res8 = pCVar24;
      do {
        lVar18 = 100;
        pCVar21 = pCVar24;
        do {
          if (*(void **)pCVar21 != (void *)0x0) {
            free(*(void **)pCVar21);
            pCVar21[0] = '\0';
            pCVar21[1] = '\0';
            pCVar21[2] = '\0';
            pCVar21[3] = '\0';
            pCVar21[4] = '\0';
            pCVar21[5] = '\0';
            pCVar21[6] = '\0';
            pCVar21[7] = '\0';
          }
          pCVar21 = pCVar21 + 8;
          lVar18 = lVar18 + -1;
        } while (lVar18 != 0);
        pCVar24 = pCVar24 + 0x330;
        lVar26 = lVar26 + -1;
      } while (lVar26 != 0);
      puVar19 = (undefined8 *)(param_1 + 0x1290);
      lVar26 = 100;
      local_78 = puVar19;
      do {
        if ((void *)*puVar19 != (void *)0x0) {
          free((void *)*puVar19);
          *puVar19 = 0;
        }
        puVar19 = puVar19 + 1;
        lVar26 = lVar26 + -1;
      } while (lVar26 != 0);
      puVar19 = (undefined8 *)(param_1 + 0x15b8);
      lVar26 = 100;
      do {
        if ((void *)*puVar19 != (void *)0x0) {
          free((void *)*puVar19);
          *puVar19 = 0;
        }
        puVar19 = puVar19 + 1;
        lVar26 = lVar26 + -1;
      } while (lVar26 != 0);
      puVar19 = (undefined8 *)(param_1 + 0x8e0);
      lVar26 = 2;
      do {
        lVar18 = lVar26;
        auVar2._8_8_ = 0;
        auVar2._0_8_ = (longlong)(*(int *)(param_1 + 0x54) << 6);
        _Var11 = SUB168(ZEXT816(2) * auVar2,0);
        if (SUB168(ZEXT816(2) * auVar2,8) != 0) {
          _Var11 = 0xffffffffffffffff;
        }
        pvVar15 = operator_new(_Var11);
        *puVar19 = pvVar15;
        memset(pvVar15,0,(longlong)(*(int *)(param_1 + 0x54) << 6) * 2);
        puVar19 = puVar19 + 1;
        lVar26 = lVar18 + -1;
      } while (lVar26 != 0);
      *(undefined4 *)(param_1 + 0x8f0) = 0;
      puVar13 = (undefined4 *)(param_1 + 0xf40);
      local_90 = 2;
      _Var11 = lVar18 - 2;
      pCVar24 = local_res8;
      do {
        lVar26 = 100;
        pCVar21 = pCVar24;
        do {
          auVar3._8_8_ = 0;
          auVar3._0_8_ = (longlong)(*(int *)(param_1 + 0x74) << 6);
          _Var16 = SUB168(ZEXT816(2) * auVar3,0);
          if (SUB168(ZEXT816(2) * auVar3,8) != 0) {
            _Var16 = _Var11;
          }
          pvVar15 = operator_new(_Var16);
          *(void **)pCVar21 = pvVar15;
          memset(pvVar15,0,(longlong)(*(int *)(param_1 + 0x74) << 6) * 2);
          pCVar21 = pCVar21 + 8;
          lVar26 = lVar26 + -1;
        } while (lVar26 != 0);
        puVar13[1] = 0;
        *puVar13 = 0;
        puVar13[2] = (int)_Var11;
        puVar13 = puVar13 + 0xcc;
        pCVar24 = pCVar24 + 0x330;
        local_90 = local_90 + -1;
      } while (local_90 != 0);
      *(int *)(param_1 + 0xc18) = *(int *)(param_1 + 0x54) << 7;
      *(undefined2 *)(param_1 + 0x38) = 1;
      *(short *)(param_1 + 0x3a) = *(short *)(param_1 + 0x54);
      *(undefined4 *)(param_1 + 0x46) = 0x10;
      *(undefined4 *)(param_1 + 0x3c) = 0xac44;
      uVar4 = *(short *)(param_1 + 0x54) * 2;
      *(ushort *)(param_1 + 0x44) = uVar4;
      *(uint *)(param_1 + 0x40) = (uint)uVar4 * 0xac44;
      lVar26 = 100;
      puVar19 = (undefined8 *)(param_1 + 0x15b8);
      local_90 = 0;
      puVar23 = local_78;
      do {
        auVar1 = ZEXT816(2) * ZEXT216(*(ushort *)(param_1 + 0x3a)) * (undefined1  [16])0x40;
        _Var11 = auVar1._0_8_;
        if (auVar1._8_8_ != 0) {
          _Var11 = 0xffffffffffffffff;
        }
        pvVar15 = operator_new(_Var11);
        *puVar23 = pvVar15;
        memset(pvVar15,0,(ulonglong)*(ushort *)(param_1 + 0x3a) << 7);
        puVar23 = puVar23 + 1;
        lVar26 = lVar26 + -1;
      } while (lVar26 != 0);
      *(undefined8 *)(param_1 + 0x15b0) = 0;
      do {
        auVar1 = ZEXT816(2) * ZEXT216(*(ushort *)(param_1 + 0x3a)) * (undefined1  [16])0x40;
        _Var11 = auVar1._0_8_;
        if (auVar1._8_8_ != 0) {
          _Var11 = 0xffffffffffffffff;
        }
        pvVar15 = operator_new(_Var11);
        *puVar19 = pvVar15;
        memset(pvVar15,0,(ulonglong)*(ushort *)(param_1 + 0x3a) << 7);
        puVar19 = puVar19 + 1;
        lVar12 = lVar12 + -1;
      } while (lVar12 != 0);
      *(undefined8 *)(param_1 + 0x18d8) = 0;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_98);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_88);
      param_3 = local_80;
    }
    else {
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_res8);
      uVar14 = Pa_GetErrorText(iVar8);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_res8,"ASIOAudio: dev open stream error (+%s)",uVar14);
      MessageBoxA((HWND)0x0,local_res8,"ASIOAudio",0x10);
      if (_Memory != (undefined4 *)0x0) {
        free(_Memory);
      }
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_res8);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_98);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_88);
    }
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_3);
  return;
}

