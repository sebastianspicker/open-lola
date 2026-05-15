
void FUN_14000ad00(longlong param_1,short *param_2,short *param_3,uint param_4)

{
  short sVar1;
  uint uVar2;
  int iVar3;
  int iVar4;
  ulonglong uVar5;
  short *psVar6;
  int iVar7;
  ulonglong uVar8;
  ulonglong uVar9;
  ulonglong uVar10;
  int *piVar11;
  int *piVar12;
  longlong local_res8;
  
  uVar8 = (ulonglong)param_4;
  psVar6 = param_3;
  if (*(int *)(param_1 + 0xa4) != 0) {
    uVar2 = *(int *)(param_1 + 0x8f0) + 1U & 0x80000001;
    if ((int)uVar2 < 0) {
      uVar2 = (uVar2 - 1 | 0xfffffffe) + 1;
    }
    *(uint *)(param_1 + 0x8f0) = uVar2;
    if (param_2 == (short *)0x0) {
      if (param_4 != 0) {
        iVar3 = *(int *)(param_1 + 0x54);
        iVar4 = *(int *)(param_1 + 0x8d0);
        do {
          iVar7 = 0;
          if (0 < iVar3) {
            do {
              iVar3 = *(int *)(param_1 + 0x8d0) + iVar7;
              iVar7 = iVar7 + 1;
              *(undefined2 *)
               (*(longlong *)(param_1 + 0x8e0 + (longlong)*(int *)(param_1 + 0x8f0) * 8) +
               (longlong)iVar3 * 2) = 0;
              *param_3 = 0;
              param_3 = param_3 + 1;
              iVar3 = *(int *)(param_1 + 0x54);
            } while (iVar7 < iVar3);
            iVar4 = *(int *)(param_1 + 0x8d0);
          }
          iVar4 = iVar4 + iVar3;
          *(int *)(param_1 + 0x8d0) = iVar4;
          uVar8 = uVar8 - 1;
        } while (uVar8 != 0);
        uVar2 = *(uint *)(param_1 + 0x8f0);
        psVar6 = param_3;
      }
      *(undefined8 *)(param_1 + 0x1288) =
           *(undefined8 *)(param_1 + 0x8e0 + (longlong)(int)uVar2 * 8);
    }
    else {
      uVar5 = 0;
      if (param_4 != 0) {
        iVar3 = *(int *)(param_1 + 0x54);
        iVar4 = *(int *)(param_1 + 0x8d0);
        uVar10 = uVar8;
        do {
          uVar9 = uVar5;
          if (0 < iVar3) {
            do {
              uVar2 = (int)uVar9 + 1;
              *(short *)(*(longlong *)(param_1 + 0x8e0 + (longlong)*(int *)(param_1 + 0x8f0) * 8) +
                        (longlong)(*(int *)(param_1 + 0x8d0) + (int)uVar9) * 2) =
                   (short)(int)*(double *)(param_1 + 0x8c8) * *param_2;
              sVar1 = *param_2;
              param_2 = param_2 + 1;
              *psVar6 = (short)(int)*(double *)(param_1 + 0x98) * sVar1;
              psVar6 = psVar6 + 1;
              iVar3 = *(int *)(param_1 + 0x54);
              uVar9 = (ulonglong)uVar2;
            } while ((int)uVar2 < iVar3);
            iVar4 = *(int *)(param_1 + 0x8d0);
          }
          iVar4 = iVar4 + iVar3;
          *(int *)(param_1 + 0x8d0) = iVar4;
          uVar10 = uVar10 - 1;
        } while (uVar10 != 0);
        uVar2 = *(uint *)(param_1 + 0x8f0);
      }
      *(undefined4 *)(param_1 + 0x8d0) = 0;
      *(undefined8 *)(param_1 + 0x1288) =
           *(undefined8 *)(param_1 + 0x8e0 + (longlong)(int)uVar2 * 8);
      SetEvent(*(HANDLE *)(param_1 + 0x30));
      piVar11 = (int *)(param_1 + 0xf44);
      local_res8 = 2;
      piVar12 = piVar11;
      do {
        psVar6 = param_3;
        if (-1 < piVar12[1]) {
          *(undefined4 *)(param_1 + 0x8d0) = 0;
          uVar10 = uVar8;
          if (param_4 == 0) {
            iVar3 = *(int *)(param_1 + 0x74);
          }
          else {
            do {
              memcpy(psVar6 + piVar12[1],
                     (void *)(*(longlong *)(param_1 + 0xc20 + ((longlong)*piVar12 + uVar5) * 8) +
                             (longlong)*(int *)(param_1 + 0x8d0) * 2),
                     ((longlong)*(int *)(param_1 + 0x74) - (longlong)piVar12[1]) * 2);
              iVar3 = *(int *)(param_1 + 0x74);
              *(int *)(param_1 + 0x8d0) = *(int *)(param_1 + 0x8d0) + iVar3;
              psVar6 = psVar6 + iVar3;
              uVar10 = uVar10 - 1;
            } while (uVar10 != 0);
          }
          memset(*(void **)(param_1 + 0xc20 + ((longlong)*piVar12 + uVar5) * 8),0,
                 (ulonglong)(iVar3 * param_4) * 2);
          *piVar11 = (*piVar12 + 1) % 100;
        }
        piVar11 = piVar11 + 0xcc;
        uVar5 = uVar5 + 0x66;
        piVar12 = piVar12 + 0xcc;
        local_res8 = local_res8 + -1;
      } while (local_res8 != 0);
      *(undefined4 *)(param_1 + 0x8d0) = 0;
    }
  }
  if (*(int *)(param_1 + 0xa8) != 0) {
    iVar3 = (*(int *)(param_1 + 0x18d8) + 1) % 100;
    if (iVar3 != *(int *)(param_1 + 0x18dc)) {
      memcpy(*(void **)(param_1 + 0x15b8 + (longlong)*(int *)(param_1 + 0x18d8) * 8),psVar6,
             (ulonglong)*(ushort *)(param_1 + 0x3a) << 7);
      *(int *)(param_1 + 0x18d8) = iVar3;
    }
    iVar3 = (*(int *)(param_1 + 0x15b0) + 1) % 100;
    if (iVar3 != *(int *)(param_1 + 0x15b4)) {
      memcpy(*(void **)(param_1 + 0x1290 + (longlong)*(int *)(param_1 + 0x15b0) * 8),
             *(void **)(param_1 + 0x8e0 + (longlong)*(int *)(param_1 + 0x8f0) * 8),
             (ulonglong)*(ushort *)(param_1 + 0x3a) << 7);
      *(int *)(param_1 + 0x15b0) = iVar3;
    }
  }
  return;
}

