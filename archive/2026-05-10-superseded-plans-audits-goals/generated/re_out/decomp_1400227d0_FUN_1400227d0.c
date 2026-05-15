
void FUN_1400227d0(longlong param_1)

{
  float fVar1;
  float fVar2;
  float fVar3;
  float fVar4;
  float fVar5;
  
  if (*(longlong *)(param_1 + 0x160) != 0) {
    fVar1 = DAT_140044d7c - (float)*(uint *)(param_1 + 0x144) / DAT_140044d98;
    fVar4 = (float)*(uint *)(param_1 + 0x134) * DAT_140044178;
    fVar5 = (float)*(uint *)(param_1 + 0x148) / DAT_140044d98;
    fVar2 = DAT_140044490;
    if (fVar1 <= DAT_140044490) {
      fVar2 = fVar1;
    }
    fVar3 = (float)*(uint *)(param_1 + 0x138) * DAT_140044178;
    fVar1 = DAT_140044d70;
    if (DAT_140044d70 <= fVar2) {
      fVar1 = fVar2;
    }
    xiSetParamFloat(*(longlong *)(param_1 + 0x160),"wb_kr",
                    (float)*(uint *)(param_1 + 0x130) * DAT_140044178);
    xiSetParamFloat(*(undefined8 *)(param_1 + 0x160),"wb_kg",fVar4);
    xiSetParamFloat(*(undefined8 *)(param_1 + 0x160),"wb_kb",fVar3);
    if (*(int *)(param_1 + 0x140) != *(int *)(param_1 + 0x13c)) {
      xiSetParamInt(*(undefined8 *)(param_1 + 0x160),&DAT_140044af8);
      *(undefined4 *)(param_1 + 0x140) = *(undefined4 *)(param_1 + 0x13c);
    }
    xiSetParamFloat(*(undefined8 *)(param_1 + 0x160),"gammaY",fVar1);
    xiSetParamFloat(*(undefined8 *)(param_1 + 0x160),"gammaC",fVar5);
    if (*(longlong *)(param_1 + 0x158) != 0) {
      FUN_140014910(*(longlong *)(param_1 + 0x158),*(undefined4 *)(param_1 + 0x130),0,
                    *(undefined4 *)(param_1 + 0x134),0,*(undefined4 *)(param_1 + 0x138),0);
    }
  }
  return;
}

