
void FUN_140022670(longlong param_1)

{
  LRESULT LVar1;
  int iVar2;
  uint uVar3;
  bool bVar4;
  int local_res8 [2];
  
  xiGetParamInt(*(undefined8 *)(param_1 + 0x160),"imgdataformat",local_res8);
  bVar4 = local_res8[0] != 2;
  if (bVar4) {
    LVar1 = SendMessageA(*(HWND *)(param_1 + 0xe60),0xf0,0,0);
    iVar2 = (int)LVar1;
  }
  else {
    iVar2 = 1;
  }
  uVar3 = (uint)!bVar4;
  CWnd::EnableWindow((CWnd *)(param_1 + 0x6e0),iVar2);
  CWnd::EnableWindow((CWnd *)(param_1 + 0x170),iVar2);
  CWnd::EnableWindow((CWnd *)(param_1 + 0x7c8),uVar3);
  CWnd::EnableWindow((CWnd *)(param_1 + 600),uVar3);
  CWnd::EnableWindow((CWnd *)(param_1 + 0x8b0),iVar2);
  CWnd::EnableWindow((CWnd *)(param_1 + 0x340),iVar2);
  CWnd::EnableWindow((CWnd *)(param_1 + 0x998),1);
  CWnd::EnableWindow((CWnd *)(param_1 + 0x428),1);
  CWnd::EnableWindow((CWnd *)(param_1 + 0xa80),uVar3);
  CWnd::EnableWindow((CWnd *)(param_1 + 0x510),uVar3);
  CWnd::EnableWindow((CWnd *)(param_1 + 0xb68),uVar3);
  CWnd::EnableWindow((CWnd *)(param_1 + 0x5f8),uVar3);
  CWnd::EnableWindow((CWnd *)(param_1 + 0xd38),uVar3);
  CWnd::EnableWindow((CWnd *)(param_1 + 0xe20),(uint)bVar4);
  return;
}

