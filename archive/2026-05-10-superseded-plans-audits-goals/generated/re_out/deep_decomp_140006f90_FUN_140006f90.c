
void FUN_140006f90(undefined8 *param_1,uint param_2)

{
  __uint64 _Var1;
  void *_Dst;
  uint uVar2;
  void *_Src;
  
  if (*(uint *)(param_1 + 1) != param_2) {
    if (param_2 == 0) {
      FUN_140006e40(param_1);
      return;
    }
    _Var1 = SUB168(ZEXT816(8) * ZEXT416(param_2),0);
    if (SUB168(ZEXT816(8) * ZEXT416(param_2),8) != 0) {
      _Var1 = 0xffffffffffffffff;
    }
    _Dst = operator_new(_Var1);
    _Src = (void *)*param_1;
    if (_Src != (void *)0x0) {
      uVar2 = param_2;
      if (*(uint *)((longlong)param_1 + 0xc) < param_2) {
        uVar2 = *(uint *)((longlong)param_1 + 0xc);
      }
      if (uVar2 != 0) {
        memcpy(_Dst,_Src,(ulonglong)uVar2 << 3);
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

