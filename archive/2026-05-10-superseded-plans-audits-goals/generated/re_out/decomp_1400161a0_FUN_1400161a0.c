
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_1400161a0(longlong param_1)

{
  uint uVar1;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *this;
  int iVar2;
  void *pvVar3;
  uint uVar4;
  bool bVar5;
  int iVar6;
  IAtlStringMgr *pIVar7;
  undefined8 *puVar8;
  _iobuf *p_Var9;
  locale *plVar10;
  _Facet_base *p_Var11;
  basic_streambuf<char,struct_std::char_traits<char>_> *pbVar12;
  void *pvVar13;
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> *pbVar14;
  size_t sVar15;
  int iVar16;
  uint uVar17;
  undefined1 auStackY_5b8 [32];
  char *local_570;
  uint local_568;
  uint local_564;
  undefined4 local_560;
  uint local_55c;
  char *local_558;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_550 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_548 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_540 [8];
  int *local_538;
  char **local_530;
  char **local_528;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_520 [8];
  int *local_518;
  char **local_510;
  char **local_508;
  longlong local_500;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_4f8 [8];
  undefined ***local_4f0;
  void *local_4e8;
  undefined8 uStack_4e0;
  longlong local_4d8;
  int iStack_4cc;
  undefined *local_4c8;
  undefined **local_4c0;
  basic_ostream<char,struct_std::char_traits<char>_> local_4b8 [96];
  _Facet_base *local_458;
  undefined1 local_44f;
  undefined8 local_44c;
  undefined1 local_444;
  _iobuf *local_440;
  basic_ios<char,struct_std::char_traits<char>_> local_420 [104];
  undefined8 local_3b8;
  longlong *local_3a8;
  longlong *local_398;
  _InputArray local_390 [40];
  undefined8 local_368 [6];
  int local_338;
  uint local_334;
  int local_330;
  int local_32c;
  uint local_248;
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> local_168;
  undefined7 uStack_167;
  undefined8 local_158;
  undefined8 local_150;
  undefined *local_148;
  undefined8 local_140;
  longlong local_138;
  int *local_130;
  longlong local_128;
  longlong local_120;
  longlong local_118;
  undefined8 local_110;
  undefined8 *local_108;
  longlong *local_100;
  longlong local_f8;
  longlong local_f0;
  _Facet_base *local_d8;
  undefined1 local_cf;
  undefined8 local_cc;
  undefined1 local_c4;
  _iobuf *local_c0;
  basic_ios<char,struct_std::char_traits<char>_> local_a0 [104];
  ulonglong local_38;
  
  local_3b8 = 0xfffffffffffffffe;
  local_38 = DAT_1400630d8 ^ (ulonglong)auStackY_5b8;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_570
            );
  uVar17 = 0;
  uVar1 = *(int *)(param_1 + 0x2c0) - 8;
  iVar16 = 0;
  if (7 < uVar1) {
    iVar16 = 0x10;
  }
  iVar2 = *(int *)(*(longlong *)(param_1 + 600) + 0x140);
  iVar6 = *(int *)(param_1 + 0x2c0) * *(int *)(param_1 + 0x2c4) * *(int *)(param_1 + 0x2c8);
  local_564 = (int)(iVar6 + (iVar6 >> 0x1f & 7U)) >> 3;
  local_560 = *(undefined4 *)(*(longlong *)(param_1 + 600) + 0x9c);
  local_55c = uVar1;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            (local_4f8,"Video Recording: ");
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_550);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
            (local_550,"_%dfps",(ulonglong)(uint)(int)*(double *)(param_1 + 0x2b8));
  this = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
         (param_1 + 0x368);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator+=
            (this,(CSimpleStringT<char,1> *)local_550);
  ResetEvent(*(HANDLE *)(param_1 + 0x370));
  iVar6 = *(int *)(param_1 + 0x380);
  do {
    if ((iVar6 == 0) ||
       (WaitForSingleObject(*(HANDLE *)(param_1 + 0x370),0xffffffff), *(int *)(param_1 + 0x380) == 0
       )) {
      SetEvent(*(HANDLE *)(param_1 + 0x378));
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_550);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_4f8);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_570);
      return;
    }
    ResetEvent(*(HANDLE *)(param_1 + 0x370));
    uVar4 = local_564;
    if ((iVar2 == 0) && (*(int *)(param_1 + 0x250) == 0)) {
      local_138 = *(longlong *)(param_1 + 0x388);
      local_140 = (undefined **)CONCAT44(*(int *)(param_1 + 0x2c4),*(int *)(param_1 + 0x2c8));
      local_130 = (int *)0x0;
      local_110 = 0;
      local_108 = &local_140;
      local_100 = &local_f8;
      local_f0 = 1;
      if (7 < uVar1) {
        local_f0 = 3;
      }
      local_f8 = *(int *)(param_1 + 0x2c4) * local_f0;
      local_148 = (undefined *)(CONCAT44(2,iVar16 + 0x42ff0000) | 0x4000);
      local_120 = local_f8 * *(int *)(param_1 + 0x2c8) + local_138;
      local_128 = local_138;
      local_118 = local_120;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_570,"_Remote_%07d.bmp",(ulonglong)uVar17);
      pIVar7 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(this);
      puVar8 = (undefined8 *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_548,pIVar7);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_548,*(char **)this,*(int *)(*(char **)this + -0x10)
                 ,local_570,*(int *)(local_570 + -0x10));
      local_158 = 0;
      local_150 = 0xf;
      local_168 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>)0x0;
      sVar15 = 0xffffffffffffffff;
      do {
        sVar15 = sVar15 + 1;
      } while (*(char *)((longlong)*puVar8 + sVar15) != '\0');
      FUN_14000ab60((longlong *)&local_168,(void *)*puVar8,sVar15);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_548);
      cv::_InputArray::_InputArray(local_390,(Mat *)&local_148);
      local_4e8 = (void *)0x0;
      uStack_4e0 = 0;
      local_4d8 = 0;
      cv::imwrite(&local_168,local_390,(vector<int,class_std::allocator<int>_> *)&local_4e8);
      if (local_4e8 != (void *)0x0) {
        pvVar13 = local_4e8;
        if ((0xfff < (ulonglong)((local_4d8 - (longlong)local_4e8 >> 2) * 4)) &&
           (pvVar13 = *(void **)((longlong)local_4e8 + -8),
           0x1f < (ulonglong)((longlong)local_4e8 + (-8 - (longlong)pvVar13)))) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
        free(pvVar13);
      }
      if (0xf < local_150) {
        pvVar3 = (void *)CONCAT71(uStack_167,local_168);
        pvVar13 = pvVar3;
        if ((0xfff < local_150 + 1) &&
           (pvVar13 = *(void **)((longlong)pvVar3 + -8),
           0x1f < (ulonglong)((longlong)pvVar3 + (-8 - (longlong)pvVar13)))) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
        free(pvVar13);
      }
      local_158 = 0;
      local_150 = 0xf;
      local_168 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>)0x0;
      if ((local_130 != (int *)0x0) &&
         (iVar6 = cv::_interlockedExchangeAdd(local_130,-1), iVar6 == 1)) {
        cv::Mat::deallocate((Mat *)&local_148);
      }
      local_118 = 0;
      local_120 = 0;
      local_128 = 0;
      local_138 = 0;
      *(undefined4 *)local_108 = 0;
      local_130 = (int *)0x0;
      if (local_100 != &local_f8) {
        cv::fastFree(local_100);
      }
    }
    else if (*(int *)(param_1 + 0x250) == 1) {
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_570,"_Remote_%07d.jpg",(ulonglong)uVar17);
      pIVar7 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(this);
      puVar8 = (undefined8 *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_540,pIVar7);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_540,*(char **)this,*(int *)(*(char **)this + -0x10)
                 ,local_570,*(int *)(local_570 + -0x10));
      local_158 = 0;
      local_150 = 0xf;
      local_168 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>)0x0;
      sVar15 = 0xffffffffffffffff;
      do {
        sVar15 = sVar15 + 1;
      } while (*(char *)((longlong)*puVar8 + sVar15) != '\0');
      FUN_14000ab60((longlong *)&local_168,(void *)*puVar8,sVar15);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_540);
      pbVar14 = &local_168;
      if (0xf < local_150) {
        pbVar14 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> *)
                  CONCAT71(uStack_167,local_168);
      }
      local_148 = &DAT_140044c98;
      std::basic_ios<char,struct_std::char_traits<char>_>::
      basic_ios<char,struct_std::char_traits<char>_>(local_a0);
      std::basic_ostream<char,struct_std::char_traits<char>_>::
      basic_ostream<char,struct_std::char_traits<char>_>
                ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_148,
                 (basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140,false);
      *(undefined ***)((longlong)&local_148 + (longlong)*(int *)(local_148 + 4)) =
           std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&local_150 + (longlong)*(int *)(local_148 + 4) + 4) =
           *(int *)(local_148 + 4) + -0xa8;
      local_4f0 = (undefined ***)&local_140;
      std::basic_streambuf<char,struct_std::char_traits<char>_>::
      basic_streambuf<char,struct_std::char_traits<char>_>
                ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
      local_140 = std::basic_filebuf<char,struct_std::char_traits<char>_>::vftable;
      local_c4 = 0;
      local_cf = 0;
      std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
      local_c0 = (_iobuf *)0x0;
      local_cc = DAT_140063e98;
      local_d8 = (_Facet_base *)0x0;
      p_Var9 = std::_Fiopen((char *)pbVar14,0x22,0x40);
      if (p_Var9 == (_iobuf *)0x0) {
        std::basic_ios<char,struct_std::char_traits<char>_>::setstate
                  ((basic_ios<char,struct_std::char_traits<char>_> *)
                   ((longlong)&local_148 + (longlong)*(int *)(local_148 + 4)),2,false);
      }
      else {
        local_c4 = 1;
        local_cf = 0;
        std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                  ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
        local_528 = (char **)0x0;
        local_530 = (char **)0x0;
        local_538 = (int *)0x0;
        _get_stream_buffer_pointers(p_Var9,&local_528,&local_530,&local_538);
        std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                  ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140,local_528,
                   local_530,local_538,local_528,local_530,local_538);
        local_cc = DAT_140063e98;
        local_d8 = (_Facet_base *)0x0;
        local_c0 = p_Var9;
        plVar10 = (locale *)
                  std::basic_streambuf<char,struct_std::char_traits<char>_>::getloc
                            ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
        p_Var11 = FUN_14000e0b0(plVar10);
        bVar5 = std::codecvt_base::always_noconv((codecvt_base *)p_Var11);
        if (bVar5) {
          local_d8 = (_Facet_base *)0x0;
        }
        else {
          local_d8 = p_Var11;
          std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                    ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
        }
        if ((local_3a8 != (longlong *)0x0) &&
           (puVar8 = (undefined8 *)(**(code **)(*local_3a8 + 0x10))(), puVar8 != (undefined8 *)0x0))
        {
          (**(code **)*puVar8)(puVar8,1);
        }
      }
      *(undefined ***)((longlong)&local_148 + (longlong)*(int *)(local_148 + 4)) =
           std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&local_150 + (longlong)*(int *)(local_148 + 4) + 4) =
           *(int *)(local_148 + 4) + -0xa8;
      if (local_c0 != (_iobuf *)0x0) {
        std::basic_ostream<char,struct_std::char_traits<char>_>::write
                  ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_148,
                   *(char **)(param_1 + 0x388),(longlong)*(int *)(param_1 + 0x390));
        pbVar12 = FUN_140013c90((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
        if (pbVar12 == (basic_streambuf<char,struct_std::char_traits<char>_> *)0x0) {
          std::basic_ios<char,struct_std::char_traits<char>_>::setstate
                    ((basic_ios<char,struct_std::char_traits<char>_> *)
                     ((longlong)&local_148 + (longlong)*(int *)(local_148 + 4)),2,false);
        }
      }
      *(undefined ***)((longlong)&local_148 + (longlong)*(int *)(local_148 + 4)) =
           std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&local_150 + (longlong)*(int *)(local_148 + 4) + 4) =
           *(int *)(local_148 + 4) + -0xa8;
      FUN_14000e800((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
      std::basic_ostream<char,struct_std::char_traits<char>_>::
      ~basic_ostream<char,struct_std::char_traits<char>_>
                ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_138);
      std::basic_ios<char,struct_std::char_traits<char>_>::
      ~basic_ios<char,struct_std::char_traits<char>_>(local_a0);
      if (0xf < local_150) {
        pvVar3 = (void *)CONCAT71(uStack_167,local_168);
        pvVar13 = pvVar3;
        if ((0xfff < local_150 + 1) &&
           (pvVar13 = *(void **)((longlong)pvVar3 + -8),
           0x1f < (ulonglong)((longlong)pvVar3 + (-8 - (longlong)*(void **)((longlong)pvVar3 + -8)))
           )) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
LAB_140016e47:
        free(pvVar13);
      }
    }
    else {
      local_558 = malloc((longlong)(int)local_564);
      local_568 = uVar4;
      memset(local_368,0,0x1f8);
      memset(&local_148,0,0xa8);
      local_368[0] = jpeg_std_error(&local_148);
      jpeg_CreateCompress(local_368,0x3e,0x1f8);
      local_338 = *(int *)(param_1 + 0x2c4);
      local_334 = *(uint *)(param_1 + 0x2c8);
      iVar6 = *(int *)(param_1 + 0x2c0);
      local_330 = (int)(iVar6 + (iVar6 >> 0x1f & 7U)) >> 3;
      local_32c = (iVar6 - 0x18U < 8) + 1;
      jpeg_set_defaults(local_368);
      jpeg_set_quality(local_368,local_560,1);
      jpeg_mem_dest(local_368,&local_558,&local_568);
      jpeg_start_compress(local_368,1);
      iVar6 = local_330 * local_338;
      if (local_248 < local_334) {
        do {
          local_500 = (ulonglong)(local_248 * iVar6) + *(longlong *)(param_1 + 0x388);
          jpeg_write_scanlines(local_368,&local_500,1);
        } while (local_248 < local_334);
      }
      jpeg_finish_compress(local_368);
      jpeg_destroy_compress(local_368);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_570,"_Remote_%07d.jpg",(ulonglong)uVar17);
      pIVar7 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(this);
      puVar8 = (undefined8 *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_520,pIVar7);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_520,*(char **)this,*(int *)(*(char **)this + -0x10)
                 ,local_570,*(int *)(local_570 + -0x10));
      local_158 = 0;
      local_150 = 0xf;
      local_168 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>)0x0;
      sVar15 = 0xffffffffffffffff;
      do {
        sVar15 = sVar15 + 1;
      } while (*(char *)((longlong)*puVar8 + sVar15) != '\0');
      FUN_14000ab60((longlong *)&local_168,(void *)*puVar8,sVar15);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_520);
      pbVar14 = &local_168;
      if (0xf < local_150) {
        pbVar14 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> *)
                  CONCAT71(uStack_167,local_168);
      }
      local_4c8 = &DAT_140044c98;
      std::basic_ios<char,struct_std::char_traits<char>_>::
      basic_ios<char,struct_std::char_traits<char>_>(local_420);
      std::basic_ostream<char,struct_std::char_traits<char>_>::
      basic_ostream<char,struct_std::char_traits<char>_>
                ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8,
                 (basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0,false);
      *(undefined ***)((longlong)&local_4c8 + (longlong)*(int *)(local_4c8 + 4)) =
           std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&iStack_4cc + (longlong)*(int *)(local_4c8 + 4)) =
           *(int *)(local_4c8 + 4) + -0xa8;
      local_4f0 = &local_4c0;
      std::basic_streambuf<char,struct_std::char_traits<char>_>::
      basic_streambuf<char,struct_std::char_traits<char>_>
                ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
      local_4c0 = std::basic_filebuf<char,struct_std::char_traits<char>_>::vftable;
      local_444 = 0;
      local_44f = 0;
      std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
      local_440 = (_iobuf *)0x0;
      local_44c = DAT_140063e98;
      local_458 = (_Facet_base *)0x0;
      p_Var9 = std::_Fiopen((char *)pbVar14,0x22,0x40);
      if (p_Var9 == (_iobuf *)0x0) {
        std::basic_ios<char,struct_std::char_traits<char>_>::setstate
                  ((basic_ios<char,struct_std::char_traits<char>_> *)
                   ((longlong)&local_4c8 + (longlong)*(int *)(local_4c8 + 4)),2,false);
      }
      else {
        local_444 = 1;
        local_44f = 0;
        std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                  ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
        local_508 = (char **)0x0;
        local_510 = (char **)0x0;
        local_518 = (int *)0x0;
        _get_stream_buffer_pointers(p_Var9,&local_508,&local_510,&local_518);
        std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                  ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0,local_508,
                   local_510,local_518,local_508,local_510,local_518);
        local_44c = DAT_140063e98;
        local_458 = (_Facet_base *)0x0;
        local_440 = p_Var9;
        plVar10 = (locale *)
                  std::basic_streambuf<char,struct_std::char_traits<char>_>::getloc
                            ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
        p_Var11 = FUN_14000e0b0(plVar10);
        bVar5 = std::codecvt_base::always_noconv((codecvt_base *)p_Var11);
        if (bVar5) {
          local_458 = (_Facet_base *)0x0;
        }
        else {
          local_458 = p_Var11;
          std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                    ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
        }
        if ((local_398 != (longlong *)0x0) &&
           (puVar8 = (undefined8 *)(**(code **)(*local_398 + 0x10))(), puVar8 != (undefined8 *)0x0))
        {
          (**(code **)*puVar8)(puVar8,1);
        }
      }
      *(undefined ***)((longlong)&local_4c8 + (longlong)*(int *)(local_4c8 + 4)) =
           std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&iStack_4cc + (longlong)*(int *)(local_4c8 + 4)) =
           *(int *)(local_4c8 + 4) + -0xa8;
      if (local_440 != (_iobuf *)0x0) {
        std::basic_ostream<char,struct_std::char_traits<char>_>::write
                  ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8,local_558,
                   (ulonglong)local_568);
        pbVar12 = FUN_140013c90((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
        if (pbVar12 == (basic_streambuf<char,struct_std::char_traits<char>_> *)0x0) {
          std::basic_ios<char,struct_std::char_traits<char>_>::setstate
                    ((basic_ios<char,struct_std::char_traits<char>_> *)
                     ((longlong)&local_4c8 + (longlong)*(int *)(local_4c8 + 4)),2,false);
        }
      }
      if (local_558 != (char *)0x0) {
        free(local_558);
      }
      *(undefined ***)((longlong)&local_4c8 + (longlong)*(int *)(local_4c8 + 4)) =
           std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&iStack_4cc + (longlong)*(int *)(local_4c8 + 4)) =
           *(int *)(local_4c8 + 4) + -0xa8;
      FUN_14000e800((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
      std::basic_ostream<char,struct_std::char_traits<char>_>::
      ~basic_ostream<char,struct_std::char_traits<char>_>(local_4b8);
      std::basic_ios<char,struct_std::char_traits<char>_>::
      ~basic_ios<char,struct_std::char_traits<char>_>(local_420);
      if (0xf < local_150) {
        pvVar3 = (void *)CONCAT71(uStack_167,local_168);
        pvVar13 = pvVar3;
        if ((0xfff < local_150 + 1) &&
           (pvVar13 = *(void **)((longlong)pvVar3 + -8),
           0x1f < (ulonglong)((longlong)pvVar3 + (-8 - (longlong)pvVar13)))) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
        goto LAB_140016e47;
      }
    }
    uVar17 = uVar17 + 1;
    iVar6 = *(int *)(param_1 + 0x380);
    uVar1 = local_55c;
  } while( true );
}

