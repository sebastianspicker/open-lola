
void * FUN_140020870(void *param_1)

{
  char *_Src;
  void *pvVar1;
  __uint64 _Var2;
  size_t sVar3;
  void *pvVar4;
  longlong lVar5;
  
  sVar3 = 0xffffffffffffffff;
  _Var2 = 0xffffffffffffffff;
  do {
    _Var2 = _Var2 + 1;
  } while (*(char *)((longlong)param_1 + _Var2) != '\0');
  _Src = operator_new(_Var2);
  do {
    sVar3 = sVar3 + 1;
  } while (*(char *)((longlong)param_1 + sVar3) != '\0');
  memcpy(_Src,param_1,sVar3);
  lVar5 = 6;
  pvVar1 = operator_new(6);
  sVar3 = 0x13;
  pvVar4 = pvVar1;
  do {
    sscanf(_Src,"%2X",pvVar4);
    memmove(_Src,_Src + 3,sVar3);
    pvVar4 = (void *)((longlong)pvVar4 + 1);
    sVar3 = sVar3 - 3;
    lVar5 = lVar5 + -1;
  } while (lVar5 != 0);
  return pvVar1;
}

