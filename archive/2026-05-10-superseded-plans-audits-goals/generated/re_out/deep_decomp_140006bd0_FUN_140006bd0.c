
undefined8 * FUN_140006bd0(undefined8 *param_1)

{
  *param_1 = flFMTDataDecoder::vftable;
  FUN_140006bb0(param_1 + 5);
  param_1[1] = 0;
  *(undefined4 *)(param_1 + 2) = 0;
  param_1[3] = 0;
  *(undefined4 *)(param_1 + 4) = 0;
  FUN_140007030(param_1 + 5,0x100);
  *(undefined4 *)(param_1 + 7) = 0x100;
  FUN_140007320(param_1 + 5,0);
  *(undefined4 *)(param_1 + 8) = 0;
  return param_1;
}

