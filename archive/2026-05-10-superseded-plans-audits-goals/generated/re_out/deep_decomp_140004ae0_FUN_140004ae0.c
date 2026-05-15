
void FUN_140004ae0(longlong param_1,void *param_2,size_t param_3)

{
  if (param_3 != 0) {
    memcpy(param_2,(void *)((ulonglong)*(uint *)(param_1 + 0x14) + *(longlong *)(param_1 + 8)),
           param_3);
    *(int *)(param_1 + 0x14) = *(int *)(param_1 + 0x14) + (int)param_3;
  }
  return;
}

