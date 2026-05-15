
void FUN_14002b9b0(CWnd *param_1,int param_2)

{
  int iVar1;
  int iVar2;
  LRESULT LVar3;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar4;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar5;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *pCVar6;
  longlong lVar7;
  CSimpleStringT<char,1> *pCVar8;
  IAtlStringMgr *pIVar9;
  undefined8 *puVar10;
  char *pcVar11;
  longlong lVar12;
  longlong lVar13;
  CWnd *pCVar14;
  longlong lVar15;
  char *local_res8;
  undefined4 local_res10;
  char *local_res18;
  char *local_res20;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_78 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_70 [8];
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> local_68 [8];
  undefined8 local_60;
  char **local_58;
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *local_50;
  
  local_60 = 0xfffffffffffffffe;
  lVar15 = (longlong)param_2;
  local_res10 = 0;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             &local_res8,"");
  lVar13 = lVar15 * 0xa78;
  CWnd::GetWindowTextA
            (param_1 + lVar13 + 0x668,
             (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             &local_res8);
  LVar3 = SendMessageA(*(HWND *)(param_1 + lVar13 + 0x5c0),0x147,0,0);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_78,"");
  CWnd::GetWindowTextA(param_1 + lVar13 + 0x838,local_78);
  if (*(char *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x24c) == '\0') {
    iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Compare
                      (local_78,"Disconnect");
    if (iVar1 != 0) {
      lVar13 = (longlong)((int)LVar3 + -1) * 0x20;
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_res18,
                 (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 (param_1 + lVar13 + 0x2ba8));
      iVar1 = 0;
      pCVar14 = param_1 + 0x1ae8;
      do {
        if (*(char *)(*(longlong *)pCVar14 + 0x24c) != '\0') {
          iVar2 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                  Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           *)(*(longlong *)pCVar14 + 0x48),local_res8);
          if (iVar2 == 0) {
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
            CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res20,"");
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res20,"Connection already established on Session %d.");
            AfxMessageBox(local_res20,0x10,0);
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
            ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res20);
            goto LAB_14002c0b7;
          }
        }
        iVar1 = iVar1 + 1;
        pCVar14 = pCVar14 + 8;
      } while (iVar1 < 2);
      iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
              Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      &local_res8,local_res18);
      if (iVar1 == 0) {
LAB_14002c0a3:
        pcVar11 = "Connection to localhost not allowed. Type a valid remote host address.";
LAB_14002c0aa:
        AfxMessageBox(pcVar11,0x10,0);
      }
      else {
        iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_res8,"127.0.0.1");
        if (iVar1 == 0) goto LAB_14002c0a3;
        iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_res8,"localhost");
        if (iVar1 == 0) goto LAB_14002c0a3;
        iVar1 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                Compare((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *
                        )&local_res18,"0.0.0.0");
        if (iVar1 == 0) {
          pcVar11 = "Local IP address \'0.0.0.0\' is not valid.";
          goto LAB_14002c0aa;
        }
        *(undefined1 *)(*(longlong *)(param_1 + 0x1908) + 0x60) = 0;
        *(undefined1 *)(*(longlong *)(param_1 + 0x1908) + 0x61) = 0;
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   (*(longlong *)(param_1 + 0x1908) + 0xb0),"");
        CWnd::SetWindowTextA(param_1 + 0x138,"Connecting ...");
        local_58 = &local_res20;
        local_50 = local_70;
        pCVar4 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                             *)&local_res20,"");
        pCVar5 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           (local_70,(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                      *)&local_res8);
        pCVar6 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                 CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                           (local_68,(CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                      *)&local_res18);
        lVar7 = FUN_14001fb60(*(longlong *)(param_1 + 0x1908),0x800c,pCVar6,pCVar5,param_2,pCVar4);
        if (lVar7 == 0) {
LAB_14002bf09:
          lVar15 = lVar15 * 0xa78;
          CWnd::SetWindowTextA(param_1 + lVar15 + 0x838,"Disconnect");
          FUN_140033260((longlong *)param_1);
          FUN_140032fd0((longlong)param_1,param_2,2);
          CWnd::EnableWindow(param_1 + lVar15 + 0x580,0);
          CWnd::EnableWindow(param_1 + lVar15 + 0x668,0);
          CWnd::EnableWindow(param_1 + lVar15 + 0xda8,0);
          pIVar9 = ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                   GetManager((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               *)&local_res8);
          puVar10 = (undefined8 *)
                    ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                    CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                              ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                *)&local_res20,pIVar9);
          local_res10 = 1;
          lVar13 = -1;
          do {
            lVar12 = lVar13 + 1;
            lVar7 = lVar13 + 1;
            lVar13 = lVar12;
          } while ("Connected to "[lVar7] != '\0');
          ATL::CSimpleStringT<char,1>::Concatenate
                    ((CSimpleStringT<char,1> *)&local_res20,"Connected to ",(int)lVar12,local_res8,
                     *(int *)(local_res8 + -0x10));
          CWnd::SetWindowTextA(param_1 + lVar15 + 0x920,(char *)*puVar10);
        }
        else {
          iVar1 = 0;
          do {
            if ((*(char *)(*(longlong *)(param_1 + 0x1908) + 0x61) != '\0') ||
               (*(char *)(*(longlong *)(param_1 + 0x1908) + 0x60) != '\0')) break;
            Sleep(100);
            iVar1 = iVar1 + 100;
          } while (iVar1 < 2000);
          if (*(char *)(*(longlong *)(param_1 + 0x1908) + 0x61) != '\0') {
            *(undefined4 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2b0) =
                 *(undefined4 *)(*(longlong *)(param_1 + 0x1908) + 100);
            *(undefined8 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2b8) =
                 *(undefined8 *)(*(longlong *)(param_1 + 0x1908) + 0x68);
            *(undefined4 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2c0) =
                 *(undefined4 *)(*(longlong *)(param_1 + 0x1908) + 0x70);
            *(undefined4 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2c4) =
                 *(undefined4 *)(*(longlong *)(param_1 + 0x1908) + 0x74);
            *(undefined4 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2c8) =
                 *(undefined4 *)(*(longlong *)(param_1 + 0x1908) + 0x78);
            *(undefined8 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2d0) =
                 *(undefined8 *)(*(longlong *)(param_1 + 0x1908) + 0x80);
            *(undefined4 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2d8) =
                 *(undefined4 *)(*(longlong *)(param_1 + 0x1908) + 0x88);
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
            operator=((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      (*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x48),
                      (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                      (*(longlong *)(param_1 + 0x1908) + 0x40));
            *(undefined4 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2dc) =
                 *(undefined4 *)(*(longlong *)(param_1 + 0x1908) + 0x8c);
            *(undefined1 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2e0) =
                 *(undefined1 *)(*(longlong *)(param_1 + 0x1908) + 0x90);
            *(undefined4 *)(param_1 + 0x1aa4) = 0;
            *(undefined4 *)(param_1 + 0x1abc) = 0;
            if (param_1[0x1b1a] != (CWnd)0x0) {
              FUN_14002cd70(param_1);
            }
            lVar7 = *(longlong *)(param_1 + lVar15 * 8 + 0x1ae8);
            FUN_14000db40(*(longlong *)(param_1 + lVar15 * 8 + 0x1b08),
                          *(undefined8 *)(lVar7 + 0x2b8),*(int *)(lVar7 + 0x2c4),
                          *(int *)(lVar7 + 0x2c8),*(uint *)(lVar7 + 0x2c0));
            pCVar4 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)&local_res20,
                                (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x48));
            FUN_14000d440(*(longlong *)(param_1 + lVar15 * 8 + 0x1b08),
                          *(undefined4 *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2dc),
                          *(undefined4 *)(param_1 + 0x19b0),*(undefined4 *)(param_1 + 0x19bc),
                          *(undefined4 *)(param_1 + 0x19c4),
                          (uint)*(byte *)(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2e0),
                          *(int *)(param_1 + 0x19c8),*(int *)(param_1 + 0x19cc),pCVar4);
            FUN_14000d7e0(*(void **)(param_1 + lVar15 * 8 + 0x1b08));
            local_50 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res20;
            pCVar8 = (CSimpleStringT<char,1> *)
                     ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)&local_res20,
                                (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)&local_res8);
            pCVar14 = param_1 + lVar13 + 0x2b90;
            iVar1 = FUN_140029e60((longlong)param_1,param_2);
            FUN_14000a000(*(void **)(param_1 + 0x1b00),param_2,(longlong)pCVar14,pCVar8,
                          *(undefined2 *)(param_1 + 0x1a10),iVar1);
            if (0 < *(int *)(param_1 + 0x1b38)) {
              pCVar8 = (CSimpleStringT<char,1> *)
                       ATL::
                       CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
                       CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                   *)&local_res20,
                                  (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                   *)&local_res8);
              FUN_140012490(*(void **)(param_1 + 0x1af8),param_2,(longlong)pCVar14,pCVar8,
                            *(undefined2 *)(param_1 + 0x1a0c),*(undefined4 *)(param_1 + 0x1a2c));
            }
            pCVar4 = (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                     ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                     ::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                               ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)&local_res20,
                                (CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                                 *)&local_res8);
            FUN_140016f20(*(void **)(param_1 + lVar15 * 8 + 0x1ae8),(longlong)pCVar14,pCVar4,
                          *(undefined4 *)
                           ((longlong)*(void **)(param_1 + lVar15 * 8 + 0x1ae8) + 0x2dc));
            param_1[lVar15 + 0x1b18] = (CWnd)0x1;
            FUN_140032dd0(param_1);
            goto LAB_14002bf09;
          }
          FUN_1400174e0(*(longlong *)(param_1 + lVar15 * 8 + 0x1ae8));
          if (*(int *)(*(longlong *)(*(longlong *)(param_1 + 0x1908) + 0xb0) + -0x10) == 0) {
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
            CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res20,"");
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res20,
                       "Session %d connection info:\nNo reply from remote host (%s) within 3 sec! Try again."
                       ,(ulonglong)(param_2 + 1),local_res8);
            AfxMessageBox(local_res20,0x30,0);
          }
          else {
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
            CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res20,"");
            ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::Format
                      ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                       &local_res20,
                       "Session %d connection info.\n\nRemote host (%s) replied with the following message:    \n\n%s"
                       ,(ulonglong)(param_2 + 1),local_res8,
                       *(undefined8 *)(*(longlong *)(param_1 + 0x1908) + 0xb0));
            AfxMessageBox(local_res20,0x30,0);
          }
        }
        ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
        ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                  ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                   &local_res20);
        CWnd::SetWindowTextA(param_1 + 0x138,"Ready");
        CWnd::SetFocus(param_1);
      }
LAB_14002c0b7:
      ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
      ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
                ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
                 &local_res18);
      goto LAB_14002c0cf;
    }
  }
  FUN_14002c100(param_1,param_2);
LAB_14002c0cf:
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>(local_78);
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::
  ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             &local_res8);
  return;
}

