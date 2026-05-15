
void FUN_140007250(longlong param_1,uint param_2)

{
  uint uVar1;
  ulonglong uVar2;
  
  *(uint *)(param_1 + 0xc) = param_2;
  if (param_2 < 0x80) {
    *(undefined4 *)(param_1 + 0xc) = 0x80;
  }
  else {
    if (0x2000 < param_2) {
      param_2 = 0x2000;
    }
    *(uint *)(param_1 + 0xc) = param_2;
  }
  uVar2 = 0;
  if (*(int *)(param_1 + 0x24) != 0) {
    do {
      free(*(void **)(*(longlong *)(param_1 + 0x18) + uVar2 * 8));
      uVar1 = (int)uVar2 + 1;
      uVar2 = (ulonglong)uVar1;
    } while (uVar1 < *(uint *)(param_1 + 0x24));
  }
  FUN_1400072d0((undefined8 *)(param_1 + 0x18),0);
  return;
}

