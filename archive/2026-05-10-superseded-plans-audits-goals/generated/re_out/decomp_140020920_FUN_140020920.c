
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_140020920(void)

{
  basic_ostream<char,struct_std::char_traits<char>_> *pbVar1;
  int iVar2;
  undefined1 auStack_148 [32];
  longlong *local_128 [2];
  undefined1 local_118 [256];
  ulonglong local_18;
  
  local_18 = DAT_1400630d8 ^ (ulonglong)auStack_148;
  pcap_findalldevs_ex("rpcap://",0,local_128,local_118);
  iVar2 = 1;
  for (; local_128[0] != (longlong *)0x0; local_128[0] = (longlong *)*local_128[0]) {
    pbVar1 = std::basic_ostream<char,struct_std::char_traits<char>_>::operator<<
                       ((basic_ostream<char,struct_std::char_traits<char>_> *)cout_exref,iVar2);
    pbVar1 = FUN_1400202f0(pbVar1,". ");
    pbVar1 = FUN_1400202f0(pbVar1,(char *)local_128[0][2]);
    std::basic_ostream<char,struct_std::char_traits<char>_>::operator<<(pbVar1,FUN_1400204c0);
    iVar2 = iVar2 + 1;
  }
  return;
}

