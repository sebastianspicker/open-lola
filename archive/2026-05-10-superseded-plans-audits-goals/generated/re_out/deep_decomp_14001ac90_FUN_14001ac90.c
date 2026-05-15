
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_14001ac90(CWnd *param_1)

{
  BOOL BVar1;
  int iVar2;
  DWORD DVar3;
  HDC pHVar4;
  CDC *pCVar5;
  CGdiObject *pCVar6;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar7;
  IAtlStringMgr *pIVar8;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar9;
  undefined8 *puVar10;
  longlong lVar11;
  longlong lVar12;
  longlong lVar13;
  void *pvVar14;
  void *pvVar15;
  char *pcVar16;
  int iVar17;
  undefined *puVar18;
  float fVar19;
  undefined1 auStackY_1c8 [32];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_160 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_158 [8];
  CDC local_150 [8];
  HDC__ *local_148;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_130 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_128 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_120 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_118 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_110 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_108 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_100 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_f8 [8];
  undefined8 local_f0;
  undefined8 local_e8;
  tagRECT local_e0;
  CPaintDC local_c8 [8];
  HDC local_c0;
  ulonglong local_58;
  
  local_e8 = 0xfffffffffffffffe;
  local_58 = DAT_1400630d8 ^ (ulonglong)auStackY_1c8;
  pvVar15 = (void *)0x0;
  FUN_140020e20((longlong)(param_1 + 0x1f0));
  CPaintDC::CPaintDC(local_c8,param_1);
  local_e0.left = 0;
  local_e0.top = 0;
  local_e0.right = 0;
  local_e0.bottom = 0;
  GetClientRect(*(HWND *)(param_1 + 0x40),&local_e0);
  BVar1 = IsIconic(*(HWND *)(param_1 + 0x40));
  if (BVar1 == 0) {
    if (*(int *)(param_1 + 800) == 0) {
      iVar17 = FUN_14001b580((longlong)param_1,*(longlong *)(param_1 + 0x1a0));
      param_1 = (CWnd *)CONCAT44((int)((ulonglong)param_1 >> 0x20),iVar17);
    }
    else {
      CDC::CDC(local_150);
      iVar17 = *(int *)(param_1 + 0x1c4);
      pHVar4 = CreateCompatibleDC(local_c0);
      iVar2 = CDC::Attach(local_150,pHVar4);
      if (iVar2 == 0) {
        CWnd::MessageBoxA(param_1,"Cannot create CompatibleDC",(char *)0x0,0x30);
        FUN_140018eb0(param_1);
        CDC::~CDC(local_150);
        goto LAB_14001b528;
      }
      pCVar6 = CGdiObject::FromHandle(*(void **)(param_1 + 0x1a0));
      pvVar14 = pvVar15;
      if (pCVar6 != (CGdiObject *)0x0) {
        pvVar14 = *(void **)(pCVar6 + 8);
      }
      pCVar6 = CDC::SelectGdiObject(local_148,pvVar14);
      if (*(int *)(param_1 + 0x238) != 0) {
        SetDIBColorTable(local_148,0,0x100,(RGBQUAD *)(*(longlong *)(param_1 + 0x1b0) + 0x28));
        SetDIBColorTable(local_c0,0,0x100,(RGBQUAD *)(*(longlong *)(param_1 + 0x1b0) + 0x28));
        *(undefined4 *)(param_1 + 0x238) = 0;
      }
      CDC::SelectPalette(local_150,*(CPalette **)(param_1 + 0x240),0);
      RealizePalette(local_148);
      CDC::SetStretchBltMode(local_150,3);
      CDC::SelectPalette((CDC *)local_c8,*(CPalette **)(param_1 + 0x240),0);
      RealizePalette(local_c0);
      CDC::SetStretchBltMode((CDC *)local_c8,(*(int *)(param_1 + 0x2dc) == 3) + 3);
      if (*(int *)(param_1 + 0x21c) != 0) {
        CDC::FillSolidRect(local_150,0,0,5,*(int *)(param_1 + 0x1d0),0);
        CDC::FillSolidRect(local_150,*(int *)(param_1 + 0x1c8) + -5,0,*(int *)(param_1 + 0x1c8),
                           *(int *)(param_1 + 0x1d0),0);
      }
      iVar2 = *(int *)(param_1 + 0x1c8);
      if ((iVar2 == local_e0.right - local_e0.left) &&
         (*(int *)(param_1 + 0x1d0) == local_e0.bottom - local_e0.top)) {
        BitBlt(local_c0,0,0,iVar2,*(int *)(param_1 + 0x1d0),local_148,0,0,0xcc0020);
        if (*(int *)(param_1 + 0x2c8) != 0) {
          FUN_140019970((longlong)param_1,(CDC *)local_c8);
        }
      }
      else {
        StretchBlt(local_c0,*(int *)(param_1 + 0x310),*(int *)(param_1 + 0x314),
                   *(int *)(param_1 + 0x318) - *(int *)(param_1 + 0x310),
                   *(int *)(param_1 + 0x31c) - *(int *)(param_1 + 0x314),local_148,
                   *(int *)(param_1 + 0x1c0),iVar17,iVar2,*(int *)(param_1 + 0x1d0),0xcc0020);
        if (*(int *)(param_1 + 0x2c8) != 0) {
          FUN_140019970((longlong)param_1,(CDC *)local_c8);
        }
        CDC::ExcludeClipRect((CDC *)local_c8,(tagRECT *)(param_1 + 0x310));
        CDC::FillSolidRect((CDC *)local_c8,&local_e0,0);
      }
      if (*(int *)(param_1 + 0x2dc) == 3) {
        SetBrushOrgEx(local_c0,0,0,(LPPOINT)0x0);
      }
      if (pCVar6 != (CGdiObject *)0x0) {
        pvVar15 = *(void **)(pCVar6 + 8);
      }
      CDC::SelectGdiObject(local_148,pvVar15);
      CDC::DeleteDC(local_150);
      CDC::~CDC(local_150);
    }
    if (*(int *)(param_1 + 0x2c8) != 0) {
      *(int *)(param_1 + 0x214) = *(int *)(param_1 + 0x214) + 1;
      DVar3 = GetTickCount();
      if (1000 < DVar3 - *(int *)(param_1 + 0x210)) {
        fVar19 = ((float)*(int *)(param_1 + 0x214) * (float)(DVar3 - *(int *)(param_1 + 0x210))) /
                 _DAT_140046a54;
        *(undefined4 *)(param_1 + 0x214) = 0;
        DVar3 = GetTickCount();
        *(DWORD *)(param_1 + 0x210) = DVar3;
        *(float *)(param_1 + 0x218) = fVar19;
      }
      pcVar16 = "DirectX";
      if (*(int *)(param_1 + 800) != 0) {
        pcVar16 = "GDI";
      }
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_f0,pcVar16);
      puVar18 = &DAT_1400466cc;
      if (*(int *)(param_1 + 0x168) != 0) {
        puVar18 = &DAT_1400466c8;
      }
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (param_1 + 0x330),
                 "Rendering mode: %s\nSIMD Acceleration: %s\nFps: %.2f\nZoom: %.2f %%");
      pCVar7 = FUN_140020e30((longlong)(param_1 + 0x1f0),local_158,local_f0,puVar18);
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar7);
      pCVar9 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_160,pIVar8);
      lVar13 = -1;
      do {
        lVar11 = lVar13 + 1;
        lVar12 = lVar13 + 1;
        lVar13 = lVar11;
      } while ("Rendering: "[lVar12] != '\0');
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_160,"Rendering: ",(int)lVar11,*(char **)pCVar7,
                 *(int *)(*(char **)pCVar7 + -0x10));
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (param_1 + 0x340),pCVar9);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_160);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_158);
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)(param_1 + 0x330));
      pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_158,pIVar8);
      lVar13 = -1;
      do {
        lVar12 = lVar13 + 1;
        pcVar16 = &DAT_140046725 + lVar13;
        lVar13 = lVar12;
      } while (*pcVar16 != '\0');
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_158,*(char **)(param_1 + 0x330),
                 *(int *)(*(char **)(param_1 + 0x330) + -0x10),"\n",(int)lVar12);
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar7);
      pCVar9 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_f8,pIVar8);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_f8,*(char **)pCVar7,
                 *(int *)(*(char **)pCVar7 + -0x10),*(char **)(param_1 + 0x348),
                 *(int *)(*(char **)(param_1 + 0x348) + -0x10));
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar9);
      pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_100,pIVar8);
      lVar13 = -1;
      do {
        lVar12 = lVar13 + 1;
        pcVar16 = &DAT_140046725 + lVar13;
        lVar13 = lVar12;
      } while (*pcVar16 != '\0');
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_100,*(char **)pCVar9,
                 *(int *)(*(char **)pCVar9 + -0x10),"\n",(int)lVar12);
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar7);
      pCVar9 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_108,pIVar8);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_108,*(char **)pCVar7,
                 *(int *)(*(char **)pCVar7 + -0x10),*(char **)(param_1 + 0x338),
                 *(int *)(*(char **)(param_1 + 0x338) + -0x10));
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar9);
      pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_110,pIVar8);
      lVar13 = -1;
      do {
        lVar12 = lVar13 + 1;
        pcVar16 = &DAT_140046725 + lVar13;
        lVar13 = lVar12;
      } while (*pcVar16 != '\0');
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_110,*(char **)pCVar9,
                 *(int *)(*(char **)pCVar9 + -0x10),"\n",(int)lVar12);
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar7);
      pCVar9 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_118,pIVar8);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_118,*(char **)pCVar7,
                 *(int *)(*(char **)pCVar7 + -0x10),*(char **)(param_1 + 0x340),
                 *(int *)(*(char **)(param_1 + 0x340) + -0x10));
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar9);
      pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_120,pIVar8);
      lVar13 = -1;
      do {
        lVar12 = lVar13 + 1;
        pcVar16 = &DAT_140046725 + lVar13;
        lVar13 = lVar12;
      } while (*pcVar16 != '\0');
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_120,*(char **)pCVar9,
                 *(int *)(*(char **)pCVar9 + -0x10),"\n",(int)lVar12);
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar7);
      pCVar9 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_128,pIVar8);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_128,*(char **)pCVar7,
                 *(int *)(*(char **)pCVar7 + -0x10),*(char **)(param_1 + 0x350),
                 *(int *)(*(char **)(param_1 + 0x350) + -0x10));
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar9);
      pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_130,pIVar8);
      lVar13 = -1;
      do {
        lVar12 = lVar13 + 1;
        pcVar16 = &DAT_140046725 + lVar13;
        lVar13 = lVar12;
      } while (*pcVar16 != '\0');
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_130,*(char **)pCVar9,
                 *(int *)(*(char **)pCVar9 + -0x10),"\n",(int)lVar12);
      pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(pCVar7);
      puVar10 = (undefined8 *)
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          (local_160,pIVar8);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_160,*(char **)pCVar7,
                 *(int *)(*(char **)pCVar7 + -0x10),*(char **)(param_1 + 0x358),
                 *(int *)(*(char **)(param_1 + 0x358) + -0x10));
      ATL::CStringT<wchar_t,class_StrTraitMFC_DLL<wchar_t,class_ATL::ChTraitsCRT<wchar_t>_>_>::
      operator=((CStringT<wchar_t,class_StrTraitMFC_DLL<wchar_t,class_ATL::ChTraitsCRT<wchar_t>_>_>
                 *)(param_1 + 0x328),(char *)*puVar10);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_160);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_130);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_128);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_120);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_118);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_110);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_108);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_100);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_f8);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_158);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_f0);
    }
  }
  else {
    pHVar4 = GetDC(*(HWND *)(param_1 + 0x40));
    pCVar5 = CDC::FromHandle(pHVar4);
    DrawIcon(*(HDC *)(pCVar5 + 8),local_e0.left,local_e0.top,*(HICON *)(param_1 + 0x2e8));
    ReleaseDC(*(HWND *)(param_1 + 0x40),*(HDC *)(pCVar5 + 8));
  }
LAB_14001b528:
  CPaintDC::~CPaintDC(local_c8);
  return;
}

