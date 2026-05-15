
void FUN_140021cc0(longlong param_1)

{
  float fVar1;
  float fVar2;
  float local_res8 [2];
  float local_res10 [2];
  float local_res18 [4];
  
  xiSetParamInt(*(undefined8 *)(param_1 + 0x160),"manual_wb",1);
  Sleep(500);
  local_res8[0] = 0.0;
  local_res10[0] = 0.0;
  local_res18[0] = 0.0;
  xiGetParamFloat(*(undefined8 *)(param_1 + 0x160),"wb_kr",local_res8);
  xiGetParamFloat(*(undefined8 *)(param_1 + 0x160),"wb_kg",local_res10);
  xiGetParamFloat(*(undefined8 *)(param_1 + 0x160),"wb_kb",local_res18);
  fVar1 = DAT_14004831c;
  fVar2 = local_res8[0] * DAT_14004831c;
  *(undefined4 *)(param_1 + 0x13c) = 0;
  *(undefined4 *)(param_1 + 0x144) = 0xd3;
  *(undefined4 *)(param_1 + 0x148) = 0xcc;
  *(int *)(param_1 + 0x130) = (int)fVar2;
  *(int *)(param_1 + 0x134) = (int)(local_res10[0] * fVar1);
  *(int *)(param_1 + 0x138) = (int)(local_res18[0] * fVar1);
  FUN_140021ad0(param_1);
  FUN_1400227d0(param_1);
  return;
}

