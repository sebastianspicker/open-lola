
void FUN_1400129d0(longlong param_1)

{
  uint uVar1;
  longlong *plVar2;
  
  uVar1 = 0;
  if (*(CWnd **)(param_1 + 0x1840) != (CWnd *)0x0) {
    FUN_140018f30(*(CWnd **)(param_1 + 0x1840));
    plVar2 = *(longlong **)(param_1 + 0x1840);
    if (plVar2 != (longlong *)0x0) {
      (**(code **)(*plVar2 + 8))(plVar2,1);
    }
    *(undefined8 *)(param_1 + 0x1840) = 0;
  }
  if (*(int *)(param_1 + 0x404) != 0) {
    plVar2 = (longlong *)(param_1 + 0x3d8);
    do {
      if (*plVar2 != 0) {
        xiCloseDevice();
      }
      uVar1 = uVar1 + 1;
      plVar2 = plVar2 + 1;
    } while (uVar1 < *(uint *)(param_1 + 0x404));
  }
  return;
}

