
ushort FUN_140020a10(longlong *param_1)

{
  ushort uVar1;
  ushort uVar2;
  ushort uVar3;
  ushort uVar4;
  longlong lVar5;
  
  uVar4 = 0;
  lVar5 = 0xe;
  do {
    uVar1 = FUN_140020580(*(undefined1 *)(*param_1 + lVar5),*(undefined1 *)(*param_1 + 1 + lVar5));
    uVar3 = uVar4 + uVar1;
    uVar2 = ~uVar4;
    uVar4 = uVar3;
    if (uVar2 < uVar1) {
      uVar4 = uVar3 + 1;
    }
    lVar5 = lVar5 + 2;
  } while (lVar5 < 0x22);
  return ~uVar4;
}

