
undefined8 FUN_14000a710(longlong param_1)

{
  int iVar1;
  
  if (*(int *)(param_1 + 0xa4) == 0) {
    return 0;
  }
  if ((*(int *)(param_1 + 0xa0) != 0) &&
     (iVar1 = Pa_IsStreamStopped(*(undefined8 *)(param_1 + 0x90)), iVar1 == 0)) {
    iVar1 = Pa_StopStream(*(undefined8 *)(param_1 + 0x90));
    *(undefined4 *)(param_1 + 0xa4) = 0;
    if (iVar1 != 0) {
      return 0;
    }
  }
  return 1;
}

