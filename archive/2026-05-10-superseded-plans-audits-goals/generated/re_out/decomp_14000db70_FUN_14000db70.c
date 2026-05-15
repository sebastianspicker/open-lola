
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_14000db70(longlong param_1)

{
  int iVar1;
  float fVar2;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar3;
  IAtlStringMgr *pIVar4;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar5;
  ulonglong uVar6;
  undefined8 uVar7;
  float fVar8;
  float fVar9;
  undefined1 auStackY_3a8 [32];
  char *local_368;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_360 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_358 [8];
  undefined8 local_350;
  undefined8 local_348;
  longlong local_340;
  int local_2d4;
  uint local_2d0;
  int local_2c8;
  uint local_2b0;
  undefined1 local_e8 [176];
  ulonglong local_38;
  
  local_350 = 0xfffffffffffffffe;
  local_38 = DAT_1400630d8 ^ (ulonglong)auStackY_3a8;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_368
             ,"Jpeg decoding (CPU): ");
  ResetEvent(*(HANDLE *)(param_1 + 0x1b8));
  *(undefined4 *)(param_1 + 0x40) = 1;
  fVar2 = DAT_140044490;
  iVar1 = *(int *)(param_1 + 0x40);
  while (iVar1 == 1) {
    *(int *)(param_1 + 0x1c0) = *(int *)(param_1 + 0x1c0) + 1;
    WaitForSingleObject(*(HANDLE *)(param_1 + 8),0xffffffff);
    if (*(int *)(param_1 + 0x40) == 0) break;
    ResetEvent(*(HANDLE *)(param_1 + 8));
    if (((*(int *)(param_1 + 0x200) != 0) && (*(int *)(param_1 + 0x1f0) == 1)) &&
       (*(longlong *)(param_1 + 0x1f8) != 0)) {
      if (*(int *)(*(longlong *)(param_1 + 0x1c8) + 0x2c8) != 0) {
        FUN_140020e20(param_1 + 0x50);
      }
      EnterCriticalSection((LPCRITICAL_SECTION)(param_1 + 0x18));
      local_348 = jpeg_std_error(local_e8);
      jpeg_CreateDecompress(&local_348,0x3e,600);
      jpeg_mem_src(&local_348,*(undefined8 *)(param_1 + 0x1f8),*(undefined4 *)(param_1 + 500));
      jpeg_read_header(&local_348,1);
      jpeg_start_decompress(&local_348);
      uVar7 = 1;
      uVar6 = (ulonglong)(uint)(local_2c8 * local_2d4);
      (**(code **)(local_340 + 0x10))(&local_348);
      if (local_2b0 < local_2d0) {
        do {
          uVar6 = 1;
          jpeg_read_scanlines(&local_348);
        } while (local_2b0 < local_2d0);
      }
      jpeg_finish_decompress(&local_348);
      jpeg_destroy_decompress(&local_348);
      free(*(void **)(param_1 + 0x1f8));
      *(undefined8 *)(param_1 + 0x1f8) = 0;
      LeaveCriticalSection((LPCRITICAL_SECTION)(param_1 + 0x18));
      if (*(int *)(*(longlong *)(param_1 + 0x1c8) + 0x2c8) != 0) {
        pCVar3 = FUN_140020e30(param_1 + 0x50,local_358,uVar6,uVar7);
        pIVar4 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             *)&local_368);
        pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           (local_360,pIVar4);
        ATL::CSimpleStringT<char,1>::Concatenate
                  ((CSimpleStringT<char,1> *)local_360,local_368,*(int *)(local_368 + -0x10),
                   *(char **)pCVar3,*(int *)(*(char **)pCVar3 + -0x10));
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   (*(longlong *)(param_1 + 0x1c8) + 0x350),pCVar5);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_360);
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_358);
      }
    }
    fVar8 = (float)*(int *)(param_1 + 0xa4);
    fVar9 = fVar2;
    if (fVar8 <= fVar2) {
      fVar9 = fVar8;
    }
    *(int *)(param_1 + 0xa4) = *(int *)(param_1 + 0xa4) - (int)fVar9;
    if (*(longlong *)(param_1 + 0x1d8) == 0) {
      FUN_1400190f0(*(CWnd **)(param_1 + 0x1c8),
                    *(uint **)(*(longlong *)(param_1 + 0x90) +
                              ((ulonglong)
                               ((*(int *)(param_1 + 0x9c) - *(int *)(param_1 + 0x1a0)) +
                               *(uint *)(param_1 + 0x84)) % (ulonglong)*(uint *)(param_1 + 0x84)) *
                              8),(undefined1 *)(ulonglong)*(uint *)(param_1 + 0x7c),(uint *)0x0);
    }
    if (*(CWnd **)(param_1 + 0x1d0) != (CWnd *)0x0) {
      FUN_1400190f0(*(CWnd **)(param_1 + 0x1d0),
                    *(uint **)(*(longlong *)(param_1 + 0x90) +
                              ((ulonglong)
                               ((*(int *)(param_1 + 0x9c) - *(int *)(param_1 + 0x1a0)) +
                               *(uint *)(param_1 + 0x84)) % (ulonglong)*(uint *)(param_1 + 0x84)) *
                              8),(undefined1 *)(ulonglong)*(uint *)(param_1 + 0x7c),(uint *)0x0);
    }
    if (*(CWnd **)(param_1 + 0x1d8) != (CWnd *)0x0) {
      FUN_1400190f0(*(CWnd **)(param_1 + 0x1d8),*(uint **)(param_1 + 0x1e0),
                    (undefined1 *)(ulonglong)*(uint *)(param_1 + 0x1e8),(uint *)0x0);
    }
    iVar1 = *(int *)(param_1 + 0x40);
  }
  SetEvent(*(HANDLE *)(param_1 + 0x1b8));
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_368
            );
  return;
}

