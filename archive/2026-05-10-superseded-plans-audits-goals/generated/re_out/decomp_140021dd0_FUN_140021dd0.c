
void FUN_140021dd0(longlong param_1)

{
  LRESULT LVar1;
  
  LVar1 = SendMessageA(*(HWND *)(param_1 + 0xc90),0xf0,0,0);
                    /* WARNING: Could not recover jumptable at 0x000140021e0d. Too many branches */
                    /* WARNING: Treating indirect jump as call */
  xiSetParamInt(*(undefined8 *)(param_1 + 0x160),&DAT_140044b10,(int)LVar1 != 0);
  return;
}

