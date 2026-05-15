
void FUN_140007200(longlong param_1,longlong param_2)

{
  uint uVar1;
  
  if ((*(int *)(param_1 + 8) == *(int *)(param_2 + 0xc)) &&
     (uVar1 = *(uint *)(param_2 + 0x14), uVar1 <= *(uint *)(param_1 + 0x34))) {
    if (*(char *)(*(longlong *)(param_1 + 0x28) + (ulonglong)uVar1) == '\0') {
      *(undefined1 *)(*(longlong *)(param_1 + 0x28) + (ulonglong)uVar1) = 1;
      memcpy((void *)((ulonglong)*(uint *)(param_2 + 0x18) + *(longlong *)(param_1 + 0x18)),
             (void *)(param_2 + 0x21),(ulonglong)*(uint *)(param_2 + 0x1c));
      *(int *)(param_1 + 0x40) = *(int *)(param_1 + 0x40) + 1;
    }
  }
  return;
}

