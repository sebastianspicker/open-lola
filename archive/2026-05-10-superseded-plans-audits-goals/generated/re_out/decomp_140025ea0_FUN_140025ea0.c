
CDialog * FUN_140025ea0(CDialog *param_1,CWnd *param_2)

{
  CDialog::CDialog(param_1,0x9a,param_2);
  *(undefined ***)param_1 = LolaChatDlg::vftable;
  _eh_vector_constructor_iterator_
            (param_1 + 0x140,8,5,
             CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref,
             ~CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>_exref);
  CWnd::CWnd((CWnd *)(param_1 + 0x170));
  *(undefined ***)(param_1 + 0x170) = CEdit::vftable;
  CWnd::CWnd((CWnd *)(param_1 + 600));
  *(undefined ***)(param_1 + 600) = CEdit::vftable;
  CWnd::CWnd((CWnd *)(param_1 + 0x340));
  *(undefined ***)(param_1 + 0x340) = CStatic::vftable;
  *(CWnd **)(param_1 + 0x138) = param_2;
  *(undefined8 *)(param_1 + 0x130) = 0x3ff0000000000000;
  *(undefined4 *)(param_1 + 0x168) = 0xffffffff;
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x140),"lola.GetRemoteSettings();");
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x148),"lola.GetRemoteInfo();");
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x150),"lola.ResetRemoteInfo();");
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x158),"lola.ForceDisconnect();");
  ATL::CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_>::operator=
            ((CStringT<char,class_StrTraitMFC_DLL<char,class_ATL::ChTraitsCRT<char>_>_> *)
             (param_1 + 0x160),"lola.SetRemoteAudioBuffer(0);");
  return param_1;
}

