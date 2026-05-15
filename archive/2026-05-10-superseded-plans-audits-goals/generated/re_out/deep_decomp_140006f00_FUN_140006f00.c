
void FUN_140006f00(longlong param_1,undefined4 param_2,uint param_3,undefined4 param_4)

{
  uint uVar1;
  void *pvVar2;
  ulonglong uVar3;
  
  *(uint *)(param_1 + 0xc) = param_3;
  *(undefined4 *)(param_1 + 8) = param_2;
  *(undefined4 *)(param_1 + 0x10) = param_4;
  if (*(uint *)(param_1 + 0x20) < param_3) {
    free(*(void **)(param_1 + 0x18));
    *(uint *)(param_1 + 0x20) = param_3;
    pvVar2 = operator_new((ulonglong)param_3);
    param_3 = *(uint *)(param_1 + 0xc);
    *(void **)(param_1 + 0x18) = pvVar2;
  }
  memset(*(void **)(param_1 + 0x18),0,(ulonglong)param_3);
  FUN_140007320((undefined8 *)(param_1 + 0x28),*(uint *)(param_1 + 0x10));
  uVar1 = 0;
  if (*(int *)(param_1 + 0x34) != 0) {
    do {
      uVar3 = (ulonglong)uVar1;
      uVar1 = uVar1 + 1;
      *(undefined1 *)(uVar3 + *(longlong *)(param_1 + 0x28)) = 0;
    } while (uVar1 < *(uint *)(param_1 + 0x34));
  }
  *(undefined4 *)(param_1 + 0x40) = 0;
  return;
}

