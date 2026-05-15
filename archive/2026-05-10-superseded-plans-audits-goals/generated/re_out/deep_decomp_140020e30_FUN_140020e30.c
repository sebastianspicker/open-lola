
CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
FUN_140020e30(longlong param_1,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *param_2,
             undefined8 param_3,undefined8 param_4)

{
  double dVar1;
  LARGE_INTEGER local_res8;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_res10;
  
  local_res10 = param_2;
  QueryPerformanceCounter((LARGE_INTEGER *)(param_1 + 0x10));
  QueryPerformanceFrequency(&local_res8);
  dVar1 = ((double)(*(longlong *)(param_1 + 0x10) - *(longlong *)(param_1 + 8)) /
          (double)local_res8.QuadPart) * DAT_1400439f0;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(param_2);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
            (param_2,"%.3f ms",SUB84(dVar1,0));
  return param_2;
}

