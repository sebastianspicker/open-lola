
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_140008b10(longlong param_1,undefined2 *param_2,int param_3)

{
  undefined2 uVar1;
  double dVar2;
  double dVar3;
  double dVar4;
  double dVar5;
  double dVar6;
  longlong lVar7;
  longlong lVar8;
  undefined2 *puVar9;
  float fVar10;
  double dVar11;
  undefined1 auStack_108 [32];
  undefined2 local_e8 [64];
  ulonglong local_68;
  
  dVar6 = DAT_1400441a0;
  dVar5 = DAT_140044188;
  dVar4 = DAT_140044180;
  local_68 = DAT_1400630d8 ^ (ulonglong)auStack_108;
  puVar9 = local_e8 + 2;
  dVar2 = 0.0;
  lVar8 = 4;
  fVar10 = (float)*(double *)(*(longlong *)(param_1 + 0xb0) + 0x1938);
  dVar3 = (double)(((fVar10 * DAT_140044178) / fVar10) * _DAT_140044190);
  do {
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[-2] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[-1] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    *puVar9 = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[1] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[2] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[3] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[4] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[5] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[6] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[7] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[8] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[9] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[10] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[0xb] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[0xc] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    dVar11 = sin(dVar2);
    dVar2 = dVar2 + dVar3;
    puVar9[0xd] = (short)(int)(dVar11 * dVar5);
    if (dVar4 < dVar2) {
      dVar2 = dVar2 + dVar6;
    }
    puVar9 = puVar9 + 0x10;
    lVar8 = lVar8 + -1;
  } while (lVar8 != 0);
  lVar8 = 0;
  do {
    if (0 < param_3) {
      uVar1 = local_e8[lVar8];
      puVar9 = param_2;
      for (lVar7 = (longlong)param_3; lVar7 != 0; lVar7 = lVar7 + -1) {
        *puVar9 = uVar1;
        puVar9 = puVar9 + 1;
      }
    }
    param_2 = param_2 + param_3;
    lVar8 = lVar8 + 1;
  } while (lVar8 < 0x40);
  return;
}

