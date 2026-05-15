
undefined8 * FUN_140004a10(undefined8 *param_1)

{
  param_1[1] = 0x400;
  *param_1 = flOutputByteStream::vftable;
  param_1[2] = 0;
  *(undefined4 *)(param_1 + 3) = 0;
  return param_1;
}

