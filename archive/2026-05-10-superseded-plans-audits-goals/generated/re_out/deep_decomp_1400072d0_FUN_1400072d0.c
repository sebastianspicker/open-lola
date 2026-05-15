
void FUN_1400072d0(undefined8 *param_1,uint param_2)

{
  if (param_2 < *(uint *)(param_1 + 1)) {
    *(uint *)((longlong)param_1 + 0xc) = param_2;
    return;
  }
  do {
    FUN_140006f90(param_1,*(int *)(param_1 + 2) + *(int *)(param_1 + 1));
  } while (*(uint *)(param_1 + 1) <= param_2);
  *(uint *)((longlong)param_1 + 0xc) = param_2;
  return;
}

