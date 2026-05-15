
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

undefined8 FUN_1400190f0(CWnd *param_1,uint *param_2,undefined1 *param_3,uint *param_4)

{
  longlong lVar1;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *this;
  IAtlStringMgr *pIVar2;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar3;
  longlong lVar4;
  byte *pbVar6;
  uint *puVar7;
  undefined1 *puVar8;
  uint *puVar9;
  uint uVar10;
  uint *puVar11;
  undefined1 *_Size;
  uint uVar12;
  uint *puVar13;
  undefined1 *puVar14;
  undefined1 auStackY_128 [32];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_f0 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_e8 [8];
  undefined8 local_e0;
  _OutputArray local_d8 [32];
  _InputArray local_b8 [32];
  Mat local_98 [96];
  ulonglong local_38;
  longlong lVar5;
  
  local_e0 = 0xfffffffffffffffe;
  local_38 = DAT_1400630d8 ^ (ulonglong)auStackY_128;
  puVar11 = (uint *)0x0;
  _Size = param_3;
  puVar13 = param_4;
  if (param_1[0x158] != (CWnd)0x0) {
    FUN_140018aa0(param_1);
    param_1[0x158] = (CWnd)0x0;
  }
  FUN_140020e20((longlong)(param_1 + 0x1f0));
  if ((int)param_4 != 0) {
    return 1;
  }
  uVar10 = (uint)param_3;
  if ((uVar10 - 8 & 0xffffffe7) == 0) {
    if (uVar10 != 0x10) {
      if ((*(int *)(param_1 + 0x21c) == 0) || (uVar10 != 8)) {
        _Size = (undefined1 *)
                (ulonglong)(*(int *)(param_1 + 0x1d0) * *(int *)(param_1 + 0x1c8) * (uVar10 >> 3));
        memcpy(*(void **)(param_1 + 0x1b8),param_2,(size_t)_Size);
      }
      else if (*(int *)(param_1 + 0x168) == 0) {
        puVar13 = (uint *)(ulonglong)*(uint *)(param_1 + 0x1c8);
        _Size = *(undefined1 **)(param_1 + 0x1b8);
        FUN_14000c120(*(longlong *)(param_1 + 0x220),(longlong)param_2,(longlong)_Size,
                      *(uint *)(param_1 + 0x1c8),*(int *)(param_1 + 0x1d0));
      }
      else {
        FUN_140018610((uint *)local_98,*(uint *)(param_1 + 0x1d0),*(uint *)(param_1 + 0x1c8),0,
                      param_2,0);
        cv::_OutputArray::_OutputArray(local_d8,(Mat *)(param_1 + 0x3a0));
        cv::_InputArray::_InputArray(local_b8,local_98);
        puVar13 = (uint *)0x0;
        _Size = (undefined1 *)(ulonglong)*(uint *)(param_1 + 0x160);
        cv::cvtColor(local_b8,local_d8,*(uint *)(param_1 + 0x160),0);
        FUN_14000ecf0(local_98);
      }
      if (((*(int *)(param_1 + 0x324) != 0) && (*(int *)(param_1 + 0x1d4) == 0x18)) &&
         (pbVar6 = *(byte **)(param_1 + 0x1b8),
         *(int *)(param_1 + 0x1d0) * *(int *)(param_1 + 0x1c8) * 3 != 0)) {
        do {
          *pbVar6 = (byte)*(undefined4 *)
                           (*(longlong *)(param_1 + 0x228) + 0x800 + (ulonglong)*pbVar6 * 4);
          pbVar6[1] = (byte)*(undefined4 *)
                             (*(longlong *)(param_1 + 0x228) + 0x400 + (ulonglong)pbVar6[1] * 4);
          pbVar6[2] = (byte)*(undefined4 *)
                             (*(longlong *)(param_1 + 0x228) + (ulonglong)pbVar6[2] * 4);
          pbVar6 = pbVar6 + 3;
          uVar10 = (int)puVar11 + 3;
          puVar11 = (uint *)(ulonglong)uVar10;
        } while (uVar10 < (uint)(*(int *)(param_1 + 0x1d0) * *(int *)(param_1 + 0x1c8) * 3));
      }
      goto LAB_140019440;
    }
  }
  else if (0x10 < uVar10) {
    if (uVar10 == 0x1e) {
      puVar14 = *(undefined1 **)(param_1 + 0x1b8);
      if (*(int *)(param_1 + 0x1d0) * *(int *)(param_1 + 0x1c8) != 0) {
        do {
          *puVar14 = (char)(*param_2 >> 2);
          puVar14[1] = (char)(*param_2 >> 0xc);
          puVar14[2] = (char)(*param_2 >> 0x16);
          puVar14 = puVar14 + 3;
          param_2 = param_2 + 1;
          uVar10 = (int)puVar11 + 1;
          puVar11 = (uint *)(ulonglong)uVar10;
        } while (uVar10 < (uint)(*(int *)(param_1 + 0x1d0) * *(int *)(param_1 + 0x1c8)));
      }
    }
    else {
      if (0xf < uVar10 - 0x21) {
        return 1;
      }
      puVar14 = *(undefined1 **)(param_1 + 0x1b8);
      if (*(int *)(param_1 + 0x1d0) != 0) {
        _Size = (undefined1 *)(ulonglong)*(uint *)(param_1 + 0x1c8);
        puVar9 = puVar11;
        do {
          puVar8 = puVar14;
          puVar13 = param_2;
          puVar7 = puVar11;
          if ((int)_Size * 3 != 0) {
            do {
              *puVar8 = (char)((ushort)*puVar13 >>
                              ((char)(((ulonglong)param_3 & 0xffffffff) / 3) - 8U & 0x1f));
              puVar8 = puVar8 + 1;
              puVar13 = (uint *)((longlong)puVar13 + 2);
              uVar10 = (int)puVar7 + 1;
              puVar7 = (uint *)(ulonglong)uVar10;
              _Size = (undefined1 *)(ulonglong)*(uint *)(param_1 + 0x1c8);
            } while (uVar10 < *(uint *)(param_1 + 0x1c8) * 3);
          }
          uVar10 = (int)_Size * 3;
          puVar14 = puVar14 + uVar10;
          param_2 = (uint *)((longlong)param_2 + (ulonglong)uVar10 * 2);
          uVar10 = (int)puVar9 + 1;
          puVar9 = (uint *)(ulonglong)uVar10;
        } while (uVar10 < *(uint *)(param_1 + 0x1d0));
      }
    }
    goto LAB_140019440;
  }
  puVar14 = *(undefined1 **)(param_1 + 0x1b8);
  if (*(int *)(param_1 + 0x1d0) != 0) {
    uVar10 = *(uint *)(param_1 + 0x1c8);
    puVar9 = puVar11;
    do {
      puVar7 = param_2;
      _Size = puVar14;
      puVar13 = puVar11;
      if (uVar10 != 0) {
        do {
          *_Size = (char)((ushort)*puVar7 >> ((char)param_3 - 8U & 0x1f));
          _Size = _Size + 1;
          puVar7 = (uint *)((longlong)puVar7 + 2);
          uVar12 = (int)puVar13 + 1;
          puVar13 = (uint *)(ulonglong)uVar12;
          uVar10 = *(uint *)(param_1 + 0x1c8);
        } while (uVar12 < uVar10);
      }
      puVar14 = puVar14 + uVar10;
      param_2 = (uint *)((longlong)param_2 + (ulonglong)uVar10 * 2);
      uVar12 = (int)puVar9 + 1;
      puVar9 = (uint *)(ulonglong)uVar12;
    } while (uVar12 < *(uint *)(param_1 + 0x1d0));
  }
LAB_140019440:
  if (*(int *)(param_1 + 0x2c8) != 0) {
    this = FUN_140020e30((longlong)(param_1 + 0x1f0),local_e8,_Size,puVar13);
    pIVar2 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             GetManager(this);
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_f0,pIVar2);
    lVar5 = -1;
    do {
      lVar4 = lVar5 + 1;
      lVar1 = lVar5 + 1;
      lVar5 = lVar4;
    } while ("DSFormatBlit-Bayer: "[lVar1] != '\0');
    ATL::CSimpleStringT<char,1>::Concatenate
              ((CSimpleStringT<char,1> *)local_f0,"DSFormatBlit-Bayer: ",(int)lVar4,*(char **)this,
               *(int *)(*(char **)this + -0x10));
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               (param_1 + 0x338),pCVar3);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_f0);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_e8);
  }
  FUN_140018ef0((longlong)param_1);
  return 0;
}

