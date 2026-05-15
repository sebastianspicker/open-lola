
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */

void FUN_1400107c0(longlong param_1)

{
  int iVar1;
  int iVar2;
  uint uVar3;
  void *pvVar4;
  bool bVar5;
  int iVar6;
  IAtlStringMgr *pIVar7;
  undefined8 *puVar8;
  _iobuf *p_Var9;
  locale *plVar10;
  _Facet_base *p_Var11;
  basic_streambuf<char,struct_std::char_traits<char>_> *pbVar12;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar13;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar14;
  void *pvVar15;
  uint uVar16;
  basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> *pbVar17;
  size_t sVar18;
  vector<int,class_std::allocator<int>_> *pvVar19;
  int *piVar20;
  uint uVar21;
  uint uVar22;
  undefined1 auStackY_5c8 [32];
  int *local_580;
  uint local_578;
  undefined4 local_574;
  uint local_570;
  int local_56c;
  int local_568;
  char *local_560;
  char *local_558;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_550 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_548 [8];
  int *local_540;
  vector<int,class_std::allocator<int>_> *local_538;
  char **local_530;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_528 [8];
  int *local_520;
  vector<int,class_std::allocator<int>_> *local_518;
  char **local_510;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_508 [8];
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
  uint local_330;
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
  ulonglong local_f0;
  _Facet_base *local_d8;
  undefined1 local_cf;
  undefined8 local_cc;
  undefined1 local_c4;
  _iobuf *local_c0;
  basic_ios<char,struct_std::char_traits<char>_> local_a0 [104];
  ulonglong local_38;
  
  local_3b8 = 0xfffffffffffffffe;
  local_38 = DAT_1400630d8 ^ (ulonglong)auStackY_5c8;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_580
            );
  uVar21 = 0;
  uVar16 = *(uint *)(param_1 + 0x10dc) >> 3;
  iVar6 = 0;
  if (uVar16 != 1) {
    iVar6 = 0x10;
  }
  iVar1 = *(int *)(param_1 + 0x1984);
  uVar22 = *(uint *)(param_1 + 0x10dc) * *(int *)(param_1 + 0x10cc) * *(int *)(param_1 + 0x10c8) >>
           3;
  local_574 = *(undefined4 *)(*(longlong *)(param_1 + 0x440) + 0x9c);
  local_570 = uVar16;
  local_56c = iVar1;
  local_568 = iVar6;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)&local_558
             ,"Video Recording: ");
  ResetEvent(*(HANDLE *)(param_1 + 0x458));
  iVar2 = *(int *)(param_1 + 0x1980);
  do {
    if ((iVar2 == 0) ||
       (WaitForSingleObject(*(HANDLE *)(param_1 + 0x458),0xffffffff),
       *(int *)(param_1 + 0x1980) == 0)) {
      SetEvent(*(HANDLE *)(param_1 + 0x1978));
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_558);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_580);
      return;
    }
    ResetEvent(*(HANDLE *)(param_1 + 0x458));
    if (*(int *)(*(longlong *)(param_1 + 0x1840) + 0x2c8) != 0) {
      FUN_140020e20(param_1 + 0x1170);
    }
    if (iVar1 == 0) {
      local_138 = *(longlong *)(param_1 + 0x1988);
      local_140 = (undefined **)CONCAT44(*(int *)(param_1 + 0x10c8),*(int *)(param_1 + 0x10cc));
      local_130 = (int *)0x0;
      local_110 = 0;
      local_108 = &local_140;
      local_100 = &local_f8;
      uVar3 = 1;
      if (uVar16 != 1) {
        uVar3 = 3;
      }
      local_f0 = (ulonglong)uVar3;
      local_f8 = (longlong)*(int *)(param_1 + 0x10c8) * local_f0;
      local_148 = (undefined *)(CONCAT44(2,iVar6 + 0x42ff0000) | 0x4000);
      local_120 = local_f8 * *(int *)(param_1 + 0x10cc) + local_138;
      local_128 = local_138;
      local_118 = local_120;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_580,"_Local_%07d.bmp",(ulonglong)uVar21);
      pIVar7 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)(param_1 + 0x1970));
      puVar8 = (undefined8 *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_550,pIVar7);
      piVar20 = local_580;
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_550,*(char **)(param_1 + 0x1970),
                 *(int *)(*(char **)(param_1 + 0x1970) + -0x10),(char *)local_580,local_580[-4]);
      local_158 = 0;
      local_150 = 0xf;
      local_168 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>)0x0;
      sVar18 = 0xffffffffffffffff;
      do {
        sVar18 = sVar18 + 1;
      } while (*(char *)((longlong)*puVar8 + sVar18) != '\0');
      FUN_14000ab60((longlong *)&local_168,(void *)*puVar8,sVar18);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_550);
      cv::_InputArray::_InputArray(local_390,(Mat *)&local_148);
      local_4e8 = (void *)0x0;
      uStack_4e0 = 0;
      local_4d8 = 0;
      pvVar19 = (vector<int,class_std::allocator<int>_> *)&local_4e8;
      cv::imwrite(&local_168,local_390,pvVar19);
      if (local_4e8 != (void *)0x0) {
        pvVar15 = local_4e8;
        if ((0xfff < (ulonglong)((local_4d8 - (longlong)local_4e8 >> 2) * 4)) &&
           (pvVar15 = *(void **)((longlong)local_4e8 + -8),
           0x1f < (ulonglong)((longlong)local_4e8 + (-8 - (longlong)pvVar15)))) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
        free(pvVar15);
      }
      if (0xf < local_150) {
        pvVar4 = (void *)CONCAT71(uStack_167,local_168);
        pvVar15 = pvVar4;
        if ((0xfff < local_150 + 1) &&
           (pvVar15 = *(void **)((longlong)pvVar4 + -8),
           0x1f < (ulonglong)((longlong)pvVar4 + (-8 - (longlong)pvVar15)))) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
        free(pvVar15);
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
    else if ((*(int *)(param_1 + 0x1114) == 1) && (*(int *)(param_1 + 0x118c) != 0)) {
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_580,"_Local_%07d.jpg",(ulonglong)uVar21);
      pIVar7 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)(param_1 + 0x1970));
      puVar8 = (undefined8 *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_548,pIVar7);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_548,*(char **)(param_1 + 0x1970),
                 *(int *)(*(char **)(param_1 + 0x1970) + -0x10),(char *)local_580,local_580[-4]);
      local_158 = 0;
      local_150 = 0xf;
      local_168 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>)0x0;
      sVar18 = 0xffffffffffffffff;
      do {
        sVar18 = sVar18 + 1;
      } while (*(char *)((longlong)*puVar8 + sVar18) != '\0');
      FUN_14000ab60((longlong *)&local_168,(void *)*puVar8,sVar18);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_548);
      pbVar17 = &local_168;
      if (0xf < local_150) {
        pbVar17 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> *)
                  CONCAT71(uStack_167,local_168);
      }
      local_148 = &DAT_140044c98;
      std::basic_ios<char,struct_std::char_traits<char>_>::
      basic_ios<char,struct_std::char_traits<char>_>(local_a0);
      piVar20 = (int *)0x0;
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
      p_Var9 = std::_Fiopen((char *)pbVar17,0x22,0x40);
      if (p_Var9 == (_iobuf *)0x0) {
        pvVar19 = (vector<int,class_std::allocator<int>_> *)0x0;
        std::basic_ios<char,struct_std::char_traits<char>_>::setstate
                  ((basic_ios<char,struct_std::char_traits<char>_> *)
                   ((longlong)&local_148 + (longlong)*(int *)(local_148 + 4)),2,false);
      }
      else {
        local_c4 = 1;
        local_cf = 0;
        std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                  ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
        local_530 = (char **)0x0;
        local_538 = (vector<int,class_std::allocator<int>_> *)0x0;
        local_540 = (int *)0x0;
        _get_stream_buffer_pointers(p_Var9,&local_530,&local_538,&local_540);
        pvVar19 = local_538;
        piVar20 = local_540;
        std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                  ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140,local_530,
                   (char **)local_538,local_540,local_530,(char **)local_538,local_540);
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
          pvVar19 = (vector<int,class_std::allocator<int>_> *)*puVar8;
          (**(code **)pvVar19)(puVar8,1);
        }
      }
      *(undefined ***)((longlong)&local_148 + (longlong)*(int *)(local_148 + 4)) =
           std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&local_150 + (longlong)*(int *)(local_148 + 4) + 4) =
           *(int *)(local_148 + 4) + -0xa8;
      if (local_c0 != (_iobuf *)0x0) {
        pvVar19 = (vector<int,class_std::allocator<int>_> *)(longlong)*(int *)(param_1 + 0x1990);
        std::basic_ostream<char,struct_std::char_traits<char>_>::write
                  ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_148,
                   *(char **)(param_1 + 0x1988),(__int64)pvVar19);
        pbVar12 = FUN_140013c90((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_140);
        if (pbVar12 == (basic_streambuf<char,struct_std::char_traits<char>_> *)0x0) {
          pvVar19 = (vector<int,class_std::allocator<int>_> *)0x0;
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
        pvVar4 = (void *)CONCAT71(uStack_167,local_168);
        pvVar15 = pvVar4;
        if ((0xfff < local_150 + 1) &&
           (pvVar15 = *(void **)((longlong)pvVar4 + -8),
           0x1f < (ulonglong)((longlong)pvVar4 + (-8 - (longlong)*(void **)((longlong)pvVar4 + -8)))
           )) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
LAB_14001144d:
        free(pvVar15);
      }
    }
    else {
      local_560 = malloc((ulonglong)uVar22);
      local_578 = uVar22;
      memset(local_368,0,0x1f8);
      memset(&local_148,0,0xa8);
      local_368[0] = jpeg_std_error(&local_148);
      jpeg_CreateCompress(local_368,0x3e,0x1f8);
      local_338 = *(int *)(param_1 + 0x10c8);
      local_334 = *(uint *)(param_1 + 0x10cc);
      local_330 = *(uint *)(param_1 + 0x10dc) >> 3;
      local_32c = (local_330 == 3) + 1;
      jpeg_set_defaults(local_368);
      jpeg_set_quality(local_368,local_574,1);
      jpeg_mem_dest(local_368,&local_560,&local_578);
      jpeg_start_compress(local_368,1);
      iVar6 = local_330 * local_338;
      if (local_248 < local_334) {
        do {
          local_500 = (ulonglong)(local_248 * iVar6) + *(longlong *)(param_1 + 0x1988);
          jpeg_write_scanlines(local_368,&local_500,1);
        } while (local_248 < local_334);
      }
      jpeg_finish_compress(local_368);
      jpeg_destroy_compress(local_368);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_580,"_Local_%07d.jpg",(ulonglong)uVar21);
      pIVar7 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)(param_1 + 0x1970));
      puVar8 = (undefined8 *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_528,pIVar7);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_528,*(char **)(param_1 + 0x1970),
                 *(int *)(*(char **)(param_1 + 0x1970) + -0x10),(char *)local_580,local_580[-4]);
      local_158 = 0;
      local_150 = 0xf;
      local_168 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>)0x0;
      sVar18 = 0xffffffffffffffff;
      do {
        sVar18 = sVar18 + 1;
      } while (*(char *)((longlong)*puVar8 + sVar18) != '\0');
      FUN_14000ab60((longlong *)&local_168,(void *)*puVar8,sVar18);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_528);
      pbVar17 = &local_168;
      if (0xf < local_150) {
        pbVar17 = (basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_> *)
                  CONCAT71(uStack_167,local_168);
      }
      local_4c8 = &DAT_140044c98;
      std::basic_ios<char,struct_std::char_traits<char>_>::
      basic_ios<char,struct_std::char_traits<char>_>(local_420);
      piVar20 = (int *)0x0;
      std::basic_ostream<char,struct_std::char_traits<char>_>::
      basic_ostream<char,struct_std::char_traits<char>_>
                ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8,
                 (basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0,false);
      *(undefined ***)
       ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8 + *(int *)(local_4c8 + 4))
           = std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
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
      p_Var9 = std::_Fiopen((char *)pbVar17,0x22,0x40);
      if (p_Var9 == (_iobuf *)0x0) {
        pvVar19 = (vector<int,class_std::allocator<int>_> *)0x0;
        std::basic_ios<char,struct_std::char_traits<char>_>::setstate
                  ((basic_ios<char,struct_std::char_traits<char>_> *)
                   ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8 +
                   *(int *)(local_4c8 + 4)),2,false);
      }
      else {
        local_444 = 1;
        local_44f = 0;
        std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                  ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
        local_510 = (char **)0x0;
        local_518 = (vector<int,class_std::allocator<int>_> *)0x0;
        local_520 = (int *)0x0;
        _get_stream_buffer_pointers(p_Var9,&local_510,&local_518,&local_520);
        pvVar19 = local_518;
        piVar20 = local_520;
        std::basic_streambuf<char,struct_std::char_traits<char>_>::_Init
                  ((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0,local_510,
                   (char **)local_518,local_520,local_510,(char **)local_518,local_520);
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
          pvVar19 = (vector<int,class_std::allocator<int>_> *)*puVar8;
          (**(code **)pvVar19)(puVar8,1);
        }
      }
      *(undefined ***)
       ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8 + *(int *)(local_4c8 + 4))
           = std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&iStack_4cc + (longlong)*(int *)(local_4c8 + 4)) =
           *(int *)(local_4c8 + 4) + -0xa8;
      if (local_440 != (_iobuf *)0x0) {
        pvVar19 = (vector<int,class_std::allocator<int>_> *)(ulonglong)local_578;
        std::basic_ostream<char,struct_std::char_traits<char>_>::write
                  ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8,local_560,
                   (__int64)pvVar19);
        pbVar12 = FUN_140013c90((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
        if (pbVar12 == (basic_streambuf<char,struct_std::char_traits<char>_> *)0x0) {
          pvVar19 = (vector<int,class_std::allocator<int>_> *)0x0;
          std::basic_ios<char,struct_std::char_traits<char>_>::setstate
                    ((basic_ios<char,struct_std::char_traits<char>_> *)
                     ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8 +
                     *(int *)(local_4c8 + 4)),2,false);
        }
      }
      if (local_560 != (char *)0x0) {
        free(local_560);
      }
      *(undefined ***)
       ((basic_ostream<char,struct_std::char_traits<char>_> *)&local_4c8 + *(int *)(local_4c8 + 4))
           = std::basic_ofstream<char,struct_std::char_traits<char>_>::vftable;
      *(int *)((longlong)&iStack_4cc + (longlong)*(int *)(local_4c8 + 4)) =
           *(int *)(local_4c8 + 4) + -0xa8;
      FUN_14000e800((basic_streambuf<char,struct_std::char_traits<char>_> *)&local_4c0);
      std::basic_ostream<char,struct_std::char_traits<char>_>::
      ~basic_ostream<char,struct_std::char_traits<char>_>(local_4b8);
      std::basic_ios<char,struct_std::char_traits<char>_>::
      ~basic_ios<char,struct_std::char_traits<char>_>(local_420);
      if (0xf < local_150) {
        pvVar4 = (void *)CONCAT71(uStack_167,local_168);
        pvVar15 = pvVar4;
        if ((0xfff < local_150 + 1) &&
           (pvVar15 = *(void **)((longlong)pvVar4 + -8),
           0x1f < (ulonglong)((longlong)pvVar4 + (-8 - (longlong)pvVar15)))) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
        goto LAB_14001144d;
      }
    }
    if (*(int *)(*(longlong *)(param_1 + 0x1840) + 0x2c8) != 0) {
      pCVar13 = FUN_140020e30(param_1 + 0x1170,local_4f8,pvVar19,piVar20);
      pIVar7 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)&local_558);
      pCVar14 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                          (local_508,pIVar7);
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_508,local_558,*(int *)(local_558 + -0x10),
                 *(char **)pCVar13,*(int *)(*(char **)pCVar13 + -0x10));
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (*(longlong *)(param_1 + 0x1840) + 0x358),pCVar14);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_508);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_4f8);
    }
    uVar21 = uVar21 + 1;
    iVar2 = *(int *)(param_1 + 0x1980);
    uVar16 = local_570;
    iVar1 = local_56c;
    iVar6 = local_568;
  } while( true );
}

