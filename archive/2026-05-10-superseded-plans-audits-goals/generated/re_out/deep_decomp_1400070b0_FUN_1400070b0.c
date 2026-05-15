
void FUN_1400070b0(longlong param_1,void *param_2,uint param_3)

{
  longlong lVar1;
  undefined4 uVar2;
  undefined8 *puVar3;
  uint uVar4;
  ulonglong uVar5;
  uint uVar6;
  void *_Src;
  void *local_res8;
  
  *(int *)(param_1 + 8) = *(int *)(param_1 + 8) + 1;
  uVar5 = 0;
  uVar6 = *(int *)(param_1 + 0xc) - 0x21;
  uVar4 = 0;
  *(undefined4 *)(param_1 + 0x10) = 0;
  for (_Src = param_2; _Src < (void *)((ulonglong)param_3 + (longlong)param_2);
      _Src = (void *)((longlong)_Src + (ulonglong)uVar6)) {
    if ((void *)((ulonglong)param_3 + (longlong)param_2) <=
        (void *)((ulonglong)uVar6 + (longlong)_Src)) {
      uVar6 = ((int)param_2 - (int)_Src) + param_3;
    }
    if (*(uint *)(param_1 + 0x24) <= (uint)uVar5) {
      local_res8 = operator_new((ulonglong)*(uint *)(param_1 + 0xc));
      FUN_140006df0((longlong *)(param_1 + 0x18),&local_res8);
      uVar5 = (ulonglong)*(uint *)(param_1 + 0x10);
    }
    puVar3 = *(undefined8 **)(*(longlong *)(param_1 + 0x18) + uVar5 * 8);
    uVar2 = *(undefined4 *)(param_1 + 8);
    *puVar3 = 0xdfdfdfdffdfdfdfd;
    puVar3[1] = CONCAT44(uVar2,0xeeeeeeee);
    puVar3[2] = uVar5 << 0x20;
    puVar3[3] = CONCAT44(uVar6,(int)_Src - (int)param_2);
    *(undefined1 *)(puVar3 + 4) = 0;
    memcpy((void *)((longlong)puVar3 + 0x21),_Src,(ulonglong)uVar6);
    uVar4 = *(int *)(param_1 + 0x10) + 1;
    uVar5 = (ulonglong)uVar4;
    *(uint *)(param_1 + 0x10) = uVar4;
  }
  uVar5 = 0;
  if (uVar4 != 0) {
    do {
      lVar1 = uVar5 * 8;
      uVar6 = (int)uVar5 + 1;
      uVar5 = (ulonglong)uVar6;
      *(undefined4 *)(*(longlong *)(*(longlong *)(param_1 + 0x18) + lVar1) + 0x10) =
           *(undefined4 *)(param_1 + 0x10);
    } while (uVar6 < *(uint *)(param_1 + 0x10));
  }
  return;
}

