
void FUN_14000a800(longlong param_1,int param_2)

{
  char *pcVar1;
  longlong lVar2;
  undefined8 *puVar3;
  
  EnterCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  lVar2 = (longlong)param_2 * 0x220;
  *(undefined2 *)(lVar2 + 0x1d80 + param_1) = 0;
  if (*(longlong *)(lVar2 + 0x1d70 + param_1) != 0) {
    pcap_close();
    *(undefined8 *)(lVar2 + 0x1d70 + param_1) = 0;
  }
  *(undefined4 *)((longlong)param_2 * 0x330 + 0xf48 + param_1) = 0xffffffff;
  LeaveCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  lVar2 = 0;
  pcVar1 = (char *)(param_1 + 0x1d80);
  do {
    if (*pcVar1 != '\0') {
      return;
    }
    lVar2 = lVar2 + 1;
    pcVar1 = pcVar1 + 0x220;
  } while (lVar2 < 2);
  if (*(int *)(param_1 + 0x18ec) != 0) {
    *(undefined4 *)(param_1 + 0x18ec) = 0;
    SetEvent(*(HANDLE *)(param_1 + 0x30));
    if (*(HANDLE *)(param_1 + 0x1fb0) != (HANDLE)0x0) {
      WaitForSingleObject(*(HANDLE *)(param_1 + 0x1fb0),1000);
    }
    puVar3 = (undefined8 *)(param_1 + 0x8e0);
    lVar2 = 2;
    do {
      memset((void *)*puVar3,0,(longlong)(*(int *)(param_1 + 0x54) << 6) * 2);
      puVar3 = puVar3 + 1;
      lVar2 = lVar2 + -1;
    } while (lVar2 != 0);
    *(undefined4 *)(param_1 + 0x8f0) = 0;
  }
  *(undefined1 *)(param_1 + 0x2010) = 0;
  return;
}

