
void FUN_14001f390(longlong param_1,
                  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_2
                  )

{
  int iVar1;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar2;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar3;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar4;
  CWinThread *pCVar5;
  longlong lVar6;
  longlong lVar7;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_res18 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_res20 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_78 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_70;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_68 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_60 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> **local_58;
  undefined8 local_50;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_48;
  
  local_50 = 0xfffffffffffffffe;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (*(longlong *)(param_1 + 0x38) + 0x58),param_2);
  local_58 = &local_70;
  pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_70,"SRCIP:");
  pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     (local_68,param_2);
  FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_res20,pCVar3,pCVar2);
  local_48 = local_60;
  pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     (local_60,"DSTIP:");
  pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_58,param_2);
  FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_78,pCVar3,pCVar2);
  lVar7 = 0;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Tokenize
            (param_2,(char *)local_res18,(int *)&DAT_140044088);
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_CHECKLOLASTATUS");
  if (iVar1 == 0) {
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    local_70 = local_60;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,local_res20);
    pCVar4 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_68,local_78);
    FUN_14001fb60(*(longlong *)(param_1 + 0x38),0x8013,pCVar4,pCVar3,0,pCVar2);
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_CHECKLOLASTATUS_ACK");
  if (iVar1 == 0) {
    *(undefined1 *)(*(longlong *)(param_1 + 0x38) + 0x60) = 1;
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_QUICKCONN");
  if (iVar1 == 0) {
    pCVar5 = AfxGetThread();
    lVar6 = lVar7;
    if (pCVar5 != (CWinThread *)0x0) {
      lVar6 = (**(code **)(*(longlong *)pCVar5 + 0xf8))(pCVar5);
    }
    SendMessageA(*(HWND *)(lVar6 + 0x40),0x8002,0,0);
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_QUICKCONN_ACK");
  if (iVar1 == 0) {
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"CHNLS:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(int *)(*(longlong *)(param_1 + 0x38) + 100) = iVar1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"FPS:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(double *)(*(longlong *)(param_1 + 0x38) + 0x68) = (double)iVar1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"BPP:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(int *)(*(longlong *)(param_1 + 0x38) + 0x70) = iVar1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"X:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(int *)(*(longlong *)(param_1 + 0x38) + 0x74) = iVar1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"Y:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(int *)(*(longlong *)(param_1 + 0x38) + 0x78) = iVar1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"SR:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(double *)(*(longlong *)(param_1 + 0x38) + 0x80) = (double)iVar1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"BPS:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(int *)(*(longlong *)(param_1 + 0x38) + 0x88) = iVar1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"COMP:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(int *)(*(longlong *)(param_1 + 0x38) + 0x8c) = iVar1;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"BAYER:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    iVar1 = atoi(*(char **)pCVar2);
    *(bool *)(*(longlong *)(param_1 + 0x38) + 0x90) = iVar1 != 0;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               (*(longlong *)(param_1 + 0x38) + 0x40),local_res20);
    *(undefined1 *)(*(longlong *)(param_1 + 0x38) + 0x61) = 1;
    *(undefined1 *)(*(longlong *)(param_1 + 0x38) + 0x60) = 1;
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_DISCONNECT");
  if (iVar1 == 0) {
    pCVar5 = AfxGetThread();
    lVar6 = lVar7;
    if (pCVar5 != (CWinThread *)0x0) {
      lVar6 = (**(code **)(*(longlong *)pCVar5 + 0xf8))(pCVar5);
    }
    SendMessageA(*(HWND *)(lVar6 + 0x40),0x8003,0,0);
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_REJECT");
  if (iVar1 == 0) {
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"TXT:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               (*(longlong *)(param_1 + 0x38) + 0xb0),pCVar2);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    *(undefined1 *)(*(longlong *)(param_1 + 0x38) + 0x61) = 0;
    *(undefined1 *)(*(longlong *)(param_1 + 0x38) + 0x60) = 1;
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_SWITCH_ON_BB");
  if (iVar1 == 0) {
    pCVar5 = AfxGetThread();
    lVar6 = lVar7;
    if (pCVar5 != (CWinThread *)0x0) {
      lVar6 = (**(code **)(*(longlong *)pCVar5 + 0xf8))(pCVar5);
    }
    SendMessageA(*(HWND *)(lVar6 + 0x40),0x8005,0,0);
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_SWITCH_OFF_BB");
  if (iVar1 == 0) {
    pCVar5 = AfxGetThread();
    lVar6 = lVar7;
    if (pCVar5 != (CWinThread *)0x0) {
      lVar6 = (**(code **)(*(longlong *)pCVar5 + 0xf8))(pCVar5);
    }
    SendMessageA(*(HWND *)(lVar6 + 0x40),0x8005,0,0);
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_SEND_AUDIO_SIGNAL");
  if (iVar1 == 0) {
    pCVar5 = AfxGetThread();
    lVar6 = lVar7;
    if (pCVar5 != (CWinThread *)0x0) {
      lVar6 = (**(code **)(*(longlong *)pCVar5 + 0xf8))(pCVar5);
    }
    SendMessageA(*(HWND *)(lVar6 + 0x40),0x8007,0,0);
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_STOP_AUDIO_SIGNAL");
  if (iVar1 == 0) {
    pCVar5 = AfxGetThread();
    lVar6 = lVar7;
    if (pCVar5 != (CWinThread *)0x0) {
      lVar6 = (**(code **)(*(longlong *)pCVar5 + 0xf8))(pCVar5);
    }
    SendMessageA(*(HWND *)(lVar6 + 0x40),0x8008,0,0);
  }
  iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                    (local_res18,"/MESG_CHAT");
  if (iVar1 == 0) {
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_58;
    pCVar2 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_58,"TXT:");
    pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_60,param_2);
    pCVar2 = FUN_14001f270(*(undefined8 *)(param_1 + 0x38),local_68,pCVar3,pCVar2);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               (*(longlong *)(param_1 + 0x38) + 0xa8),pCVar2);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_68);
    pCVar5 = AfxGetThread();
    if (pCVar5 != (CWinThread *)0x0) {
      lVar7 = (**(code **)(*(longlong *)pCVar5 + 0xf8))(pCVar5);
    }
    SendMessageA(*(HWND *)(lVar7 + 0x40),0x8006,0,0);
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res18);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_78);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res20);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_2);
  return;
}

