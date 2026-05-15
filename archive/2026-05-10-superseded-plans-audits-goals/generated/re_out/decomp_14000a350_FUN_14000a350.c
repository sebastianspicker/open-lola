
undefined8 FUN_14000a350(longlong param_1)

{
  int iVar1;
  
  if (*(int *)(param_1 + 0xa4) != 0) {
    return 0;
  }
  if (*(int *)(param_1 + 0xa0) != 0) {
    iVar1 = Pa_StartStream(*(undefined8 *)(param_1 + 0x90));
    if (iVar1 != 0) {
      return 0;
    }
    *(undefined4 *)(param_1 + 0xa4) = 1;
  }
  return 1;
}

