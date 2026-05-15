
ushort FUN_140020a80(longlong *param_1,void *param_2,int param_3)

{
  u_short uVar1;
  undefined1 *_Dst;
  ushort uVar2;
  ushort uVar3;
  ushort uVar4;
  longlong lVar5;
  ushort uVar6;
  undefined1 *puVar7;
  
  uVar4 = 0;
  uVar6 = (short)param_3 + 0x11;
  uVar6 = (uVar6 & 1) + uVar6;
  _Dst = operator_new((ulonglong)uVar6);
  if (uVar6 != 0) {
    memset(_Dst,0,(ulonglong)uVar6);
  }
  *_Dst = 0x11;
  *(undefined8 *)(_Dst + 1) = *(undefined8 *)(*param_1 + 0x1a);
  uVar1 = htons((short)param_3 + 8);
  *(u_short *)(_Dst + 9) = uVar1;
  *(u_short *)(_Dst + 0xb) = uVar1;
  *(undefined2 *)(_Dst + 0xd) = *(undefined2 *)(*param_1 + 0x22);
  *(undefined2 *)(_Dst + 0xf) = *(undefined2 *)(*param_1 + 0x24);
  memcpy(_Dst + 0x11,param_2,(longlong)param_3);
  if ((ulonglong)uVar6 != 0) {
    lVar5 = ((ulonglong)uVar6 - 1 >> 1) + 1;
    puVar7 = _Dst;
    do {
      uVar6 = FUN_140020580(*puVar7,puVar7[1]);
      uVar3 = uVar4 + uVar6;
      uVar2 = ~uVar4;
      uVar4 = uVar3;
      if (uVar2 < uVar6) {
        uVar4 = uVar3 + 1;
      }
      puVar7 = puVar7 + 2;
      lVar5 = lVar5 + -1;
    } while (lVar5 != 0);
  }
  free(_Dst);
  return ~uVar4;
}

