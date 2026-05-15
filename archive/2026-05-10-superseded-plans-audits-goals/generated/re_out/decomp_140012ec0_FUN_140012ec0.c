
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_140012ec0(longlong param_1,undefined8 param_2,double param_3)

{
  int iVar1;
  undefined1 uVar2;
  int iVar3;
  int iVar4;
  void *pvVar5;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *this;
  IAtlStringMgr *pIVar6;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar7;
  tm *ptVar8;
  undefined8 uVar9;
  int iVar10;
  uint uVar11;
  byte *pbVar12;
  uint uVar13;
  size_t _Size;
  int iVar14;
  uint uVar15;
  ulonglong uVar16;
  ulonglong uVar17;
  size_t sVar18;
  size_t sVar19;
  char *pcVar20;
  longlong lVar21;
  ulonglong uVar22;
  undefined1 auStackY_2a8 [32];
  double in_stack_fffffffffffffd78;
  undefined4 uVar23;
  int local_250;
  uint local_24c;
  undefined4 local_248;
  undefined4 local_244;
  int local_240;
  int local_23c;
  ulonglong local_238;
  uint local_230;
  undefined4 local_22c;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_228 [8];
  size_t local_220;
  int local_218;
  int local_214;
  uint local_210;
  uint local_20c;
  uint local_208;
  uint local_204;
  uint local_200;
  uint local_1fc;
  uint local_1f8;
  uint local_1f4;
  undefined4 local_1f0;
  int local_1ec;
  undefined4 local_1e8;
  int local_1e4;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_1e0 [8];
  undefined8 local_1d8;
  void *local_1d0;
  double dStack_1c8;
  double local_1c0;
  ulonglong uStack_1b8;
  uint local_1a8;
  undefined4 local_1a4;
  uint local_1a0;
  uint local_19c;
  longlong local_198;
  int *local_190;
  longlong local_188;
  longlong local_180;
  longlong local_178;
  undefined8 local_170;
  uint *local_168;
  longlong *local_160;
  longlong local_158;
  longlong local_150;
  void *local_148;
  double dStack_140;
  undefined8 local_138;
  undefined8 uStack_130;
  tm local_128;
  char local_f8 [128];
  ulonglong local_78;
  
  local_1d8 = 0xfffffffffffffffe;
  local_78 = DAT_1400630d8 ^ (ulonglong)auStackY_2a8;
  uVar22 = 0;
  iVar4 = 0;
  local_248 = 0;
  if (*(int *)(param_1 + 0x1110) == 0) {
    uVar11 = *(uint *)(param_1 + 0x10dc);
    local_24c = *(uint *)(param_1 + 0x10d0);
  }
  else {
    uVar11 = *(uint *)(param_1 + 0x10e0);
    local_24c = *(uint *)(param_1 + 0x10d4);
  }
  uVar17 = (ulonglong)local_24c;
  *(undefined4 *)(param_1 + 0x1138) = 0;
  if (*(void **)(param_1 + 0x1130) != (void *)0x0) {
    free(*(void **)(param_1 + 0x1130));
    *(undefined8 *)(param_1 + 0x1130) = 0;
  }
  local_220 = uVar17;
  pvVar5 = operator_new(uVar17);
  *(void **)(param_1 + 0x1130) = pvVar5;
  memset(pvVar5,0,uVar17);
  local_198 = *(longlong *)(param_1 + 0x1130);
  local_19c = *(uint *)(param_1 + 0x10c8);
  local_1a0 = *(uint *)(param_1 + 0x10cc);
  pcVar20 = (char *)(longlong)(int)local_1a0;
  local_1a4 = 2;
  local_190 = (int *)0x0;
  local_170 = 0;
  local_168 = &local_1a0;
  local_160 = &local_158;
  local_150 = 1;
  if (uVar11 == 0x18) {
    local_150 = 3;
  }
  local_158 = (int)local_19c * local_150;
  iVar3 = iVar4;
  if (uVar11 == 0x18) {
    iVar3 = 0x10;
  }
  local_1a8 = iVar3 + 0x42ff0000U | 0x4000;
  local_180 = local_158 * (longlong)pcVar20 + local_198;
  local_188 = local_198;
  local_178 = local_180;
  if (uVar11 == 0x18) {
    pbVar12 = &DAT_140044499;
    uVar17 = uVar22;
    do {
      param_3 = (double)pbVar12[-1];
      dStack_1c8 = (double)*pbVar12;
      local_1d0 = (void *)(double)pbVar12[1];
      uStack_1b8 = 0;
      local_22c = *(undefined4 *)(param_1 + 0x10cc);
      local_230 = *(uint *)(param_1 + 0x10c8) >> 3;
      local_238 = (ulonglong)(local_230 * (int)uVar17);
      in_stack_fffffffffffffd78 =
           (double)CONCAT44((int)((ulonglong)in_stack_fffffffffffffd78 >> 0x20),8);
      pcVar20 = (char *)0xffffffff;
      local_1c0 = param_3;
      cv::rectangle((Mat *)&local_1a8,&local_238,&local_1d0);
      uVar13 = (int)uVar17 + 1;
      uVar17 = (ulonglong)uVar13;
      pbVar12 = pbVar12 + 3;
    } while ((int)uVar13 < 8);
  }
  else {
    uVar17 = uVar22;
    if (local_1a0 != 0) {
      do {
        pcVar20 = (char *)(ulonglong)*(uint *)(param_1 + 0x10c8);
        iVar3 = (int)uVar17;
        if (*(uint *)(param_1 + 0x10c8) != 0) {
          uVar16 = uVar22;
          do {
            iVar14 = (int)uVar16;
            lVar21 = (longlong)(int)(uVar16 / (local_19c >> 3)) * 3;
            uVar16 = (ulonglong)(uint)((int)pcVar20 * iVar3 + iVar14);
            if ((uVar17 & 1) == 0) {
              *(undefined1 *)(uVar16 + *(longlong *)(param_1 + 0x1130)) = (&DAT_140044498)[lVar21];
              iVar10 = *(int *)(param_1 + 0x10c8);
              uVar2 = (&DAT_140044499)[lVar21];
            }
            else {
              *(undefined1 *)(uVar16 + *(longlong *)(param_1 + 0x1130)) = (&DAT_140044499)[lVar21];
              iVar10 = *(int *)(param_1 + 0x10c8);
              uVar2 = (&DAT_14004449a)[lVar21];
            }
            *(undefined1 *)
             ((ulonglong)(uint)(iVar14 + 1 + iVar10 * iVar3) + *(longlong *)(param_1 + 0x1130)) =
                 uVar2;
            uVar16 = (ulonglong)(iVar14 + 2U);
            pcVar20 = (char *)(ulonglong)*(uint *)(param_1 + 0x10c8);
          } while (iVar14 + 2U < *(uint *)(param_1 + 0x10c8));
        }
        uVar17 = (ulonglong)(iVar3 + 1U);
      } while (iVar3 + 1U < *(uint *)(param_1 + 0x10cc));
    }
  }
  *(undefined4 *)(param_1 + 0x478) = 1;
  ResetEvent(*(HANDLE *)(param_1 + 0x460));
  ResetEvent(*(HANDLE *)(param_1 + 0x450));
  iVar14 = 0;
  iVar3 = 0;
  local_250 = 0;
  xiGetParamInt(*(undefined8 *)(param_1 + 0x3d8),&DAT_140044b98,&local_250);
  if (local_250 == 1) {
    iVar3 = 1;
    uVar22 = 1;
    iVar4 = 0;
  }
  else if (local_250 == 4) {
    iVar14 = 1;
    uVar22 = 0;
    iVar4 = 1;
  }
  else if (local_250 == 5) {
    uVar22 = 1;
    iVar4 = 1;
  }
  else {
    iVar3 = iVar4;
    iVar14 = 0;
    if (local_250 == 6) {
      uVar22 = 0;
      iVar3 = 1;
      iVar14 = 1;
      iVar4 = 0;
    }
  }
  iVar10 = *(int *)(param_1 + 0x478);
  _Size = local_220;
  do {
    if (iVar10 == 0) {
LAB_140013969:
      SetEvent(*(HANDLE *)(param_1 + 0x460));
      if ((local_190 != (int *)0x0) &&
         (iVar4 = cv::_interlockedExchangeAdd(local_190,-1), iVar4 == 1)) {
        cv::Mat::deallocate((Mat *)&local_1a8);
      }
      local_178 = 0;
      local_180 = 0;
      local_188 = 0;
      local_198 = 0;
      *local_168 = 0;
      local_190 = (int *)0x0;
      if (local_160 != &local_158) {
        cv::fastFree(local_160);
      }
      return;
    }
    *(int *)(param_1 + 0x1188) = *(int *)(param_1 + 0x1188) + 1;
    iVar10 = (*(int *)(param_1 + 0x1870) + 1) % 0x1e;
    *(int *)(param_1 + 0x1870) = iVar10;
    memset(*(void **)(param_1 + 0x1878 + (longlong)iVar10 * 8),0,_Size);
    lVar21 = *(longlong *)(param_1 + 0x3d8 + (longlong)*(int *)(param_1 + 0x30) * 8);
    if (lVar21 != 0) {
      if (*(int *)(param_1 + 0x478) == 0) goto LAB_140013969;
      xiGetImage(lVar21,1000,param_1 + 0x38 + (longlong)*(int *)(param_1 + 0x30) * 0xe8);
    }
    if (*(int *)(param_1 + 0x478) == 0) goto LAB_140013969;
    if (*(int *)(*(longlong *)(param_1 + 0x1840) + 0x2c8) != 0) {
      FUN_140020e20(param_1 + 0x1140);
    }
    uVar17 = (ulonglong)
             ((uint)(*(int *)(param_1 + 0x10dc) * *(int *)(param_1 + 0x10c8) *
                    *(int *)(param_1 + 0x10cc)) >> 3);
    memcpy(*(void **)(param_1 + 0x1878 + (longlong)*(int *)(param_1 + 0x1870) * 8),
           *(void **)((longlong)*(int *)(param_1 + 0x30) * 0xe8 + 0x40 + param_1),uVar17);
    uVar23 = (undefined4)((ulonglong)in_stack_fffffffffffffd78 >> 0x20);
    if (((*(int *)(param_1 + 0x10a0) != 0) && (uVar11 == 8)) && (*(int *)(param_1 + 0x10cc) != 0)) {
      uVar13 = *(uint *)(param_1 + 0x10c8);
      uVar16 = uVar22;
      do {
        iVar10 = *(int *)(param_1 + 0x1870);
        iVar1 = (int)uVar16;
        lVar21 = (ulonglong)(((iVar14 - (int)uVar22) + iVar1) * uVar13) +
                 *(longlong *)(param_1 + 0x1878 + (longlong)iVar10 * 8);
        uVar15 = 0;
        if (uVar13 != 0) {
          do {
            *(undefined1 *)((ulonglong)(uVar15 + iVar4) + lVar21) =
                 *(undefined1 *)
                  (*(longlong *)(param_1 + 0x1098) +
                  (ulonglong)*(byte *)((ulonglong)(uVar15 + iVar4) + lVar21) * 4);
            uVar15 = uVar15 + 2;
            uVar13 = *(uint *)(param_1 + 0x10c8);
          } while (uVar15 < uVar13);
          iVar10 = *(int *)(param_1 + 0x1870);
        }
        pcVar20 = (char *)((ulonglong)(uVar13 * iVar1) +
                          *(longlong *)(param_1 + 0x1878 + (longlong)iVar10 * 8));
        uVar17 = 0;
        if (uVar13 != 0) {
          do {
            uVar13 = (int)uVar17 + iVar3;
            pcVar20[uVar13] =
                 *(char *)(*(longlong *)(param_1 + 0x1098) + 0x800 +
                          (ulonglong)(byte)pcVar20[uVar13] * 4);
            uVar15 = (int)uVar17 + 2;
            uVar17 = (ulonglong)uVar15;
            uVar13 = *(uint *)(param_1 + 0x10c8);
          } while (uVar15 < uVar13);
        }
        uVar16 = (ulonglong)(iVar1 + 2U);
      } while ((iVar1 + 2U) - (int)uVar22 < *(uint *)(param_1 + 0x10cc));
    }
    if (*(int *)(*(longlong *)(param_1 + 0x1840) + 0x2c8) != 0) {
      this = FUN_140020e30(param_1 + 0x1140,local_1e0,uVar17,pcVar20);
      pIVar6 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               GetManager(this);
      pCVar7 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
               ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
               CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                         (local_228,pIVar6);
      local_248 = 1;
      pcVar20 = *(char **)this;
      in_stack_fffffffffffffd78 = (double)CONCAT44(uVar23,*(int *)(pcVar20 + -0x10));
      ATL::CSimpleStringT<char,1>::Concatenate
                ((CSimpleStringT<char,1> *)local_228,"FrameBufferFill: ",0x11,pcVar20,
                 *(int *)(pcVar20 + -0x10));
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (*(longlong *)(param_1 + 0x1840) + 0x348),pCVar7);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_228);
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_1e0);
      _Size = local_220;
    }
    uVar23 = (undefined4)((ulonglong)in_stack_fffffffffffffd78 >> 0x20);
    if (*(int *)(param_1 + 0x1128) != 0) {
      local_238 = _time64((__time64_t *)0x0);
      ptVar8 = _localtime64((__time64_t *)&local_238);
      local_128.tm_sec = ptVar8->tm_sec;
      local_128.tm_min = ptVar8->tm_min;
      local_128.tm_hour = ptVar8->tm_hour;
      local_128.tm_mday = ptVar8->tm_mday;
      local_128.tm_mon = ptVar8->tm_mon;
      local_128.tm_year = ptVar8->tm_year;
      local_128.tm_wday = ptVar8->tm_wday;
      local_128.tm_yday = ptVar8->tm_yday;
      local_128.tm_isdst = ptVar8->tm_isdst;
      ptVar8 = &local_128;
      strftime(local_f8,0x80,"LoLa AV Test - %#x - %X",ptVar8);
      iVar10 = (int)ptVar8;
      uVar13 = *(uint *)(param_1 + 0x10c8) / 0x14;
      local_244 = 0;
      local_1c0 = 0.0;
      uStack_1b8 = 0xf;
      local_1d0 = (void *)((ulonglong)local_1d0 & 0xffffffffffffff00);
      sVar19 = 0xffffffffffffffff;
      do {
        sVar18 = sVar19 + 1;
        lVar21 = sVar19 + 1;
        sVar19 = sVar18;
      } while (local_f8[lVar21] != '\0');
      FUN_14000ab60((longlong *)&local_1d0,local_f8,sVar18);
      cv::getTextSize((basic_string<char,struct_std::char_traits<char>,class_std::allocator<char>_>
                       *)&local_240,(int)&local_1d0,param_3,iVar10,(int *)CONCAT44(uVar23,1));
      if (0xf < uStack_1b8) {
        pvVar5 = local_1d0;
        if ((0xfff < uStack_1b8 + 1) &&
           (pvVar5 = *(void **)((longlong)local_1d0 + -8),
           0x1f < (ulonglong)((longlong)local_1d0 + (-8 - (longlong)pvVar5)))) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
        free(pvVar5);
      }
      local_1d0 = _DAT_140044de0;
      dStack_1c8 = _UNK_140044de8;
      local_1c0 = (double)_DAT_140044db0;
      uStack_1b8 = _UNK_140044db8;
      local_1e4 = local_23c * 2;
      local_1e8 = *(undefined4 *)(param_1 + 0x10c8);
      local_1ec = *(int *)(param_1 + 0x10cc) + local_23c * -2;
      local_1f0 = 0;
      cv::rectangle((Mat *)&local_1a8,&local_1f0,&local_1d0);
      local_1c0 = 0.0;
      uStack_1b8 = 0xf;
      local_1d0 = (void *)((ulonglong)local_1d0 & 0xffffffffffffff00);
      sVar19 = 0xffffffffffffffff;
      do {
        sVar18 = sVar19 + 1;
        lVar21 = sVar19 + 1;
        sVar19 = sVar18;
      } while (local_f8[lVar21] != '\0');
      FUN_14000ab60((longlong *)&local_1d0,local_f8,sVar18);
      local_148 = (void *)0x0;
      dStack_140 = 0.0;
      local_138 = 0;
      uStack_130 = 0;
      local_214 = (*(int *)(param_1 + 0x10cc) - local_23c / 2) + -1;
      local_218 = (*(uint *)(param_1 + 0x10c8) >> 1) - local_240 / 2;
      pcVar20 = (char *)0x0;
      cv::putText((Mat *)&local_1a8,&local_1d0,&local_218);
      if (0xf < uStack_1b8) {
        pvVar5 = local_1d0;
        if ((0xfff < uStack_1b8 + 1) &&
           (pvVar5 = *(void **)((longlong)local_1d0 + -8),
           0x1f < (ulonglong)((longlong)local_1d0 + (-8 - (longlong)pvVar5)))) {
                    /* WARNING: Subroutine does not return */
          _invalid_parameter_noinfo_noreturn();
        }
        free(pvVar5);
      }
      local_148 = _DAT_140044de0;
      dStack_140 = _UNK_140044de8;
      local_138 = _DAT_140044db0;
      uStack_130 = _UNK_140044db8;
      local_204 = (uint)(*(int *)(param_1 + 0x10cc) * 3) >> 2;
      local_208 = *(uint *)(param_1 + 0x10c8) >> 1;
      local_210 = uVar13;
      local_20c = uVar13;
      cv::ellipse((Mat *)&local_1a8,&local_208,&local_210,0);
      local_148 = (void *)_DAT_140044dd0;
      dStack_140 = (double)_UNK_140044dd8;
      local_138 = _DAT_140044da0;
      uStack_130 = _UNK_140044da8;
      local_1f4 = (uint)(*(int *)(param_1 + 0x10cc) * 3) >> 2;
      local_1f8 = *(uint *)(param_1 + 0x10c8) >> 1;
      in_stack_fffffffffffffd78 = (double)(*(int *)(param_1 + 0x1870) * 0xc);
      local_200 = uVar13;
      local_1fc = uVar13;
      cv::ellipse((Mat *)&local_1a8,&local_1f8,&local_200,0);
      memcpy(*(void **)(param_1 + 0x1878 + (longlong)*(int *)(param_1 + 0x1870) * 8),
             *(void **)(param_1 + 0x1130),_Size);
    }
    EnterCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
    *(undefined1 *)(param_1 + 0x1830) = 1;
    *(undefined8 *)(param_1 + 0x1838) =
         *(undefined8 *)(param_1 + 0x1878 + (longlong)*(int *)(param_1 + 0x1870) * 8);
    SetEvent(*(HANDLE *)(param_1 + 0x450));
    LeaveCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
    *(int *)(param_1 + 0x1138) = *(int *)(param_1 + 0x1138) + 1;
    if ((*(CWnd **)(param_1 + 0x1840) != (CWnd *)0x0) && (*(int *)(param_1 + 0x478) != 0)) {
      pcVar20 = (char *)0x0;
      uVar9 = FUN_1400190f0(*(CWnd **)(param_1 + 0x1840),
                            *(uint **)(param_1 + 0x1878 +
                                      (ulonglong)
                                      (((*(int *)(param_1 + 0x1870) - *(int *)(param_1 + 0x1968)) +
                                       0x1eU) % 0x1e) * 8),(undefined1 *)(ulonglong)uVar11,
                            (uint *)0x0);
      if ((int)uVar9 != 0) {
        MessageBoxA((HWND)0x0,"Couldn\'t update display surface window.","CBFVideoServer Class",0x40
                   );
        goto LAB_140013969;
      }
    }
    if ((*(int *)(param_1 + 0x1980) != 0) && (*(int *)(param_1 + 0x118c) == 0)) {
      *(undefined8 *)(param_1 + 0x1988) = *(undefined8 *)(param_1 + 0x1838);
      *(uint *)(param_1 + 0x1990) = local_24c;
      SetEvent(*(HANDLE *)(param_1 + 0x458));
    }
    iVar10 = *(int *)(param_1 + 0x478);
  } while( true );
}

