
undefined8 FUN_14002d090(CWnd *param_1)

{
  double dVar1;
  undefined8 uVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar6;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar7;
  IAtlStringMgr *pIVar8;
  undefined8 *puVar9;
  CWnd *pCVar10;
  LRESULT LVar11;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar12;
  CSimpleStringT<char,1> *pCVar13;
  CDialog *pCVar14;
  longlong lVar15;
  longlong lVar16;
  char *pcVar17;
  CWnd *this;
  undefined *puVar18;
  longlong lVar19;
  undefined *puVar20;
  undefined8 uVar21;
  undefined8 uVar22;
  uint uVar23;
  undefined *puVar24;
  CDialog *local_res8;
  undefined8 **local_res20;
  CComboBox **local_c8;
  LPARAM local_c0;
  CComboBox *local_b8;
  char *local_b0;
  undefined8 **local_a8;
  char *local_a0;
  char **local_98;
  CComboBox **local_90;
  char *local_88;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_80 [8];
  undefined8 local_78;
  CComboBox **local_70;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_68 [8];
  char *local_60;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_58 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_50 [8];
  int local_48;
  undefined8 local_40;
  
  local_40 = 0xfffffffffffffffe;
  pCVar14 = (CDialog *)0x0;
  local_res20 = (undefined8 **)((ulonglong)local_res20 & 0xffffffff00000000);
  local_res8 = (CDialog *)param_1;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            (local_58,(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      (*(longlong *)(param_1 + 0x1908) + 0x58));
  local_c8 = (CComboBox **)&local_res20;
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res20,"SRCIP:");
  pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_b0,local_58);
  FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),
                (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                &local_a0,pCVar7,pCVar6);
  local_c8 = &local_b8;
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_b8,"DSTIP:");
  pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_a8,local_58);
  FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_68,pCVar7,pCVar6);
  local_res20 = &local_98;
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_98,"TXT:");
  pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_90,local_58);
  FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),
                (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                &local_c0,pCVar7,pCVar6);
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_c8,
                      (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_a0);
  iVar3 = FUN_14002a000((longlong)param_1,pCVar6);
  lVar19 = (longlong)iVar3;
  local_48 = iVar3;
  pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_a0);
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     (local_80,pIVar8);
  local_res20._0_4_ = 1;
  local_b0 = &DAT_ffffffffffffffff;
  lVar16 = -1;
  do {
    lVar15 = lVar16 + 1;
    pcVar17 = &DAT_14004ae79 + lVar16;
    lVar16 = lVar15;
  } while (*pcVar17 != '\0');
  ATL::CSimpleStringT<char,1>::Concatenate
            ((CSimpleStringT<char,1> *)local_80," (",(int)lVar15,local_a0,*(int *)(local_a0 + -0x10)
            );
  pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           GetManager(pCVar6);
  puVar9 = (undefined8 *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,pIVar8);
  local_res20 = (undefined8 **)CONCAT44(local_res20._4_4_,3);
  lVar16 = -1;
  do {
    lVar15 = lVar16 + 1;
    pcVar17 = &DAT_140049349 + lVar16;
    lVar16 = lVar15;
  } while (*pcVar17 != '\0');
  ATL::CSimpleStringT<char,1>::Concatenate
            ((CSimpleStringT<char,1> *)&local_78,*(char **)pCVar6,*(int *)(*(char **)pCVar6 + -0x10)
             ,")",(int)lVar15);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Insert
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_c0,
             6,(char *)*puVar9);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_78)
  ;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_80);
  pCVar10 = CWnd::GetDlgItem(param_1,0x40c);
  uVar22 = 0;
  LVar11 = SendMessageA(*(HWND *)(pCVar10 + 0x40),0xf0,0,0);
  if ((int)LVar11 != 0) {
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_res8,
               (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               (*(longlong *)(param_1 + 0x1908) + 0xa8));
    iVar3 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res8,"[(!)]",0);
    if (iVar3 < 0) {
      local_b8 = (CComboBox *)&local_res20;
      local_a8 = &local_c8;
      pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_res20,
                          (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_a0);
      pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_c8,local_68);
      pCVar12 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                            *)&local_b0,"[(!)] Remote host is busy. Please retry later.");
      FUN_1400329a0((longlong)param_1,pCVar12,pCVar7,pCVar6);
    }
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_res8);
    goto LAB_14002dcc6;
  }
  uVar21 = 0;
  pcVar17 = "lola.GetRemoteInfo()";
  iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c0,"lola.GetRemoteInfo()",0);
  if (iVar4 < 0) {
    uVar21 = 0;
    pcVar17 = "lola.ResetRemoteInfo()";
    iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_c0,"lola.ResetRemoteInfo()",0);
    if (iVar4 < 0) {
      iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                        ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          *)&local_c0,"lola.GetRemoteSettings()",0);
      if (iVar4 < 0) {
        iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                          ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                            *)&local_c0,"lola.SetRemoteAudioBuffer(",0);
        if (((-1 < iVar4) && (-1 < iVar3)) && (param_1[lVar19 + 0x1b18] != (CWnd)0x0)) {
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c0,"lola.SetRemoteAudioBuffer(",0);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Replace
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c0,"lola.SetRemoteAudioBuffer(","");
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Replace
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c0,");","");
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Mid
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c0,(int)&local_b0);
          iVar5 = atoi(local_b0);
          iVar4 = 1;
          if (0 < iVar5 + 1) {
            iVar4 = iVar5 + 1;
          }
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_res20,"");
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_res20,"%d",(ulonglong)(iVar4 - 1U));
          SendMessageA(*(HWND *)(param_1 + lVar19 * 0xa78 + 0xa48),0x405,1,(longlong)iVar4);
          CWnd::SetWindowTextA(param_1 + lVar19 * 0xa78 + 0xbd8,(char *)local_res20);
          if ((*(longlong *)(param_1 + 0x1b00) != 0) && (iVar4 - 1U < 0x15)) {
            FUN_14000aaa0(*(longlong *)(param_1 + 0x1b00),iVar3,iVar4);
          }
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_res8);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_res8,"[Remote Audio buffer changed correctly]\r\nAudio: %d\r\n",
                     (ulonglong)
                     (*(int *)(*(longlong *)(param_1 + 0x1b00) + 0x1280 + lVar19 * 4) - 1));
          local_98 = (char **)&local_c8;
          local_90 = &local_b8;
          pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_c8,
                              (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_a0);
          pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_b8,local_68);
          pCVar12 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                    CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                *)&local_a8,
                               (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                *)&local_res8);
          FUN_1400329a0((longlong)param_1,pCVar12,pCVar7,pCVar6);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_res8);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_res20);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_b0);
          goto LAB_14002dcc6;
        }
        iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                          ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                            *)&local_c0,"lola.ForceDisconnect(",0);
        if (-1 < iVar4) {
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Find
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c0,"lola.ForceDisconnect(",0);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Replace
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c0,"lola.ForceDisconnect(","");
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Replace
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c0,");","");
          pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   Mid((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_c0,(int)&local_c8);
          pCVar6 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   Trim(pCVar6);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_res20,pCVar6);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_c8);
          if (iVar3 != -1) {
            FUN_14002c100(param_1,iVar3);
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
            CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res8,"");
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res8,"[Remote %s has disconnected successfully]\r\n",local_res20);
            local_a8 = &local_c8;
            local_98 = &local_b0;
            pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)&local_c8,
                                (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)&local_a0);
            pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)&local_b0,local_68);
            pCVar12 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                      ::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                  *)&local_b8,
                                 (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                  *)&local_res8);
            FUN_1400329a0((longlong)param_1,pCVar12,pCVar7,pCVar6);
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
            ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res8);
          }
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_res20);
          goto LAB_14002dcc6;
        }
      }
      else if (((*(longlong *)(param_1 + 0x1b00) != 0) && (*(longlong *)(param_1 + 0x1af8) != 0)) &&
              (param_1 != (CWnd *)0xffffffffffffe4f8)) {
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_78,"\r\n");
        pCVar10 = param_1 + 0x5c0;
        this = param_1 + 0x580;
        do {
          local_b8 = (CComboBox *)this;
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_88,"");
          uVar23 = (int)pCVar14 + 1;
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_88,"%d");
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_60,"");
          LVar11 = SendMessageA(*(HWND *)pCVar10,0x147,0,0);
          CComboBox::GetLBText
                    ((CComboBox *)this,(int)LVar11,
                     (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_60);
          pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_88);
          pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_a8,pIVar8);
          local_res20._0_4_ = 4;
          ATL::CSimpleStringT<char,1>::Concatenate
                    ((CSimpleStringT<char,1> *)&local_a8,"Session ",8,local_88,
                     *(int *)(local_88 + -0x10));
          pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   GetManager(pCVar6);
          pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_98,pIVar8);
          local_res20._0_4_ = 0xc;
          ATL::CSimpleStringT<char,1>::Concatenate
                    ((CSimpleStringT<char,1> *)&local_98,*(char **)pCVar6,
                     *(int *)(*(char **)pCVar6 + -0x10)," - ",3);
          pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   GetManager(pCVar7);
          pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_90,pIVar8);
          local_res20._0_4_ = 0x1c;
          ATL::CSimpleStringT<char,1>::Concatenate
                    ((CSimpleStringT<char,1> *)&local_90,*(char **)pCVar7,
                     *(int *)(*(char **)pCVar7 + -0x10),local_60,*(int *)(local_60 + -0x10));
          pIVar8 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   GetManager(pCVar6);
          pCVar13 = (CSimpleStringT<char,1> *)
                    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                    CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                              (local_50,pIVar8);
          local_res20 = (undefined8 **)CONCAT44(local_res20._4_4_,0x3c);
          ATL::CSimpleStringT<char,1>::Concatenate
                    ((CSimpleStringT<char,1> *)local_50,*(char **)pCVar6,
                     *(int *)(*(char **)pCVar6 + -0x10),"\r\n",2);
          ATL::CSimpleStringT<char,1>::Append((CSimpleStringT<char,1> *)&local_78,pCVar13);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_50);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_90);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_98);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_a8);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_60);
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     &local_88);
          pCVar14 = (CDialog *)(ulonglong)uVar23;
          this = (CWnd *)(local_b8 + 0xa78);
          pCVar10 = pCVar10 + 0xa78;
        } while ((int)uVar23 < 2);
        local_b8 = (CComboBox *)this;
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_70,"Version: ");
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator+=
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_70,"2.0.0 - Beta 1");
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator+=
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_70,"\r\nBuild: Ximea SDK");
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator+=
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_70," - CUDA Disabled");
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_80,"");
        pCVar14 = local_res8;
        if (local_48 < 0) {
          local_res20 = (undefined8 **)CONCAT44(local_res20._4_4_,0xffffffff);
        }
        else {
          local_res20 = (undefined8 **)
                        CONCAT44(local_res20._4_4_,
                                 *(undefined4 *)
                                  (*(longlong *)(local_res8 + (longlong)local_48 * 8 + 0x1b08) +
                                  0x1a0));
          local_b0 = (char *)(ulonglong)
                             (*(int *)(*(longlong *)(local_res8 + 0x1b00) + 0x1280 +
                                      (longlong)local_48 * 4) - 1);
        }
        local_a8 = &local_c8;
        local_b8 = (CComboBox *)
                   ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_c8,
                              (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)(local_res8 + 0x1918));
        pCVar6 = FUN_14000fa20(*(longlong *)(pCVar14 + 0x1af8),
                               (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                *)&local_88);
        pCVar7 = FUN_1400210f0((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                *)&local_60);
        pCVar12 = FUN_14002a190(pCVar14,local_50);
        uVar22 = *(undefined8 *)(pCVar14 + 0x1980);
        uVar21 = *(undefined8 *)pCVar6;
        uVar2 = *(undefined8 *)pCVar7;
        local_a8 = (undefined8 **)local_78;
        local_98 = *(char ***)pCVar12;
        local_90 = local_70;
        puVar24 = &DAT_1400466cc;
        puVar18 = &DAT_1400466cc;
        if (*(int *)(local_res8 + 0x1a28) != 0) {
          puVar18 = &DAT_1400466c8;
        }
        puVar20 = &DAT_1400466cc;
        if (*(int *)(local_res8 + 0x19bc) != 0) {
          puVar20 = &DAT_1400466c8;
        }
        if (*(int *)(local_res8 + 0x19b0) != 0) {
          puVar24 = &DAT_1400466c8;
        }
        dVar1 = *(double *)(local_res8 + 0x1988);
        iVar3 = FUN_140009010(*(longlong *)(local_res8 + 0x1b00),
                              (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)local_b8);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                  (local_80,
                   "=== [Lola Info] ===\r\n%s\r\n=== [HW/SW Info] ===\r\n%s\r\nNICs: %sOS: %s\r\n=== [HW/SW Settings] ===\r\n%s\r\nASIO Buffer size: %d samples\r\nCamera File: %s\r\nVideo FpS: %d\r\nOptimize JPEG decompression: %s\r\nSIMD Acceleration: %s\r\nIncomplete frame threshold: %d%%\r\nIP and UDP Advanced Filtering: %s\r\nVideoPacketSize: %d\r\n=== [A/V Buffers] ===\r\nAudio: %d\r\nVideo: %d\r\n"
                   ,local_90,local_98,local_a8,uVar2,uVar21,iVar3,uVar22,(int)dVar1,puVar24,puVar20,
                   *(undefined4 *)(local_res8 + 0x19b8),puVar18,*(undefined4 *)(local_res8 + 0x1a2c)
                   ,(int)local_b0,local_res20._0_4_);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_50);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_60);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_88);
        local_b8 = (CComboBox *)&local_res20;
        local_a8 = &local_c8;
        pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             *)&local_res20,
                            (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             *)&local_a0);
        pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             *)&local_c8,local_68);
        pCVar12 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                              *)&local_b0,local_80);
        FUN_1400329a0((longlong)local_res8,pCVar12,pCVar7,pCVar6);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_80);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_70);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_78);
        goto LAB_14002dcc6;
      }
    }
    else {
      FUN_140030ce0(param_1,pcVar17,uVar21,uVar22);
      if (*(longlong *)(param_1 + 0x2b60) != 0) {
        FUN_140034080(*(longlong *)(param_1 + 0x2b60));
        goto LAB_14002dcc6;
      }
    }
  }
  else {
    FUN_140030ce0(param_1,pcVar17,uVar21,uVar22);
    if (*(longlong *)(param_1 + 0x2b60) != 0) {
      FUN_140033dd0(*(longlong *)(param_1 + 0x2b60));
      goto LAB_14002dcc6;
    }
  }
  pCVar10 = *(CWnd **)(param_1 + 0x3398);
  if (pCVar10 == (CWnd *)0x0) {
    local_res8 = operator_new(0x428);
    if (local_res8 != (CDialog *)0x0) {
      pCVar14 = FUN_140025ea0(local_res8,param_1);
    }
    *(CDialog **)(param_1 + 0x3398) = pCVar14;
    (**(code **)(*(longlong *)pCVar14 + 0x2d8))(pCVar14,0x9a);
    pCVar10 = *(CWnd **)(param_1 + 0x3398);
    if (pCVar10 == (CWnd *)0x0) goto LAB_14002dcc6;
  }
  FUN_140026860(pCVar10);
  iVar3 = CWnd::GetWindowTextLengthA((CWnd *)(*(longlong *)(param_1 + 0x3398) + 0x170));
  if (30000 < iVar3) {
    lVar16 = *(longlong *)(param_1 + 0x3398);
    SendMessageA(*(HWND *)(lVar16 + 0x1b0),0xb1,0,(longlong)(iVar3 + -15000));
    SendMessageA(*(HWND *)(lVar16 + 0x1b0),0xb7,0,0);
    SendMessageA(*(HWND *)(*(longlong *)(param_1 + 0x3398) + 0x1b0),0xc2,0,0x1400439ac);
    iVar3 = CWnd::GetWindowTextLengthA((CWnd *)(*(longlong *)(param_1 + 0x3398) + 0x170));
  }
  lVar16 = *(longlong *)(param_1 + 0x3398);
  SendMessageA(*(HWND *)(lVar16 + 0x1b0),0xb1,(longlong)iVar3,(longlong)iVar3);
  SendMessageA(*(HWND *)(lVar16 + 0x1b0),0xb7,0,0);
  SendMessageA(*(HWND *)(*(longlong *)(param_1 + 0x3398) + 0x1b0),0xc2,0,local_c0);
LAB_14002dcc6:
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_c0)
  ;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_a0)
  ;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_58);
  return 0;
}

