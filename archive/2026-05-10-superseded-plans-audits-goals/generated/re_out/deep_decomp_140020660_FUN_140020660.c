
undefined1 * FUN_140020660(undefined1 *param_1,longlong param_2)

{
  undefined8 *puVar1;
  undefined8 *puVar2;
  undefined8 *puVar3;
  undefined8 uVar4;
  ulong uVar5;
  int iVar6;
  undefined8 *_Memory;
  char *pcVar7;
  undefined8 *puVar8;
  longlong lVar9;
  undefined8 *puVar10;
  undefined4 local_res8 [2];
  undefined4 local_res18 [4];
  
  memset(param_1,0,0x1e0);
  _Memory = operator_new(0x8400);
  local_res8[0] = 0x8400;
  GetAdaptersInfo(_Memory,local_res8);
  puVar3 = _Memory;
joined_r0x0001400206a7:
  if (puVar3 != (undefined8 *)0x0) {
    pcVar7 = strstr(*(char **)(param_2 + 8),(char *)((longlong)puVar3 + 0xc));
    if (pcVar7 == (char *)0x0) goto code_r0x0001400206c2;
    uVar5 = inet_addr((char *)(puVar3 + 0x3e));
    *(ulong *)(param_1 + 8) = uVar5;
    uVar5 = inet_addr((char *)(puVar3 + 0x38));
    *(ulong *)(param_1 + 4) = uVar5;
    *(undefined4 *)(param_1 + 0x12) = *(undefined4 *)(puVar3 + 0x33);
    *(undefined2 *)(param_1 + 0x16) = *(undefined2 *)((longlong)puVar3 + 0x19c);
    local_res18[0] = 6;
    iVar6 = SendARP(*(undefined4 *)(param_1 + 8),0,param_1 + 0xc,local_res18);
    if (iVar6 != 0) {
      FUN_1400202f0((basic_ostream<char,struct_std::char_traits<char>_> *)cout_exref,
                    "SendARP Failed. No default gateway\n");
    }
    *param_1 = 1;
    lVar9 = 2;
    puVar8 = (undefined8 *)((longlong)puVar3 + 0xc);
    puVar10 = (undefined8 *)(param_1 + 0x18);
    do {
      puVar1 = puVar10 + 0x10;
      uVar4 = puVar8[1];
      puVar2 = puVar8 + 0x10;
      *puVar10 = *puVar8;
      puVar10[1] = uVar4;
      uVar4 = puVar8[3];
      puVar10[2] = puVar8[2];
      puVar10[3] = uVar4;
      uVar4 = puVar8[5];
      puVar10[4] = puVar8[4];
      puVar10[5] = uVar4;
      uVar4 = puVar8[7];
      puVar10[6] = puVar8[6];
      puVar10[7] = uVar4;
      uVar4 = puVar8[9];
      puVar10[8] = puVar8[8];
      puVar10[9] = uVar4;
      uVar4 = puVar8[0xb];
      puVar10[10] = puVar8[10];
      puVar10[0xb] = uVar4;
      uVar4 = puVar8[0xd];
      puVar10[0xc] = puVar8[0xc];
      puVar10[0xd] = uVar4;
      uVar4 = puVar8[0xf];
      puVar10[0xe] = puVar8[0xe];
      puVar10[0xf] = uVar4;
      lVar9 = lVar9 + -1;
      puVar8 = puVar2;
      puVar10 = puVar1;
    } while (lVar9 != 0);
    *(undefined4 *)puVar1 = *(undefined4 *)puVar2;
    uVar4 = puVar3[0x23];
    *(undefined8 *)(param_1 + 0x11c) = puVar3[0x22];
    *(undefined8 *)(param_1 + 0x124) = uVar4;
    uVar4 = puVar3[0x25];
    *(undefined8 *)(param_1 + 300) = puVar3[0x24];
    *(undefined8 *)(param_1 + 0x134) = uVar4;
    uVar4 = puVar3[0x27];
    *(undefined8 *)(param_1 + 0x13c) = puVar3[0x26];
    *(undefined8 *)(param_1 + 0x144) = uVar4;
    uVar4 = puVar3[0x29];
    *(undefined8 *)(param_1 + 0x14c) = puVar3[0x28];
    *(undefined8 *)(param_1 + 0x154) = uVar4;
    uVar4 = puVar3[0x2b];
    *(undefined8 *)(param_1 + 0x15c) = puVar3[0x2a];
    *(undefined8 *)(param_1 + 0x164) = uVar4;
    uVar4 = puVar3[0x2d];
    *(undefined8 *)(param_1 + 0x16c) = puVar3[0x2c];
    *(undefined8 *)(param_1 + 0x174) = uVar4;
    uVar4 = puVar3[0x2f];
    *(undefined8 *)(param_1 + 0x17c) = puVar3[0x2e];
    *(undefined8 *)(param_1 + 0x184) = uVar4;
    uVar4 = puVar3[0x31];
    *(undefined8 *)(param_1 + 0x18c) = puVar3[0x30];
    *(undefined8 *)(param_1 + 0x194) = uVar4;
    *(undefined4 *)(param_1 + 0x19c) = *(undefined4 *)(puVar3 + 0x32);
    uVar4 = puVar3[0x39];
    *(undefined8 *)(param_1 + 0x1a0) = puVar3[0x38];
    *(undefined8 *)(param_1 + 0x1a8) = uVar4;
    uVar4 = puVar3[0x3b];
    *(undefined8 *)(param_1 + 0x1b0) = puVar3[0x3a];
    *(undefined8 *)(param_1 + 0x1b8) = uVar4;
    uVar4 = puVar3[0x3b];
    *(undefined8 *)(param_1 + 0x1c0) = puVar3[0x3a];
    *(undefined8 *)(param_1 + 0x1c8) = uVar4;
    uVar4 = puVar3[0x3d];
    *(undefined8 *)(param_1 + 0x1d0) = puVar3[0x3c];
    *(undefined8 *)(param_1 + 0x1d8) = uVar4;
    goto LAB_1400206d2;
  }
  *param_1 = 0;
  if (_Memory != (undefined8 *)0x0) {
LAB_1400206d2:
    free(_Memory);
  }
  return param_1;
code_r0x0001400206c2:
  puVar3 = (undefined8 *)*puVar3;
  goto joined_r0x0001400206a7;
}

