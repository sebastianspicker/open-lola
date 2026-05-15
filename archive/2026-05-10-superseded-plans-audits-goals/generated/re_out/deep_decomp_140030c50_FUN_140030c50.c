
void FUN_140030c50(CWnd *param_1,undefined8 param_2,undefined8 param_3,undefined8 param_4)

{
  CDialog *pCVar1;
  CWnd *pCVar2;
  
  pCVar2 = *(CWnd **)(param_1 + 0x3398);
  if (pCVar2 == (CWnd *)0x0) {
    pCVar1 = operator_new(0x428);
    if (pCVar1 == (CDialog *)0x0) {
      pCVar1 = (CDialog *)0x0;
    }
    else {
      pCVar1 = FUN_140025ea0(pCVar1,param_1);
    }
    *(CDialog **)(param_1 + 0x3398) = pCVar1;
    (**(code **)(*(longlong *)pCVar1 + 0x2d8))(pCVar1,0x9a,param_1);
    pCVar2 = *(CWnd **)(param_1 + 0x3398);
    if (pCVar2 == (CWnd *)0x0) {
      return;
    }
  }
  FUN_140026860(pCVar2);
  CWnd::SetFocus((CWnd *)(*(longlong *)(param_1 + 0x3398) + 600));
  return;
}

