
void FUN_140006df0(longlong *param_1,undefined8 *param_2)

{
  uint uVar1;
  
  uVar1 = *(uint *)((longlong)param_1 + 0xc);
  if (uVar1 == *(uint *)(param_1 + 1)) {
    FUN_140006f90(param_1,(int)param_1[2] + *(uint *)(param_1 + 1));
    uVar1 = *(uint *)((longlong)param_1 + 0xc);
  }
  *(undefined8 *)(*param_1 + (ulonglong)uVar1 * 8) = *param_2;
  *(int *)((longlong)param_1 + 0xc) = *(int *)((longlong)param_1 + 0xc) + 1;
  return;
}

