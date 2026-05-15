
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

undefined8 FUN_140007520(void)

{
  longlong lVar1;
  int iVar2;
  ulonglong uVar3;
  undefined4 extraout_var;
  undefined4 extraout_var_00;
  char *pcVar4;
  undefined8 uVar5;
  undefined1 auStack_548 [32];
  undefined1 *local_528;
  undefined4 local_520;
  undefined4 local_518;
  char *local_508;
  longlong local_500;
  timecaps_tag local_4f8;
  undefined8 local_4f0;
  undefined8 local_4e8;
  undefined8 uStack_4e0;
  undefined8 local_4d8;
  undefined8 uStack_4d0;
  undefined8 local_4c8;
  undefined8 uStack_4c0;
  WSADATA local_4b8;
  char local_318 [256];
  char local_218 [256];
  undefined1 local_118 [256];
  ulonglong local_18;
  
  local_4f0 = 0xfffffffffffffffe;
  uVar3 = DAT_1400630d8 ^ (ulonglong)auStack_548;
  if (DAT_140063d30 == 0) {
    local_18 = uVar3;
    iVar2 = WSAStartup(2,&local_4b8);
    uVar3 = CONCAT44(extraout_var,iVar2);
    if (((iVar2 != 0) || (uVar3 = (ulonglong)local_4b8.wVersion, (char)local_4b8.wVersion != '\x02')
        ) || (uVar3 = 0, (char)(local_4b8.wVersion >> 8) != '\0')) {
      return uVar3 & 0xffffffffffffff00;
    }
    timeGetDevCaps(&local_4f8,8);
    timeBeginPeriod(local_4f8.wPeriodMin);
    iVar2 = gethostname(local_318,0x100);
    uVar3 = CONCAT44(extraout_var_00,iVar2);
    if (iVar2 == 0) {
      local_4d8 = 0;
      uStack_4d0 = 0;
      local_4c8 = 0;
      uStack_4c0 = 0;
      local_4e8 = 0x200000000;
      uStack_4e0 = 1;
      uVar3 = getaddrinfo(local_318,0,&local_4e8,&local_500);
      lVar1 = local_500;
      if ((int)uVar3 == 0) {
        while (lVar1 != 0) {
          local_518 = 10;
          local_520 = 0x100;
          local_528 = local_118;
          uVar5 = 0x100;
          pcVar4 = local_218;
          getnameinfo(*(undefined8 *)(lVar1 + 0x20),*(undefined4 *)(lVar1 + 0x10));
          lVar1 = *(longlong *)(lVar1 + 0x28);
          local_508 = (char *)0x0;
          FUN_140005870((longlong *)&local_508,local_218,pcVar4,uVar5);
          FUN_140005870((longlong *)&DAT_140063d38,local_508,pcVar4,uVar5);
          thunk_FUN_140005e90(&local_508);
        }
        uVar3 = freeaddrinfo(local_500);
      }
    }
  }
  DAT_140063d30 = DAT_140063d30 + 1;
  return CONCAT71((int7)(uVar3 >> 8),1);
}

