
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_14000fb40(void *param_1,uint param_2,int param_3,undefined4 param_4,undefined4 param_5,
                  undefined8 param_6,undefined4 param_7)

{
  CWnd *pCVar1;
  float fVar2;
  float fVar3;
  undefined4 uVar4;
  undefined4 uVar5;
  float fVar6;
  bool bVar7;
  int iVar8;
  int iVar9;
  int iVar10;
  int iVar11;
  BOOL BVar12;
  ulong uVar13;
  ulong uVar14;
  ulong uVar15;
  undefined4 uVar16;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar17;
  ulonglong uVar18;
  CDialog *pCVar19;
  undefined7 extraout_var;
  longlong lVar20;
  void *pvVar21;
  CWinThread *pCVar22;
  ulonglong uVar23;
  char *pcVar24;
  undefined8 *puVar25;
  longlong *plVar26;
  uint uVar27;
  CDialog *pCVar28;
  float fVar29;
  float fVar30;
  undefined1 auStackY_458 [32];
  int local_418;
  int local_414;
  CDialog *local_410;
  int local_408;
  ulong local_404;
  ulong local_400;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_3f8 [8];
  undefined8 local_3f0 [2];
  ulong local_3e0;
  uint local_3d8;
  int local_3d4;
  uint local_3d0;
  int local_3cc;
  undefined4 local_3c8;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_3c0 [8];
  undefined8 *local_3b8;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_3b0 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_3a8 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_3a0 [8];
  undefined8 local_398;
  CDialog local_388 [544];
  tagRECT local_168;
  char local_158 [112];
  ulonglong local_e8;
  
  local_398 = 0xfffffffffffffffe;
  local_e8 = DAT_1400630d8 ^ (ulonglong)auStackY_458;
  pCVar28 = (CDialog *)0x0;
  if (*(int *)((longlong)param_1 + 0x478) != 0) {
    *(undefined4 *)((longlong)param_1 + 0x478) = 0;
  }
  *(undefined4 *)((longlong)param_1 + 0x1118) = param_5;
  *(undefined4 *)((longlong)param_1 + 0x19a0) = param_7;
  local_3d8 = param_2;
  local_3cc = param_3;
  local_3c8 = param_4;
  FUN_14001cbf0(local_388,(CWnd *)0x0);
  CDialog::Create(local_388,(char *)0x6a,(CWnd *)0x0);
  if ((*(int *)((longlong)param_1 + 0x484) == 0) ||
     (pcVar24 = "Lola - CXP/GenICam Info", *(int *)((longlong)param_1 + 0x19a0) != 0)) {
    pcVar24 = "Lola - Info";
  }
  CWnd::SetWindowTextA((CWnd *)local_388,pcVar24);
  fVar6 = DAT_140044d98;
  uVar5 = DAT_140044d78;
  uVar4 = DAT_140044d74;
  fVar3 = DAT_140044490;
  fVar2 = DAT_140044178;
  if (*(int *)((longlong)param_1 + 0x404) != 0) {
    plVar26 = (longlong *)((longlong)param_1 + 0x3d8);
    puVar25 = (undefined8 *)((longlong)param_1 + 0x40);
    pCVar19 = pCVar28;
    do {
      local_3b8 = puVar25;
      if (*plVar26 != 0) {
        xiStopAcquisition();
        xiCloseDevice(*plVar26);
        *plVar26 = 0;
      }
      CWnd::ShowWindow((CWnd *)local_388,1);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_3f8,"");
      local_3d0 = (int)pCVar19 + 1;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                (local_3f8,"Initializing USB3 camera #%d. Please wait ...",(ulonglong)local_3d0);
      pCVar17 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          (local_3a8,local_3f8);
      FUN_14001cda0((longlong)local_388,pCVar17);
      local_410 = (CDialog *)(longlong)(int)pCVar19;
      iVar8 = xiOpenDevice(pCVar19,(void *)((longlong)param_1 + (longlong)(local_410 + 0x7b) * 8));
      if (iVar8 != 0) {
        MessageBoxA((HWND)0x0,"Lola was unable to initialize your USB3 Ximea camera.\n",
                    "Lola USB3 initialization error",0x10);
        pCVar17 = local_3f8;
        goto LAB_14001072c;
      }
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_3f8);
      xiSetParamInt(*plVar26,"exposure");
      uVar27 = local_3d8;
      *(undefined4 *)(puVar25 + -1) = 0xe8;
      *puVar25 = 0;
      *(undefined4 *)(puVar25 + 1) = 0;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 ((longlong)param_1 + (ulonglong)local_3d8 * 8 + 0x890),"RGB24",0);
      xiSetParamInt(*plVar26,"imgdataformat");
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_3c0);
      pCVar17 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          (local_3a0,
                           (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                            *)((longlong)param_1 + (ulonglong)uVar27 * 8 + 0x890));
      FUN_140020ee0(pCVar17,(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             *)0x0,
                    (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)0x0
                    ,&local_418,&local_414,local_3c0,(int *)0x0);
      xiGetParamInt(*plVar26,"width",&local_408);
      if (local_408 < local_418) {
        local_418 = local_408;
      }
      xiGetParamInt(*plVar26,"height",&local_3d4);
      if (local_3d4 < local_414) {
        local_414 = local_3d4;
      }
      iVar8 = local_408 / 2;
      iVar9 = local_418 / 2;
      iVar10 = local_3d4 / 2;
      iVar11 = local_414 / 2;
      xiSetParamInt(*plVar26,"width",local_418);
      xiSetParamInt(*plVar26,"height",local_414);
      xiSetParamInt(*plVar26,"offsetX",iVar8 - iVar9);
      xiSetParamInt(*plVar26,"offsetY",iVar10 - iVar11);
      xiSetParamInt(*plVar26,&DAT_140044a20,0);
      xiSetParamInt(*plVar26,"auto_wb",0);
      BVar12 = PathFileExistsA(".\\XimeaColors.ini");
      if (BVar12 == 0) {
        xiSetParamFloat(*plVar26,"wb_kr",fVar3);
        xiSetParamFloat(*plVar26,"wb_kg",fVar3);
        xiSetParamFloat(*plVar26,"wb_kb",fVar3);
        xiSetParamInt(*plVar26,&DAT_140044af8,0);
        xiSetParamFloat(*plVar26,"gammaY",uVar4);
        xiSetParamFloat(*plVar26,"gammaC",uVar5);
        xiSetParamInt(*plVar26,&DAT_140044b10,0);
      }
      else {
        FUN_14001cdf0(local_3f0,".\\XimeaColors.ini");
        local_3e0 = FUN_14001d680((longlong)local_3f0,"Colors","m_RedGain",0x40,10);
        local_400 = FUN_14001d680((longlong)local_3f0,"Colors","m_GreenGain",0x40,10);
        local_404 = FUN_14001d680((longlong)local_3f0,"Colors","m_BlueGain",0x40,10);
        uVar13 = FUN_14001d680((longlong)local_3f0,"Colors","m_GainAll",0,10);
        uVar14 = FUN_14001d680((longlong)local_3f0,"Colors","m_Luminosity",0xd3,10);
        uVar15 = FUN_14001d680((longlong)local_3f0,"Colors","m_Chromaticity",0xcc,10);
        FUN_14001d400((longlong)local_3f0,"Colors","m_BadPixelsCorrection",0);
        uVar16 = FUN_14001d400((longlong)local_3f0,"Colors","m_RawColorCorrection",0);
        *(undefined4 *)((longlong)param_1 + 0x10a0) = uVar16;
        uVar23 = (ulonglong)local_400;
        uVar18 = (ulonglong)local_404;
        fVar29 = DAT_140044d7c - (float)uVar14 / fVar6;
        fVar30 = fVar3;
        if (fVar29 <= fVar3) {
          fVar30 = fVar29;
        }
        fVar29 = DAT_140044d70;
        if (DAT_140044d70 <= fVar30) {
          fVar29 = fVar30;
        }
        xiSetParamFloat(*plVar26,"wb_kr",(float)local_3e0 * fVar2);
        xiSetParamFloat(*plVar26,"wb_kg",(float)uVar23 * fVar2);
        xiSetParamFloat(*plVar26,"wb_kb",(float)uVar18 * fVar2);
        xiSetParamInt(*plVar26,&DAT_140044af8,uVar13);
        xiSetParamFloat(*plVar26,"gammaY",fVar29);
        xiSetParamFloat(*plVar26,"gammaC",(float)uVar15 / fVar6);
        xiSetParamInt(*plVar26,&DAT_140044b10);
        if (*(longlong *)((longlong)param_1 + 0x1098) != 0) {
          FUN_140014910(*(longlong *)((longlong)param_1 + 0x1098),local_3e0,0,local_400,0,local_404,
                        0);
        }
        FUN_14001ce40(local_3f0);
        puVar25 = local_3b8;
      }
      xiStartAcquisition(*plVar26);
      xiGetImage(*plVar26,1000,(longlong)local_410 * 0xe8 + 0x38 + (longlong)param_1);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_3c0);
      pCVar19 = (CDialog *)(ulonglong)local_3d0;
      plVar26 = plVar26 + 1;
      puVar25 = puVar25 + 0x1d;
      param_4 = local_3c8;
      param_3 = local_3cc;
      local_3b8 = puVar25;
    } while (local_3d0 < *(uint *)((longlong)param_1 + 0x404));
  }
  pcVar24 = "";
  switch(*(undefined4 *)((longlong)param_1 + 0x4c)) {
  default:
    iVar8 = 1;
    break;
  case 1:
  case 6:
    iVar8 = 2;
    break;
  case 2:
  case 4:
    iVar8 = 3;
    break;
  case 3:
    iVar8 = 4;
  }
  *(int *)((longlong)param_1 + 0x10d0) =
       *(int *)((longlong)param_1 + 0x54) * iVar8 * *(int *)((longlong)param_1 + 0x50);
  *(undefined4 *)((longlong)param_1 + 0x10c8) = *(undefined4 *)((longlong)param_1 + 0x50);
  *(undefined4 *)((longlong)param_1 + 0x10cc) = *(undefined4 *)((longlong)param_1 + 0x54);
  *(int *)((longlong)param_1 + 0x10dc) = iVar8 * 8;
  *(int *)((longlong)param_1 + 0x1110) = param_3;
  *(undefined4 *)((longlong)param_1 + 0x1114) = param_4;
  pCVar1 = *(CWnd **)((longlong)param_1 + 0x1840);
  if (pCVar1 != (CWnd *)0x0) {
    *(undefined4 *)((longlong)param_1 + 0x10c0) = *(undefined4 *)(pCVar1 + 0x15c);
    FUN_140018f30(pCVar1);
    plVar26 = *(longlong **)((longlong)param_1 + 0x1840);
    if (plVar26 != (longlong *)0x0) {
      (**(code **)(*plVar26 + 8))(plVar26,1);
    }
    *(undefined8 *)((longlong)param_1 + 0x1840) = 0;
  }
  local_410 = operator_new(0x480);
  pCVar19 = pCVar28;
  if (local_410 != (CDialog *)0x0) {
    pCVar19 = FUN_1400181e0(local_410);
  }
  *(CDialog **)((longlong)param_1 + 0x1840) = pCVar19;
  pCVar19[0x165] = (CDialog)0x1;
  *(undefined4 *)(*(longlong *)((longlong)param_1 + 0x1840) + 0x2d4) = 1;
  if (*(int *)((longlong)param_1 + 0x10dc) == 0x18) {
    *(undefined4 *)(*(longlong *)((longlong)param_1 + 0x1840) + 0x2d0) = 1;
  }
  FUN_140014910(*(longlong *)(*(longlong *)((longlong)param_1 + 0x1840) + 0x228),
                *(undefined4 *)((longlong)param_1 + 0x10a4),
                *(undefined4 *)((longlong)param_1 + 0x10a8),
                *(undefined4 *)((longlong)param_1 + 0x10ac),
                *(undefined4 *)((longlong)param_1 + 0x10b0),
                *(undefined4 *)((longlong)param_1 + 0x10b4),
                *(undefined4 *)((longlong)param_1 + 0x10b8));
  FUN_1400196c0(*(longlong *)((longlong)param_1 + 0x1840),*(int *)((longlong)param_1 + 0x10c0));
  *(undefined4 *)(*(longlong *)((longlong)param_1 + 0x1840) + 0x168) =
       *(undefined4 *)((longlong)param_1 + 0x1118);
  if (*(int *)((longlong)param_1 + 0x10dc) == 0x18) {
    *(undefined4 *)(*(longlong *)((longlong)param_1 + 0x1840) + 0x2d8) = 1;
  }
  if (0 < *(int *)((longlong)param_1 + 0x1114)) {
    pcVar24 = " - COMPRESSED";
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_3b0,pcVar24);
  iVar8 = 0;
  if ((*(int *)((longlong)param_1 + 0x10dc) == 8) && (*(int *)((longlong)param_1 + 0x1998) != 0)) {
    iVar8 = 1;
  }
  bVar7 = FUN_140018f60(*(CWnd **)((longlong)param_1 + 0x1840),0,
                        *(undefined4 *)((longlong)param_1 + 0x10c8),
                        *(undefined4 *)((longlong)param_1 + 0x10cc),
                        *(int *)((longlong)param_1 + 0x10dc),iVar8,
                        *(int *)((longlong)param_1 + 0x199c));
  if ((int)CONCAT71(extraout_var,bVar7) == 0) {
    MessageBoxA((HWND)0x0,"Couldn\'t create display surface","CBFVideoServer Class",0x40);
  }
  else {
    FUN_1400062f0(local_158,"Local host (%dx%d, %d bit, %d FpS)%s",
                  (ulonglong)*(uint *)((longlong)param_1 + 0x10c8),
                  (ulonglong)*(uint *)((longlong)param_1 + 0x10cc));
    *(int *)((longlong)param_1 + 0x19a4) = iVar8;
    pCVar17 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
              ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
              CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                        ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          *)&local_410,local_158);
    FUN_140019790(*(CWnd **)((longlong)param_1 + 0x1840),pCVar17);
    local_168.left = 0;
    local_168.top = 0;
    local_168.right = 0;
    local_168.bottom = 0;
    pCVar19 = pCVar28;
    if (*(longlong *)((longlong)param_1 + 0x19c0) != 0) {
      pCVar19 = *(CDialog **)(*(longlong *)((longlong)param_1 + 0x19c0) + 0x40);
    }
    GetWindowRect((HWND)pCVar19,&local_168);
    FUN_140019610(*(CWnd **)((longlong)param_1 + 0x1840),local_168.right - local_168.left,
                  local_168.top);
    thunk_FUN_14001c720(*(CWnd **)((longlong)param_1 + 0x1840),fVar3);
    *(undefined4 *)(*(longlong *)((longlong)param_1 + 0x1840) + 0x308) = 1;
    lVar20 = FUN_140019520(*(longlong *)((longlong)param_1 + 0x1840));
    *(longlong *)((longlong)param_1 + 0x1108) = lVar20;
    if (lVar20 == 0) {
      MessageBoxA((HWND)0x0,"No display surface available","CBFVideoServer Class",0x40);
    }
    else {
      puVar25 = (undefined8 *)((longlong)param_1 + 0x1878);
      lVar20 = 0x1e;
      if (param_3 == 0) {
        do {
          if ((void *)*puVar25 != (void *)0x0) {
            free((void *)*puVar25);
          }
          pvVar21 = operator_new((ulonglong)*(uint *)((longlong)param_1 + 0x10d0));
          *puVar25 = pvVar21;
          memset(pvVar21,0,(ulonglong)*(uint *)((longlong)param_1 + 0x10d0));
          puVar25 = puVar25 + 1;
          lVar20 = lVar20 + -1;
        } while (lVar20 != 0);
        if (*(void **)((longlong)param_1 + 0x19b0) != (void *)0x0) {
          free(*(void **)((longlong)param_1 + 0x19b0));
        }
        pvVar21 = operator_new((ulonglong)*(uint *)((longlong)param_1 + 0x10d0));
        uVar27 = *(uint *)((longlong)param_1 + 0x10d0);
      }
      else {
        do {
          if ((void *)*puVar25 != (void *)0x0) {
            free((void *)*puVar25);
          }
          pvVar21 = operator_new((ulonglong)*(uint *)((longlong)param_1 + 0x10d4));
          *puVar25 = pvVar21;
          memset(pvVar21,0,(ulonglong)*(uint *)((longlong)param_1 + 0x10d4));
          puVar25 = puVar25 + 1;
          lVar20 = lVar20 + -1;
        } while (lVar20 != 0);
        if (*(void **)((longlong)param_1 + 0x19b0) != (void *)0x0) {
          free(*(void **)((longlong)param_1 + 0x19b0));
        }
        pvVar21 = operator_new((ulonglong)*(uint *)((longlong)param_1 + 0x10d4));
        uVar27 = *(uint *)((longlong)param_1 + 0x10d4);
      }
      *(void **)((longlong)param_1 + 0x19b0) = pvVar21;
      memset(pvVar21,0,(ulonglong)uVar27);
      pCVar22 = AfxBeginThread(FUN_140013a30,param_1,0,0,0,(_SECURITY_ATTRIBUTES *)0x0);
      *(CWinThread **)((longlong)param_1 + 0x420) = pCVar22;
      iVar8 = *(int *)((longlong)param_1 + 0x478);
      while (iVar8 == 0) {
        Sleep(100);
        uVar27 = (int)pCVar28 + 1;
        pCVar28 = (CDialog *)(ulonglong)uVar27;
        if (9 < (int)uVar27) break;
        iVar8 = *(int *)((longlong)param_1 + 0x478);
      }
      CWnd::DestroyWindow((CWnd *)local_388);
    }
  }
  pCVar17 = local_3b0;
LAB_14001072c:
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(pCVar17);
  FUN_14001cc50(local_388);
  return;
}

