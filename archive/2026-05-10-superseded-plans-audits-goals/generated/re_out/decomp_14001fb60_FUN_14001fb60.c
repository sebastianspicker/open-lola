
undefined8
FUN_14001fb60(longlong param_1,int param_2,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_3,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_4,
             undefined4 param_5,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_6)

{
  undefined2 uVar1;
  longlong lVar2;
  code *pcVar3;
  int iVar4;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar5;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar6;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar7;
  undefined8 uVar8;
  char *pcVar9;
  undefined4 uVar10;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_res8 [16];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_res18;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_res20;
  undefined8 in_stack_ffffffffffffff40;
  undefined4 uVar11;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_78 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_70;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_68;
  undefined8 local_60;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_58;
  uint uStack_50;
  undefined4 uStack_4c;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_48;
  uint uStack_40;
  undefined4 uStack_3c;
  
  uVar11 = (undefined4)((ulonglong)in_stack_ffffffffffffff40 >> 0x20);
  local_60 = 0xfffffffffffffffe;
  local_res18 = param_3;
  local_res20 = param_4;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res8,"");
  uVar10 = 0;
  if ((*(longlong *)(param_1 + 0xa0) != 0) &&
     (uVar10 = 0, *(int *)(*(longlong *)(param_1 + 0xa0) + 0x10dc) == 8)) {
    uVar10 = 1;
  }
  switch(param_2) {
  case 0x800c:
    lVar2 = *(longlong *)(param_1 + 0x98);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
              (local_res8,
               "/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d"
               ,*(undefined8 *)param_3,*(undefined8 *)param_4,param_5,
               CONCAT44(uVar11,(int)*(double *)(lVar2 + 0x28)),*(undefined4 *)(lVar2 + 0x30),
               *(undefined4 *)(lVar2 + 0x34),(int)*(double *)(lVar2 + 0x78),
               *(undefined4 *)(lVar2 + 0x88),*(undefined4 *)(lVar2 + 0x8c),
               *(undefined4 *)(lVar2 + 0x90),*(undefined4 *)(lVar2 + 0x98),uVar10);
    goto LAB_14001fd89;
  case 0x800d:
    pcVar9 = "/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;";
    break;
  default:
    AfxMessageBox("CLolaLibController: type of message unknown.",0,0);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res8);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_3);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_4);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_6);
    return 0;
  case 0x800f:
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
              (local_res8,"/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s",*(undefined8 *)param_3,
               *(undefined8 *)param_4,param_5,*(undefined8 *)param_6);
    goto LAB_14001fd89;
  case 0x8010:
    lVar2 = *(longlong *)(param_1 + 0x98);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
              (local_res8,
               "/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d"
               ,*(undefined8 *)param_3,*(undefined8 *)param_4,param_5,
               CONCAT44(uVar11,(int)*(double *)(lVar2 + 0x28)),*(undefined4 *)(lVar2 + 0x30),
               *(undefined4 *)(lVar2 + 0x34),(int)*(double *)(lVar2 + 0x78),
               *(undefined4 *)(lVar2 + 0x88),*(undefined4 *)(lVar2 + 0x8c),
               *(undefined4 *)(lVar2 + 0x90),*(undefined4 *)(lVar2 + 0x98),uVar10);
    goto LAB_14001fd89;
  case 0x8012:
    pcVar9 = "/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;";
    break;
  case 0x8013:
    pcVar9 = "/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;";
    break;
  case 0x8014:
    pcVar9 = "/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;";
    break;
  case 0x8015:
    pcVar9 = "/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;";
    break;
  case 0x8016:
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
              (local_res8,"/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s",*(undefined8 *)param_3,
               *(undefined8 *)param_4,param_5,*(undefined8 *)param_6);
    goto LAB_14001fd89;
  case 0x8017:
    pcVar9 = "/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d";
    break;
  case 0x8018:
    pcVar9 = "/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d";
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
            (local_res8,pcVar9,*(undefined8 *)param_3,*(undefined8 *)param_4,param_5);
LAB_14001fd89:
  *(undefined2 *)(param_1 + 0x60) = 0;
  if (param_2 != 0x8016) {
    local_58 = local_78;
    local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               &local_70;
    pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       (local_78,local_res8);
    pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_70,param_4);
    pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                       ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_68,param_3);
    FUN_14001ffa0(pCVar7,pCVar6,*(u_short *)(*(longlong *)(param_1 + 0x98) + 0xf8),pCVar5);
LAB_14001febc:
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_res8);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_3);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_4);
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_6);
    return 1;
  }
  uVar1 = *(undefined2 *)(*(longlong *)(param_1 + 0x98) + 0xf8);
  pCVar5 = operator_new(0x28);
  if (pCVar5 == (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)0x0) {
    pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)0x0;
  }
  else {
    local_68 = pCVar5;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(pCVar5,local_res8);
    *(undefined2 *)(pCVar5 + 8) = uVar1;
    local_70 = pCVar5 + 0x10;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70,param_4);
    local_70 = pCVar5 + 0x18;
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_70,param_3);
    *(code **)(pCVar5 + 0x20) = FUN_14001ffa0;
  }
  local_68 = pCVar5;
  local_48 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             _beginthreadex((void *)0x0,0,FUN_14001ee40,pCVar5,0,&uStack_40);
  if (local_48 != (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)0x0)
  {
    if (uStack_40 == 0) goto LAB_14001ff54;
    uStack_50 = uStack_40;
    uStack_4c = uStack_3c;
    local_58 = local_48;
    iVar4 = _Thrd_detach(&local_58);
    if (iVar4 == 0) goto LAB_14001febc;
    std::_Throw_C_error(iVar4);
  }
  uStack_40 = 0;
  std::_Throw_Cpp_error(6);
LAB_14001ff54:
  std::_Throw_Cpp_error(1);
  pcVar3 = (code *)swi(3);
  uVar8 = (*pcVar3)();
  return uVar8;
}

