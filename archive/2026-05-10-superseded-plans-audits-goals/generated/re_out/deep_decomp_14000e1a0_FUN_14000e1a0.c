
undefined8 * FUN_14000e1a0(undefined8 *param_1,longlong param_2,undefined8 param_3)

{
  void *pvVar1;
  longlong lVar2;
  HANDLE pvVar3;
  undefined8 *puVar4;
  longlong *plVar5;
  longlong lVar6;
  
  *param_1 = CBFVideoServ::vftable;
  _eh_vector_constructor_iterator_
            (param_1 + 0x92,8,0x80,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  _eh_vector_constructor_iterator_
            (param_1 + 0x112,8,0x100,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  FUN_140020e00(param_1 + 0x228);
  FUN_140020e00(param_1 + 0x22b);
  FUN_140020e00(param_1 + 0x22e);
  lVar2 = 0;
  param_1[0x234] = 0;
  param_1[0x235] = 0xf;
  *(undefined1 *)(param_1 + 0x232) = 0;
  *(undefined4 *)(param_1 + 0x238) = 0xfdfdfdfd;
  *(undefined4 *)((longlong)param_1 + 0x11c4) = 0xdfdfdfdf;
  *(undefined4 *)(param_1 + 0x239) = 0xaaaaaaaa;
  *(undefined8 *)((longlong)param_1 + 0x11cc) = 0;
  *(undefined8 *)((longlong)param_1 + 0x11d4) = 0;
  *(undefined4 *)((longlong)param_1 + 0x11dc) = 0;
  FUN_140004a10(param_1 + 0x23c);
  plVar5 = param_1 + 0x27d;
  lVar6 = 2;
  _eh_vector_constructor_iterator_(plVar5,0x220,2,FUN_140008660,FUN_140008a20);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x32e));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x339));
  param_1[0x338] = param_2;
  param_1[0x88] = param_2 + 0x1910;
  param_1[0x89] = param_3;
  param_1[0x330] = 0;
  *(undefined4 *)(param_1 + 0x225) = 0;
  InitializeCriticalSection((LPCRITICAL_SECTION)(param_1 + 1));
  *(undefined4 *)(param_1 + 6) = 0;
  param_1[0x7f] = 0;
  *(undefined4 *)(param_1 + 0x223) = 1;
  *(undefined4 *)((longlong)param_1 + 0x1994) = 1;
  *(undefined8 *)((longlong)param_1 + 0x484) = 0;
  *(undefined4 *)((longlong)param_1 + 0x48c) = 0;
  *(undefined4 *)(param_1 + 0x333) = 1;
  *(undefined4 *)((longlong)param_1 + 0x199c) = 1;
  param_1[0x7b] = 0;
  param_1[0x7c] = 0;
  param_1[0x7d] = 0;
  param_1[0x7e] = 0;
  param_1[0x212] = 0;
  pvVar1 = operator_new(0xc38);
  if (pvVar1 != (void *)0x0) {
    lVar2 = FUN_140014880((longlong)pvVar1);
  }
  param_1[0x213] = lVar2;
  FUN_140014950(lVar2);
  *(undefined4 *)(param_1 + 0x214) = 0;
  *(undefined4 *)(param_1 + 0x30a) = 1;
  *(undefined8 *)((longlong)param_1 + 0x404) = 0;
  param_1[0x308] = 0;
  param_1[0x309] = 0;
  *(undefined4 *)(param_1 + 0x32d) = 0;
  *(undefined4 *)(param_1 + 0x335) = 0;
  *(undefined4 *)((longlong)param_1 + 0x1114) = 0;
  *(undefined4 *)((longlong)param_1 + 0x1834) = 0;
  *(undefined4 *)((longlong)param_1 + 0x11b4) = 0;
  *(undefined4 *)(param_1 + 0x219) = 0x280;
  *(undefined4 *)((longlong)param_1 + 0x10cc) = 0x1e0;
  *(undefined4 *)((longlong)param_1 + 0x10dc) = 8;
  *(undefined4 *)(param_1 + 0x21c) = 0x20;
  *(undefined4 *)(param_1 + 0x21a) = 0x4b000;
  *(undefined4 *)((longlong)param_1 + 0x10d4) = 0x12c000;
  param_1[0x21d] = 0x403e000000000000;
  param_1[0x21e] = 0x4059000000000000;
  param_1[0x21f] = 0;
  *(undefined4 *)(param_1 + 0x220) = 0xffffffff;
  param_1[0x221] = 0;
  param_1[0x224] = 0;
  param_1[0x226] = 0;
  *(undefined4 *)(param_1 + 0x227) = 0;
  *(undefined8 *)((longlong)param_1 + 0x10a4) = 0x40;
  *(undefined8 *)((longlong)param_1 + 0x10ac) = 0x40;
  *(undefined8 *)((longlong)param_1 + 0x10b4) = 0x40;
  *(undefined8 *)((longlong)param_1 + 0x10bc) = 0;
  *(undefined4 *)((longlong)param_1 + 0x10c4) = 0;
  param_1[0x30f] = 0;
  param_1[0x310] = 0;
  param_1[0x311] = 0;
  param_1[0x312] = 0;
  param_1[0x313] = 0;
  param_1[0x314] = 0;
  param_1[0x315] = 0;
  param_1[0x316] = 0;
  param_1[0x317] = 0;
  param_1[0x318] = 0;
  param_1[0x319] = 0;
  param_1[0x31a] = 0;
  param_1[0x31b] = 0;
  param_1[0x31c] = 0;
  param_1[0x31d] = 0;
  param_1[0x31e] = 0;
  param_1[799] = 0;
  param_1[800] = 0;
  param_1[0x321] = 0;
  param_1[0x322] = 0;
  param_1[0x323] = 0;
  param_1[0x324] = 0;
  param_1[0x325] = 0;
  param_1[0x326] = 0;
  param_1[0x327] = 0;
  param_1[0x328] = 0;
  param_1[0x329] = 0;
  param_1[0x32a] = 0;
  param_1[0x32b] = 0;
  param_1[0x32c] = 0;
  *(undefined4 *)(param_1 + 0x30e) = 0;
  param_1[0x336] = 0;
  *(undefined1 *)(param_1 + 0x306) = 0;
  param_1[0x231] = 0;
  param_1[0x8f] = 0;
  *(undefined4 *)(param_1 + 0x90) = 0;
  pvVar3 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,0,0,"VideoWriteEvent");
  param_1[0x8a] = pvVar3;
  pvVar3 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,0,0,"RecFrameReadyEvent");
  param_1[0x8b] = pvVar3;
  pvVar3 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,0,0,"CameraPreviewEndedEvent");
  param_1[0x8e] = pvVar3;
  param_1[0x83] = 0;
  param_1[0x84] = 0;
  param_1[0x85] = 0;
  param_1[0x86] = 0;
  pvVar3 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,1,1,"FrameDoneThreadEnded");
  param_1[0x8c] = pvVar3;
  pvVar3 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,1,1,"NetSendThreadEnded");
  param_1[0x8d] = pvVar3;
  pvVar3 = CreateEventA((LPSECURITY_ATTRIBUTES)0x0,1,1,"LocRecVideoThreadEnded");
  param_1[0x32f] = pvVar3;
  puVar4 = param_1 + 0x2be;
  do {
    puVar4[-1] = 0;
    *puVar4 = 0;
    puVar4[1] = 0;
    FUN_14000ab60(plVar5,&DAT_1400439ac,0);
    *(undefined2 *)(puVar4 + 2) = 0;
    plVar5 = plVar5 + 0x44;
    puVar4 = puVar4 + 0x44;
    lVar6 = lVar6 + -1;
  } while (lVar6 != 0);
  *(undefined1 *)(param_1 + 0x33a) = 0;
  param_1[0x305] = 0;
  param_1[0x237] = 0;
  return param_1;
}

