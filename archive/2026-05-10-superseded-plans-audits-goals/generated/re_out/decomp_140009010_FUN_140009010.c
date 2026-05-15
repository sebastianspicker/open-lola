
int FUN_140009010(longlong param_1,
                 CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_2)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  undefined8 *puVar4;
  int local_res8 [2];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_res10;
  int local_res18 [2];
  undefined1 local_res20 [8];
  undefined1 local_48 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_40 [8];
  undefined8 local_38;
  
  local_38 = 0xfffffffffffffffe;
  iVar2 = 0;
  local_res10 = param_2;
  if ((*(int *)(param_1 + 0xa0) != 0) &&
     (iVar1 = Pa_IsStreamActive(*(undefined8 *)(param_1 + 0x90)), iVar2 = 0, iVar1 != 0)) {
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_40,param_2);
    iVar2 = -1;
    iVar1 = 0;
    if (0 < *(int *)(param_1 + 0xbc)) {
      puVar4 = (undefined8 *)(param_1 + 200);
      do {
        if (iVar2 == 0) break;
        iVar2 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                Compare(local_40,(char *)*puVar4);
        iVar1 = iVar1 + 1;
        puVar4 = puVar4 + 1;
      } while (iVar1 < *(int *)(param_1 + 0xbc));
    }
    uVar3 = Pa_HostApiDeviceIndexToDeviceIndex(*(undefined4 *)(param_1 + 0xb8),iVar1 + -1);
    PaAsio_GetAvailableBufferSizes(uVar3,local_res18,local_48,local_res8,local_res20);
    iVar2 = local_res8[0];
    if ((local_res8[0] < 1) && (iVar2 = 0, 0 < local_res18[0])) {
      iVar2 = local_res18[0];
    }
    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
    ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_40);
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_2);
  return iVar2;
}

