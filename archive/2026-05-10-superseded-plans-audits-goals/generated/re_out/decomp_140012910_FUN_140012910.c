
void FUN_140012910(longlong param_1,int param_2)

{
  char *pcVar1;
  longlong lVar2;
  
  EnterCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  lVar2 = (longlong)param_2 * 0x220;
  *(undefined2 *)(lVar2 + 0x1600 + param_1) = 0;
  if (*(longlong *)(lVar2 + 0x15f0 + param_1) != 0) {
    pcap_close();
    *(undefined8 *)(lVar2 + 0x15f0 + param_1) = 0;
  }
  LeaveCriticalSection((LPCRITICAL_SECTION)(param_1 + 8));
  lVar2 = 0;
  pcVar1 = (char *)(param_1 + 0x1600);
  do {
    if (*pcVar1 != '\0') {
      return;
    }
    lVar2 = lVar2 + 1;
    pcVar1 = pcVar1 + 0x220;
  } while (lVar2 < 2);
  *(undefined4 *)(param_1 + 0x118c) = 0;
  SetEvent(*(HANDLE *)(param_1 + 0x450));
  if (*(HANDLE *)(param_1 + 0x468) != (HANDLE)0x0) {
    WaitForSingleObject(*(HANDLE *)(param_1 + 0x468),1000);
  }
  *(undefined1 *)(param_1 + 0x19d0) = 0;
  return;
}

