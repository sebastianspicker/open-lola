
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_14000efc0(longlong param_1)

{
  void *pvVar1;
  longlong lVar2;
  uint uVar3;
  int iVar4;
  undefined8 uVar5;
  void *_Memory;
  uint uVar6;
  int *piVar7;
  longlong *plVar8;
  Mat *pMVar9;
  size_t sVar10;
  uint uVar12;
  undefined1 auStackY_438 [32];
  uint local_3e8;
  int local_3e4;
  undefined4 local_3e0;
  uint local_3dc;
  undefined4 local_3d8;
  int local_3d4;
  undefined8 local_3d0;
  undefined4 local_3c8;
  undefined4 local_3c4;
  int local_3c0;
  undefined4 local_3bc;
  int local_3b8;
  int local_3b4;
  uint local_3b0;
  undefined4 uStack_3ac;
  undefined4 uStack_3a8;
  undefined4 uStack_3a4;
  undefined4 local_3a0;
  undefined4 uStack_39c;
  undefined4 uStack_398;
  undefined4 uStack_394;
  undefined8 local_390;
  undefined8 local_388;
  undefined8 local_380;
  uint *local_378;
  int *piStack_370;
  undefined8 local_368;
  undefined8 local_360;
  undefined8 local_358;
  undefined8 local_350;
  undefined8 *local_348;
  undefined8 *local_340;
  undefined8 local_338;
  undefined8 local_330;
  uint local_328;
  int local_324;
  int local_320;
  int local_31c;
  longlong local_318;
  int *local_310;
  longlong local_308;
  longlong local_300;
  longlong local_2f8;
  undefined8 local_2f0;
  int *local_2e8;
  longlong *local_2e0;
  longlong local_2d8;
  longlong local_2d0;
  uint local_2c8;
  undefined4 uStack_2c4;
  undefined4 uStack_2c0;
  undefined4 uStack_2bc;
  undefined8 local_2b8;
  undefined8 uStack_2b0;
  Mat local_2a8 [16];
  undefined8 local_298;
  int *local_290;
  undefined8 local_288;
  undefined8 local_280;
  undefined8 local_278;
  undefined4 *local_268;
  undefined1 *local_260;
  undefined1 local_258 [16];
  Mat local_248 [4];
  int local_244 [95];
  char local_c8 [112];
  ulonglong local_58;
  size_t sVar11;
  
  local_390 = 0xfffffffffffffffe;
  local_58 = DAT_1400630d8 ^ (ulonglong)auStackY_438;
  iVar4 = 0;
  local_3e8 = 0;
  _eh_vector_constructor_iterator_(local_248,0x60,4,FUN_14000e700,FUN_14000ecf0);
  uVar12 = (uint)(*(int *)(param_1 + 0x10cc) * 0x140) / *(uint *)(param_1 + 0x10c8);
  local_3e4 = *(int *)(param_1 + 0x404) * 0x140;
  local_348 = &local_380;
  local_330 = 0;
  local_338 = 0;
  local_388 = 0x42ff0000;
  local_380 = 0;
  local_358 = 0;
  local_360 = 0;
  local_368 = 0;
  local_378 = (uint *)0x0;
  piStack_370 = (int *)0x0;
  local_350 = 0;
  if (*(int *)(param_1 + 0x10dc) == 0x18) {
    iVar4 = 0x10;
  }
  local_3e8 = uVar12;
  local_340 = &local_338;
  cv::Mat::create((Mat *)&local_388,2,(int *)&local_3e8,iVar4);
  *(undefined4 *)(param_1 + 0x480) = 1;
  ResetEvent(*(HANDLE *)(param_1 + 0x470));
  iVar4 = *(int *)(param_1 + 0x480);
  do {
    if (iVar4 == 0) {
LAB_14000f61c:
      SetEvent(*(HANDLE *)(param_1 + 0x470));
      if ((piStack_370 != (int *)0x0) &&
         (iVar4 = cv::_interlockedExchangeAdd(piStack_370,-1), iVar4 == 1)) {
        cv::Mat::deallocate((Mat *)&local_388);
      }
      local_358 = 0;
      local_360 = 0;
      local_368 = 0;
      local_378 = (uint *)0x0;
      *(undefined4 *)local_348 = 0;
      piStack_370 = (int *)0x0;
      if (local_340 != &local_338) {
        cv::fastFree(local_340);
      }
      _eh_vector_destructor_iterator_(local_248,0x60,4,FUN_14000ecf0);
      return;
    }
    uVar6 = 0;
    uVar3 = 0;
    if (*(int *)(param_1 + 0x404) != 0) {
      plVar8 = (longlong *)(param_1 + 0x3d8);
      do {
        if (((*plVar8 != 0) && (*(int *)(param_1 + 0x480) != 0)) &&
           (uVar6 != *(uint *)(param_1 + 0x30))) {
          xiGetImage(*plVar8,1000,param_1 + 0x38 + (longlong)(int)uVar6 * 0xe8);
        }
        uVar6 = uVar6 + 1;
        plVar8 = plVar8 + 1;
        uVar3 = *(uint *)(param_1 + 0x404);
      } while (uVar6 < uVar3);
    }
    uVar6 = 0;
    if (uVar3 != 0) {
      piVar7 = local_244;
      plVar8 = (longlong *)(param_1 + 0x40);
      do {
        local_318 = *plVar8;
        local_31c = *(int *)(param_1 + 0x10c8);
        local_320 = *(int *)(param_1 + 0x10cc);
        local_324 = 2;
        local_310 = (int *)0x0;
        local_2f0 = 0;
        local_2e8 = &local_320;
        local_2e0 = &local_2d8;
        local_2d0 = 1;
        if (*(int *)(param_1 + 0x10dc) == 0x18) {
          local_2d0 = 3;
        }
        iVar4 = 0;
        if (*(int *)(param_1 + 0x10dc) == 0x18) {
          iVar4 = 0x10;
        }
        local_328 = iVar4 + 0x42ff0000U | 0x4000;
        local_2d8 = local_31c * local_2d0;
        local_300 = local_31c * local_2d0 * (longlong)local_320 + local_318;
        pMVar9 = (Mat *)(piVar7 + -1);
        local_308 = local_318;
        local_2f8 = local_300;
        if (pMVar9 != (Mat *)&local_328) {
          if ((*(int **)(piVar7 + 5) != (int *)0x0) &&
             (iVar4 = cv::_interlockedExchangeAdd(*(int **)(piVar7 + 5),-1), iVar4 == 1)) {
            cv::Mat::deallocate(pMVar9);
          }
          piVar7[0xb] = 0;
          piVar7[0xc] = 0;
          piVar7[9] = 0;
          piVar7[10] = 0;
          piVar7[7] = 0;
          piVar7[8] = 0;
          piVar7[3] = 0;
          piVar7[4] = 0;
          **(undefined4 **)(piVar7 + 0xf) = 0;
          piVar7[5] = 0;
          piVar7[6] = 0;
          *(uint *)pMVar9 = local_328;
          if ((*piVar7 < 3) && (local_324 < 3)) {
            *piVar7 = local_324;
            piVar7[1] = local_320;
            piVar7[2] = local_31c;
            **(longlong **)(piVar7 + 0x11) = *local_2e0;
            *(longlong *)(*(longlong *)(piVar7 + 0x11) + 8) = local_2e0[1];
          }
          else {
            cv::Mat::copySize(pMVar9,(Mat *)&local_328);
          }
          *(longlong *)(piVar7 + 3) = local_318;
          *(longlong *)(piVar7 + 7) = local_308;
          *(longlong *)(piVar7 + 9) = local_300;
          *(longlong *)(piVar7 + 0xb) = local_2f8;
          *(int **)(piVar7 + 5) = local_310;
          *(undefined8 *)(piVar7 + 0xd) = local_2f0;
        }
        if ((local_310 != (int *)0x0) &&
           (iVar4 = cv::_interlockedExchangeAdd(local_310,-1), iVar4 == 1)) {
          cv::Mat::deallocate((Mat *)&local_328);
        }
        local_2f8 = 0;
        local_300 = 0;
        local_308 = 0;
        local_318 = 0;
        *local_2e8 = 0;
        local_310 = (int *)0x0;
        if (local_2e0 != &local_2d8) {
          cv::fastFree(local_2e0);
        }
        pMVar9 = local_248 + (longlong)(int)uVar6 * 0x60;
        cv::_OutputArray::_OutputArray((_OutputArray *)&local_3b0,pMVar9);
        cv::_InputArray::_InputArray((_InputArray *)&local_2c8,pMVar9);
        local_3e0 = 0x140;
        local_3dc = uVar12;
        cv::resize(&local_2c8,&local_3b0,&local_3e0,0);
        if (uVar6 == *(uint *)(param_1 + 0x30)) {
          local_2c8 = _DAT_140044df0;
          uStack_2c4 = _UNK_140044df4;
          uStack_2c0 = _UNK_140044df8;
          uStack_2bc = _UNK_140044dfc;
          local_2b8 = CONCAT44(_UNK_140044dc4,_DAT_140044dc0);
          uStack_2b0 = CONCAT44(_UNK_140044dcc,_UNK_140044dc8);
          local_3c4 = **(undefined4 **)(piVar7 + 0xf);
          local_3c8 = (*(undefined4 **)(piVar7 + 0xf))[1];
          local_3d0 = 0;
          cv::rectangle(pMVar9,&local_3d0,&local_2c8,2);
          snprintf(local_c8,100,"CAM %d",(ulonglong)(uVar6 + 1));
          local_2b8 = 0;
          uStack_2b0 = 0xf;
          local_2c8 = local_2c8 & 0xffffff00;
          sVar11 = 0xffffffffffffffff;
          do {
            sVar10 = sVar11 + 1;
            lVar2 = sVar11 + 1;
            sVar11 = sVar10;
          } while (local_c8[lVar2] != '\0');
          FUN_14000ab60((longlong *)&local_2c8,local_c8,sVar10);
          local_3b0 = _DAT_140044df0;
          uStack_3ac = _UNK_140044df4;
          uStack_3a8 = _UNK_140044df8;
          uStack_3a4 = _UNK_140044dfc;
          local_3a0 = _DAT_140044dc0;
          uStack_39c = _UNK_140044dc4;
          uStack_398 = _UNK_140044dc8;
          uStack_394 = _UNK_140044dcc;
          local_3d8 = 10;
          local_3d4 = uVar12 - 10;
          cv::putText(pMVar9,&local_2c8,&local_3d8);
          if (0xf < uStack_2b0) {
            pvVar1 = (void *)CONCAT44(uStack_2c4,local_2c8);
            _Memory = pvVar1;
            if ((0xfff < uStack_2b0 + 1) &&
               (_Memory = *(void **)((longlong)pvVar1 + -8),
               0x1f < (ulonglong)((longlong)pvVar1 + (-8 - (longlong)_Memory)))) {
                    /* WARNING: Subroutine does not return */
              _invalid_parameter_noinfo_noreturn();
            }
            free(_Memory);
          }
        }
        local_3b4 = piVar7[1];
        local_3b8 = piVar7[2];
        local_3c0 = local_3b8 * uVar6;
        local_3bc = 0;
        cv::Mat::Mat(local_2a8,(Mat *)&local_388,(Rect_<int> *)&local_3c0);
        cv::_OutputArray::_OutputArray((_OutputArray *)&local_3b0,local_2a8);
        cv::Mat::copyTo(pMVar9,(_OutputArray *)&local_3b0);
        if ((local_290 != (int *)0x0) &&
           (iVar4 = cv::_interlockedExchangeAdd(local_290,-1), iVar4 == 1)) {
          cv::Mat::deallocate(local_2a8);
        }
        local_278 = 0;
        local_280 = 0;
        local_288 = 0;
        local_298 = 0;
        *local_268 = 0;
        local_290 = (int *)0x0;
        if (local_260 != local_258) {
          cv::fastFree(local_260);
        }
        uVar6 = uVar6 + 1;
        plVar8 = plVar8 + 0x1d;
        piVar7 = piVar7 + 0x18;
      } while (uVar6 < *(uint *)(param_1 + 0x404));
    }
    if (*(CWnd **)(param_1 + 0x1848) != (CWnd *)0x0) {
      if (*(int *)(param_1 + 0x480) == 0) goto LAB_14000f61c;
      uVar5 = FUN_1400190f0(*(CWnd **)(param_1 + 0x1848),local_378,
                            (undefined1 *)(ulonglong)*(uint *)(param_1 + 0x10dc),(uint *)0x0);
      if ((int)uVar5 != 0) {
        MessageBoxA((HWND)0x0,"Couldn\'t update camera preview surface window.",
                    "CBFVideoServer Class",0x40);
        goto LAB_14000f61c;
      }
    }
    iVar4 = *(int *)(param_1 + 0x480);
  } while( true );
}

