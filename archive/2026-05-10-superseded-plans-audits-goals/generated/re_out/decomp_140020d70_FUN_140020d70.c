
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_140020d70(undefined8 *param_1,longlong param_2)

{
  undefined8 uVar1;
  undefined1 auStack_148 [32];
  undefined8 local_128;
  undefined1 *local_120;
  undefined1 local_118 [256];
  ulonglong local_18;
  
  local_18 = DAT_1400630d8 ^ (ulonglong)auStack_148;
  local_120 = local_118;
  local_128 = 0;
  uVar1 = pcap_open(*(undefined8 *)(param_2 + 8),0xffff,0x10);
  pcap_sendpacket(uVar1,*param_1,*(int *)(param_1 + 1) + 0x2a);
  pcap_close(uVar1);
  return;
}

