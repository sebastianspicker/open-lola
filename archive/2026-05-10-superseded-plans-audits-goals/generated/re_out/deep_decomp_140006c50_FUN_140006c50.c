
undefined8 * FUN_140006c50(undefined8 *param_1)

{
  *param_1 = flFMTDataEncoder::vftable;
  FUN_140006b90(param_1 + 3);
  *(undefined4 *)(param_1 + 1) = 0;
  *(undefined8 *)((longlong)param_1 + 0xc) = 0x400;
  FUN_1400072d0(param_1 + 3,0);
  FUN_140006f90(param_1 + 3,0x400);
  *(undefined4 *)(param_1 + 5) = 0x400;
  return param_1;
}

