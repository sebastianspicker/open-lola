
void FUN_140004b20(longlong param_1,void *param_2,size_t param_3)

{
  void *_Dst;
  uint uVar1;
  ulonglong uVar2;
  ulonglong uVar3;
  
  if (param_3 != 0) {
    uVar3 = (ulonglong)*(uint *)(param_1 + 0x18);
    uVar2 = (ulonglong)*(uint *)(param_1 + 0xc);
    if (uVar3 < param_3 + uVar2) {
      do {
        uVar1 = *(int *)(param_1 + 8) + (int)uVar3;
        *(uint *)(param_1 + 0x18) = uVar1;
        _Dst = operator_new((ulonglong)uVar1);
        if (*(void **)(param_1 + 0x10) != (void *)0x0) {
          memcpy(_Dst,*(void **)(param_1 + 0x10),(ulonglong)*(uint *)(param_1 + 0xc));
          free(*(void **)(param_1 + 0x10));
        }
        *(void **)(param_1 + 0x10) = _Dst;
        uVar2 = (ulonglong)*(uint *)(param_1 + 0xc);
        uVar3 = (ulonglong)*(uint *)(param_1 + 0x18);
      } while ((ulonglong)*(uint *)(param_1 + 0x18) < param_3 + uVar2);
    }
    else {
      _Dst = *(void **)(param_1 + 0x10);
    }
    memcpy((void *)(uVar2 + (longlong)_Dst),param_2,param_3);
    *(int *)(param_1 + 0xc) = *(int *)(param_1 + 0xc) + (int)param_3;
  }
  return;
}

