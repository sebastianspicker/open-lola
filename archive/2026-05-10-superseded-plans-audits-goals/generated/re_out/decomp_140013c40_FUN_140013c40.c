
void FUN_140013c40(longlong param_1)

{
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar1;
  undefined4 local_res8 [2];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_res10 [24];
  
  pCVar1 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
           ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
           CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     (local_res10,".\\CAMERAFILES\\Ximea.ini");
  FUN_14000f710(param_1,pCVar1);
  local_res8[0] = 0;
  xiGetNumberDevices(local_res8);
  *(undefined4 *)(param_1 + 0x404) = local_res8[0];
  return;
}

