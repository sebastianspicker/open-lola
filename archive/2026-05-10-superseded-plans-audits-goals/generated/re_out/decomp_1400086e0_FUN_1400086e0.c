
void FUN_1400086e0(undefined8 *param_1)

{
  void *pvVar1;
  int iVar2;
  void *_Memory;
  undefined8 *puVar3;
  undefined8 *puVar4;
  longlong lVar5;
  longlong lVar6;
  longlong lVar7;
  
  *param_1 = ASIOAudio::vftable;
  if (*(int *)(param_1 + 0x15) != 0) {
    FUN_14000a770((longlong)param_1);
  }
  if ((*(int *)(param_1 + 0x14) != 0) && (iVar2 = Pa_IsStreamActive(param_1[0x12]), iVar2 != 0)) {
    Pa_IsStreamStopped(param_1[0x12]);
    Pa_IsStreamActive(param_1[0x12]);
  }
  Pa_Terminate();
  param_1[0x14] = 0;
  *(undefined4 *)(param_1 + 0x15) = 0;
  *(undefined4 *)((longlong)param_1 + 0x18ec) = 0;
  SetEvent((HANDLE)param_1[6]);
  if ((HANDLE)param_1[0x3f6] != (HANDLE)0x0) {
    WaitForSingleObject((HANDLE)param_1[0x3f6],1000);
    CloseHandle((HANDLE)param_1[0x3f6]);
  }
  puVar4 = param_1 + 0x11c;
  lVar5 = 2;
  do {
    if ((void *)*puVar4 != (void *)0x0) {
      free((void *)*puVar4);
    }
    puVar4 = puVar4 + 1;
    lVar5 = lVar5 + -1;
  } while (lVar5 != 0);
  puVar4 = param_1 + 0x184;
  lVar5 = 100;
  lVar7 = 2;
  do {
    lVar6 = 100;
    puVar3 = puVar4;
    do {
      if ((void *)*puVar3 != (void *)0x0) {
        free((void *)*puVar3);
      }
      puVar3 = puVar3 + 1;
      lVar6 = lVar6 + -1;
    } while (lVar6 != 0);
    puVar4 = puVar4 + 0x66;
    lVar7 = lVar7 + -1;
  } while (lVar7 != 0);
  puVar4 = param_1 + 0x252;
  lVar7 = 100;
  do {
    if ((void *)*puVar4 != (void *)0x0) {
      free((void *)*puVar4);
    }
    puVar4 = puVar4 + 1;
    lVar7 = lVar7 + -1;
  } while (lVar7 != 0);
  puVar4 = param_1 + 0x2b7;
  do {
    if ((void *)*puVar4 != (void *)0x0) {
      free((void *)*puVar4);
    }
    puVar4 = puVar4 + 1;
    lVar5 = lVar5 + -1;
  } while (lVar5 != 0);
  puVar4 = (undefined8 *)param_1[0x3fe];
  if (puVar4 != (undefined8 *)0x0) {
    (**(code **)*puVar4)(puVar4,1);
    param_1[0x3fe] = 0;
  }
  if ((HANDLE)param_1[0x3f7] != (HANDLE)0x0) {
    CloseHandle((HANDLE)param_1[0x3f7]);
  }
  puVar4 = (undefined8 *)param_1[0x3ff];
  if (puVar4 != (undefined8 *)0x0) {
    (**(code **)*puVar4)(puVar4,1);
    param_1[0x3ff] = 0;
  }
  if ((HANDLE)param_1[0x3f8] != (HANDLE)0x0) {
    CloseHandle((HANDLE)param_1[0x3f8]);
  }
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x3fa));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x3f9));
  _eh_vector_destructor_iterator_(param_1 + 0x36d,0x220,2,FUN_140008a20);
  FUN_140004a40(param_1 + 0x329);
  if (0xf < (ulonglong)param_1[0x321]) {
    pvVar1 = (void *)param_1[0x31e];
    _Memory = pvVar1;
    if ((0xfff < param_1[0x321] + 1) &&
       (_Memory = *(void **)((longlong)pvVar1 + -8),
       0x1f < (ulonglong)((longlong)pvVar1 + (-8 - (longlong)_Memory)))) {
                    /* WARNING: Subroutine does not return */
      _invalid_parameter_noinfo_noreturn();
    }
    free(_Memory);
  }
  param_1[800] = 0;
  param_1[0x321] = 0xf;
  *(undefined1 *)(param_1 + 0x31e) = 0;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x31c));
  _eh_vector_destructor_iterator_
            (param_1 + 0x99,8,0x40,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  _eh_vector_destructor_iterator_
            (param_1 + 0x59,8,0x40,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  _eh_vector_destructor_iterator_
            (param_1 + 0x19,8,0x40,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  return;
}

