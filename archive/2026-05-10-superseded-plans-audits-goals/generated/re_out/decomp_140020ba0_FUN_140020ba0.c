
void FUN_140020ba0(longlong *param_1,undefined4 *param_2,undefined4 *param_3,undefined4 param_4,
                  undefined4 param_5,u_short param_6,u_short param_7,void *param_8,uint param_9)

{
  undefined4 *puVar1;
  longlong lVar2;
  u_short uVar3;
  ushort uVar4;
  
  puVar1 = (undefined4 *)*param_1;
  *(uint *)(param_1 + 1) = param_9;
  *puVar1 = *param_3;
  *(undefined2 *)(puVar1 + 1) = *(undefined2 *)(param_3 + 1);
  lVar2 = *param_1;
  *(undefined4 *)(lVar2 + 6) = *param_2;
  *(undefined2 *)(lVar2 + 10) = *(undefined2 *)(param_2 + 1);
  *(undefined2 *)(*param_1 + 0xc) = 8;
  *(undefined1 *)(*param_1 + 0xe) = 0x45;
  *(undefined1 *)(*param_1 + 0xf) = 0;
  uVar3 = htons((short)param_9 + 0x1c);
  *(u_short *)(*param_1 + 0x10) = uVar3;
  uVar3 = htons(0x1337);
  *(u_short *)(*param_1 + 0x12) = uVar3;
  *(undefined1 *)(*param_1 + 0x14) = 0;
  *(undefined1 *)(*param_1 + 0x15) = 0;
  *(undefined1 *)(*param_1 + 0x16) = 0x80;
  *(undefined1 *)(*param_1 + 0x17) = 0x11;
  *(undefined2 *)(*param_1 + 0x18) = 0;
  *(undefined4 *)(*param_1 + 0x1a) = param_4;
  *(undefined4 *)(*param_1 + 0x1e) = param_5;
  uVar3 = htons(param_6);
  *(u_short *)(*param_1 + 0x22) = uVar3;
  uVar3 = htons(param_7);
  *(u_short *)(*param_1 + 0x24) = uVar3;
  uVar3 = htons((short)param_9 + 8);
  *(u_short *)(*param_1 + 0x26) = uVar3;
  memcpy((void *)(*param_1 + 0x2a),param_8,(ulonglong)param_9);
  htons(param_7);
  htons(param_6);
  uVar4 = FUN_140020a80(param_1,param_8,param_9);
  *(ushort *)(*param_1 + 0x28) = uVar4;
  uVar4 = FUN_140020a10(param_1);
  uVar3 = htons(uVar4);
  *(u_short *)(*param_1 + 0x18) = uVar3;
  return;
}

