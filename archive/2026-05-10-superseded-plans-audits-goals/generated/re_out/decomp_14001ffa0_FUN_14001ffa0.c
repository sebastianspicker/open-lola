
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

undefined8
FUN_14001ffa0(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_1,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_2,
             u_short param_3,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_4)

{
  int iVar1;
  SOCKET SVar2;
  ulonglong s;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar3;
  undefined1 auStackY_498 [32];
  undefined8 local_468;
  sockaddr local_458;
  char local_448 [1024];
  ulonglong local_48;
  
  local_48 = DAT_1400630d8 ^ (ulonglong)auStackY_498;
  pCVar3 = param_4;
  local_468 = param_4;
  SVar2 = socket(2,2,0x11);
  if ((int)SVar2 != -1) {
    local_458.sa_family = 2;
    local_458.sa_data._0_2_ = htons(param_3);
    inet_pton(2,*(undefined8 *)param_2,local_458.sa_data + 2);
    local_468._0_2_ = 2;
    inet_pton(2,*(undefined8 *)param_1,(longlong)&local_468 + 4);
    s = SVar2 & 0xffffffff;
    local_468._0_4_ = (uint)(u_short)local_468;
    bind(s,(sockaddr *)&local_468,0x10);
    FUN_1400062f0(local_448,&DAT_140044fe4,*(undefined8 *)param_4,pCVar3);
    iVar1 = sendto(SVar2 & 0xffffffff,local_448,0x400,0,&local_458,0x10);
    if (iVar1 == -1) {
      closesocket(s);
    }
    else {
      iVar1 = closesocket(s);
      if (iVar1 != -1) {
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_1);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_2);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_4);
        return 0;
      }
    }
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_1);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_2);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_4);
  return 1;
}

