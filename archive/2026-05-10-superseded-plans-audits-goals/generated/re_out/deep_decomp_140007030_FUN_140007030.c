
void FUN_140007030(undefined8 *param_1,uint param_2)

{
  uint uVar1;
  void *_Dst;
  void *_Src;
  
  if (*(uint *)(param_1 + 1) != param_2) {
    if (param_2 == 0) {
      FUN_140006e60(param_1);
      return;
    }
    _Dst = operator_new((ulonglong)param_2);
    _Src = (void *)*param_1;
    if (_Src != (void *)0x0) {
      uVar1 = param_2;
      if (*(uint *)((longlong)param_1 + 0xc) < param_2) {
        uVar1 = *(uint *)((longlong)param_1 + 0xc);
      }
      if (uVar1 != 0) {
        memcpy(_Dst,_Src,(ulonglong)uVar1);
        _Src = (void *)*param_1;
      }
      free(_Src);
    }
    *param_1 = _Dst;
    if (param_2 < *(uint *)((longlong)param_1 + 0xc)) {
      *(uint *)((longlong)param_1 + 0xc) = param_2;
    }
    *(uint *)(param_1 + 1) = param_2;
  }
  return;
}

