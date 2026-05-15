
/* WARNING: Function: _alloca_probe replaced with injection: alloca_probe */
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_140020110(longlong param_1)

{
  int iVar1;
  SOCKET SVar2;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar3;
  undefined1 auStackY_10a8 [32];
  int local_1078 [2];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_1070 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_1068 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_1060 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_1058 [8];
  undefined8 local_1050;
  sockaddr local_1040;
  sockaddr local_1030;
  char local_1018 [4096];
  ulonglong local_18;
  undefined8 uStack_10;
  
  uStack_10 = 0x14002011c;
  local_1050 = 0xfffffffffffffffe;
  local_18 = DAT_1400630d8 ^ (ulonglong)auStackY_10a8;
  ResetEvent(*(HANDLE *)(param_1 + 0x58));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_1058);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_1060);
  local_1078[0] = 0x10;
  SVar2 = socket(2,2,0x11);
  *(int *)(param_1 + 0x60) = (int)SVar2;
  if ((int)SVar2 == -1) {
    AfxMessageBox("Winsock error: Unable to start listening socket",0,0);
  }
  else {
    local_1040.sa_family = 2;
    local_1040.sa_data._0_2_ = htons(*(u_short *)(param_1 + 0x30));
    local_1040.sa_data._2_4_ = htonl(0);
    iVar1 = bind((ulonglong)*(uint *)(param_1 + 0x60),&local_1040,0x10);
    if (iVar1 == 0) {
      *(undefined1 *)(param_1 + 100) = 0;
      do {
        iVar1 = recvfrom((ulonglong)*(uint *)(param_1 + 0x60),local_1018,0x1000,0,&local_1030,
                         local_1078);
        if (iVar1 == -1) {
          iVar1 = WSAGetLastError();
          if (iVar1 == 0x2714) break;
        }
        else {
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                    (local_1070,local_1018);
          iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                  Find(local_1070,"/MESG_",0);
          if (iVar1 == 0) {
            pCVar3 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               (local_1068,local_1070);
            FUN_14001f390(param_1,pCVar3);
          }
          ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
          ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_1070);
        }
      } while (*(char *)(param_1 + 100) == '\0');
      SetEvent(*(HANDLE *)(param_1 + 0x58));
    }
    else {
      AfxMessageBox("Winsock error: Bind failed",0,0);
    }
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_1060);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_1058);
  return;
}

