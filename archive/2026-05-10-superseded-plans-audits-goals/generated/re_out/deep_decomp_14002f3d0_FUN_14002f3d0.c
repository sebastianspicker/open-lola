
undefined8 FUN_14002f3d0(CWnd *param_1)

{
  void *pvVar1;
  longlong lVar2;
  int iVar3;
  int iVar4;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar5;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar6;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar7;
  undefined8 uVar8;
  CSimpleStringT<char,1> *pCVar9;
  IAtlStringMgr *pIVar10;
  undefined8 *puVar11;
  longlong lVar12;
  CWnd *pCVar14;
  int iVar15;
  int iVar16;
  CWnd *pCVar17;
  longlong lVar18;
  undefined8 *local_res8;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_res20 [8];
  undefined8 ***local_78;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_70 [8];
  undefined8 *local_68;
  char *local_60;
  char *local_58;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_50 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_48 [8];
  undefined8 ***local_40;
  undefined8 local_38;
  undefined8 ***local_30;
  longlong lVar13;
  
  local_38 = 0xfffffffffffffffe;
  iVar15 = 0;
  local_res8._0_4_ = 0;
  *(undefined4 *)(param_1 + 0x1aa4) = 0;
  *(undefined4 *)(param_1 + 0x1abc) = 0;
  if (param_1[0x1b1a] != (CWnd)0x0) {
    FUN_14002cd70(param_1);
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            (local_res20,
             (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (*(longlong *)(param_1 + 0x1908) + 0x58));
  local_78 = (undefined8 ***)&local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"SRCIP:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     (local_70,local_res20);
  FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),
                (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                &local_60,pCVar6,pCVar5);
  local_78 = &local_40;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_40,"DSTIP:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     (local_50,local_res20);
  FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),
                (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                &local_58,pCVar6,pCVar5);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"SID:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     (local_70,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),
                         (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          *)&local_78,pCVar6,pCVar5);
  iVar3 = atoi(*(char **)pCVar5);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_78)
  ;
  iVar16 = 0;
  pCVar14 = param_1 + 0x1ae8;
  pCVar17 = pCVar14;
  do {
    if ((*(char *)(*(longlong *)pCVar17 + 0x24c) == '\0') &&
       (lVar18 = *(longlong *)(*(longlong *)pCVar17 + 0x328), lVar18 != 0)) {
      iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
              Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      (lVar18 + 0x18),local_58);
      if (iVar4 == 0) goto LAB_14002f600;
    }
    iVar16 = iVar16 + 1;
    pCVar17 = pCVar17 + 8;
  } while (iVar16 < 2);
  local_68 = &local_res8;
  local_30 = &local_78;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"Lola is running but it is currently busy.\nPlease retry later.");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,
                      (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_60);
  pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     (local_70,(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                *)&local_58);
  FUN_14001fb60(*(longlong *)(param_1 + 0x1908),0x800f,pCVar7,pCVar6,iVar3,pCVar5);
  goto LAB_14002f5c1;
LAB_14002f600:
  do {
    if (*(longlong *)(*(longlong *)pCVar14 + 0x328) != 0) {
      iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
              Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      (*(longlong *)(*(longlong *)pCVar14 + 0x328) + 0x18),local_58);
      if (iVar4 == 0) {
        iVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )(*(longlong *)pCVar14 + 0x48),local_60);
        if (iVar4 == 0) goto LAB_14002f5c1;
      }
    }
    iVar15 = iVar15 + 1;
    pCVar14 = pCVar14 + 8;
  } while (iVar15 < 2);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"CHNLS:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  lVar18 = (longlong)iVar16;
  iVar15 = atoi(*(char **)pCVar5);
  *(int *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2b0) = iVar15;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"FPS:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  iVar15 = atoi(*(char **)pCVar5);
  *(double *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2b8) = (double)iVar15;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"BPP:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  iVar15 = atoi(*(char **)pCVar5);
  *(int *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2c0) = iVar15;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"X:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  iVar15 = atoi(*(char **)pCVar5);
  *(int *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2c4) = iVar15;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"Y:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  iVar15 = atoi(*(char **)pCVar5);
  *(int *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2c8) = iVar15;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"SR:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  iVar15 = atoi(*(char **)pCVar5);
  *(double *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2d0) = (double)iVar15;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"BPS:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  iVar15 = atoi(*(char **)pCVar5);
  *(int *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2d8) = iVar15;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"COMP:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  iVar15 = atoi(*(char **)pCVar5);
  *(int *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2dc) = iVar15;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  local_68 = &local_res8;
  pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,"BAYER:");
  pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_78,local_res20);
  pCVar5 = FUN_14001f270(*(undefined8 *)(param_1 + 0x1908),local_70,pCVar6,pCVar5);
  iVar15 = atoi(*(char **)pCVar5);
  *(bool *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2e0) = iVar15 != 0;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_48,"");
  uVar8 = FUN_140029150((longlong)param_1,*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8),'\0',local_48
                       );
  local_68 = &local_res8;
  local_40 = &local_78;
  if ((char)uVar8 == '\0') {
    pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_res8,local_48);
    pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_78,
                        (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_60);
    pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_50,(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                  *)&local_58);
    FUN_14001fb60(*(longlong *)(param_1 + 0x1908),0x800f,pCVar7,pCVar6,iVar3,pCVar5);
  }
  else {
    pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_res8,"");
    pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_78,
                        (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_60);
    pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_50,(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                  *)&local_58);
    FUN_14001fb60(*(longlong *)(param_1 + 0x1908),0x8010,pCVar7,pCVar6,iVar3,pCVar5);
    *(undefined1 *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2ad) = 1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               (*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x48),
               (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_60);
    lVar13 = *(longlong *)(param_1 + lVar18 * 8 + 0x1ae8);
    FUN_14000db40(*(longlong *)(param_1 + lVar18 * 8 + 0x1b08),*(undefined8 *)(lVar13 + 0x2b8),
                  *(int *)(lVar13 + 0x2c4),*(int *)(lVar13 + 0x2c8),*(uint *)(lVar13 + 0x2c0));
    pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_res8,
                        (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x48));
    FUN_14000d440(*(longlong *)(param_1 + lVar18 * 8 + 0x1b08),
                  *(undefined4 *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2dc),
                  *(undefined4 *)(param_1 + 0x19b0),*(undefined4 *)(param_1 + 0x19bc),
                  *(undefined4 *)(param_1 + 0x19c4),
                  (uint)*(byte *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x2e0),
                  *(int *)(param_1 + 0x19c8),*(int *)(param_1 + 0x19cc),pCVar5);
    FUN_14000d7e0(*(void **)(param_1 + lVar18 * 8 + 0x1b08));
    local_68 = &local_res8;
    pCVar9 = (CSimpleStringT<char,1> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_res8,
                        (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_60);
    iVar15 = FUN_140029e60((longlong)param_1,iVar16);
    FUN_14000a000(*(void **)(param_1 + 0x1b00),iVar16,
                  *(longlong *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x328),pCVar9,
                  *(undefined2 *)(param_1 + 0x1a10),iVar15);
    if (0 < *(int *)(param_1 + 0x1b38)) {
      pCVar9 = (CSimpleStringT<char,1> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_res8,
                          (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_60);
      FUN_140012490(*(void **)(param_1 + 0x1af8),iVar16,
                    *(longlong *)(*(longlong *)(param_1 + lVar18 * 8 + 0x1ae8) + 0x328),pCVar9,
                    *(undefined2 *)(param_1 + 0x1a0c),*(undefined4 *)(param_1 + 0x1a2c));
    }
    pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_res8,
                        (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_60);
    pvVar1 = *(void **)(param_1 + lVar18 * 8 + 0x1ae8);
    FUN_140016f20(pvVar1,*(longlong *)((longlong)pvVar1 + 0x328),pCVar5,
                  *(undefined4 *)((longlong)pvVar1 + 0x2dc));
    param_1[lVar18 + 0x1b18] = (CWnd)0x1;
    FUN_140032dd0(param_1);
    lVar18 = lVar18 * 0xa78;
    CWnd::SetWindowTextA(param_1 + lVar18 + 0x668,local_60);
    CWnd::SetWindowTextA(param_1 + lVar18 + 0x838,"Disconnect");
    FUN_140032fd0((longlong)param_1,iVar16,2);
    CWnd::EnableWindow(param_1 + lVar18 + 0x580,0);
    CWnd::EnableWindow(param_1 + lVar18 + 0x668,0);
    CWnd::EnableWindow(param_1 + lVar18 + 0xda8,0);
    pIVar10 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
              GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          *)&local_60);
    puVar11 = (undefined8 *)
              ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
              CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                        (local_70,pIVar10);
    local_res8._0_4_ = 1;
    lVar13 = -1;
    do {
      lVar12 = lVar13 + 1;
      lVar2 = lVar13 + 1;
      lVar13 = lVar12;
    } while ("Connected to "[lVar2] != '\0');
    ATL::CSimpleStringT<char,1>::Concatenate
              ((CSimpleStringT<char,1> *)local_70,"Connected to ",(int)lVar12,local_60,
               *(int *)(local_60 + -0x10));
    CWnd::SetWindowTextA(param_1 + lVar18 + 0x920,(char *)*puVar11);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70);
    FUN_140033260((longlong *)param_1);
    CWnd::SetFocus(param_1);
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_48);
LAB_14002f5c1:
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_58)
  ;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_60)
  ;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res20);
  return 0;
}

