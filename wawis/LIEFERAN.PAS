unit Lieferanten;
interface
  uses
    Objects, OWindows, ODialogs,
    WinTypes, WinProcs, Strings,
    Globals, ListWin, DBServer, DBEditor;

  type
    TAnschrift= array[0..2, 0..40] of Char;

    PLieferRec= ^TLieferRec;
    TLieferRec= record
      Nr: LongInt;
      Name: array[0..40] of Char;
      Short: array[0..5] of Char;
      Anschrift: TAnschrift;
      Telefon, Telefax: array[0..30] of Char;
      Mode: Byte;
    end;

    PLieferEditor= ^TLieferEditor;
    TLieferEditor= object(TDBEditor)
      procedure SetupWindow; virtual;
      function GetString(Rec: Pointer; Field: Byte): PChar; virtual;
      function EditItem(Data: Pointer): Boolean; virtual;
      procedure IDMEKListe(Var Msg: TMessage); virtual cm_First+idm_ShowEKListe;
    end;

    PLieferWin= ^TLieferWin;
    TLieferWin= object(TListWindow)
      constructor Init;
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(var AWndClass: TWndClass); virtual;
    end;

    PLieferDlg= ^TLieferDlg;
    TLieferDlg= object(TDialog)
      constructor Init(ALiefer: PLieferRec);
      procedure EKPreise(var Msg: TMessage); virtual id_First+8;
    end;

  const
    LieferDB: PDatabase= nil;
    EKDB: PDatabase= nil;

  function SelectLieferant(ShowLocked: Boolean): LongInt;
  function LockLieferant(On: Boolean; Nr: LongInt): Boolean;   

implementation

  function LockLieferant(On: Boolean; Nr: LongInt): Boolean;
  var LieferRec: PLieferRec;
  begin
    LockLieferant:=False;
    LieferRec:=LieferDB^.CheckRecNr(Nr);
    if LieferRec=nil then Exit;
    if On and (LieferRec^.Mode<>0) then Exit;
    if On then
      LieferRec^.Mode:=1
    else
      LieferRec^.Mode:=0;
    LieferDB^.UpdateRec(0, LieferDB^.IndexOf(0, Nr), LieferRec^);
    LockLieferant:=True;
  end;

{
== TLieferEditor (Object) ==
}
  procedure TLieferEditor.SetupWindow;
  begin
    LocalMenu:=LieferMenu;
    DeleteQuery:=str_LieferantDeleteQuery;
    Range.X:=3;
    AddListCol(1, 200, GetResString(str_Firma), False);
    AddListCol(5, 200, GetResString(str_Telefon), False);
    AddListCol(6, 200, GetResString(str_Telefax), False);
    TDBEditor.SetupWindow;
  end;

  function TLieferEditor.GetString(Rec: Pointer; Field: Byte): PChar;
  var
    L: PLieferRec absolute Rec;
  begin
    if L<>nil then
    case Field of
      1: GetString:=L^.Name;
      2: GetString:=L^.Anschrift[0];
      3: GetString:=L^.Anschrift[1];
      4: GetString:=L^.Anschrift[2];
      5: GetString:=L^.Telefon;
      6: GetString:=L^.Telefax;
      else GetString:=nil;
    end else
      GetString:=nil;
  end;

  function TLieferEditor.EditItem(Data: Pointer): Boolean;
  var Dlg: PLieferDlg;
  begin
    New(Dlg, Init(PLieferRec(Data)));
    EditItem:=Application^.ExecDialog(Dlg)=ID_OK;
    UpdateWindow(hMainWindow);
  end;

  procedure TLieferEditor.IDMEKListe(var Msg: TMessage);
  begin
    if FocusedNr>=0 then PostMessage(hMainWindow, wm_EKListe, 0, FocusedNr);
  end;

{
== TLieferWin (Object) ==
}
  constructor TLieferWin.Init;
  begin
    TListWindow.Init(Application^.MainWindow, GetResString(str_LieferDB));
    Viewer:=New(PLieferEditor, Init(@Self, LieferDB));
  end;

  function TLieferWin.GetClassName: PChar;
  begin
    GetClassName:='WAWIS:Lieferanten';
  end;

  procedure TLieferWin.GetWindowClass(Var AWndClass: TWndClass);
  begin
    TListWindow.GetWindowClass(AWndClass);
    AWndClass.hIcon:=LoadIcon(hInstance, MakeIntResource(LieferIcon)); 
  end;

{
== TLieferDlg (Object) ==
}
  constructor TLieferDlg.Init(ALiefer: PLieferRec);
  var
    E: PEdit;
    I: Byte;
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(LieferantDlg));
    New(E, InitResource(@Self, ID_FIRMA, 41));
    New(E, InitResource(@Self, ID_SHORT, 6));
    for I:=0 to 2 do
      New(E, InitResource(@Self, ID_ANSCHRIFT+I, 41));
    for I:=0 to 1 do
      New(E, InitResource(@Self, ID_TELEFON+I, 31));
    TransferBuffer:=@ALiefer^.Name;
  End;

  procedure TLieferDlg.EKPreise(var Msg: TMessage);
  begin
    EndDlg(8);
  end;

{
== TSelectLieferDlg ==
}
  type
    PSelectLieferDlg= ^TSelectLieferDlg;
    TSelectLieferDlg= object(TDialog)
      L: PListBox;
      Data: ^LongInt;
      ShowLocked: Boolean;
      NrColl: TCollection;
      constructor Init;
      procedure SetupWindow; virtual;
      procedure OK(var Msg: TMessage); virtual id_First+id_Ok;
      procedure WMDestroy(var Msg: TMessage); virtual wm_First+wm_Destroy;
      procedure Listbox(var Msg: TMessage); virtual id_First+id_ListBox;
    end;

  constructor TSelectLieferDlg.Init;
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(SelectDlg));
    New(L, InitResource(@Self, id_ListBox));
  end;

  procedure TSelectLieferDlg.SetupWindow;
  var
    E: PBufferElement;
    I: Integer;
    P: PLieferRec;
    acS: array[0..100] of Char;
  begin
    TDialog.SetupWindow;
    SetWindowText(hWindow, 'Lieferant auswählen');
    SetWindowText(GetItemHandle(id_ListBoxText), '&Lieferanten');
    NrColl.Init(10, 10);
    LieferDB^.Register(hWindow, 1);
    for I:=0 to LieferDB^.NumRecs(hWindow)-1 do
    begin
      P:=PLieferRec(LieferDB^.CheckRec(hWindow, I));
      if ((ShowLocked) or (P^.Mode=0)) or (Debug) then
      begin
        if Debug and (P^.Mode<>0) then
        begin
          StrCat(StrCopy(acS, P^.Name), ' (Locked)');
          L^.AddString(acS);
        end else
          L^.AddString(P^.Name);
        NrColl.Insert(Pointer(P^.Nr));
      end;
    end;
    LieferDB^.Unregister(hWindow);
    EnableWindow(hMainWindow, False);
  end;

  procedure TSelectLieferDlg.Ok(var Msg: TMessage);
  var
    I: Integer;
  begin
    I:=L^.GetSelIndex;
    if I>=0 then
    begin
      Data^:=LongInt(NrColl.At(I));
      TDialog.Ok(Msg);
    end else
      MessageBeep(0);
  end;

  procedure TSelectLieferDlg.WMDestroy;
  begin
    NrColl.DeleteAll;
    NrColl.Done;
    TDialog.WMDestroy(Msg);
  end;

  procedure TSelectLieferDlg.ListBox;
  begin
    if Msg.lParamHi=lbn_DblClk then Ok(Msg);
  end;

  function SelectLieferant(ShowLocked: Boolean): LongInt;
  var
    P: PSelectLieferDlg;
    L: LongInt;
  begin
    New(P, Init);
    P^.Data:=@L;
    P^.ShowLocked:=ShowLocked;
    if Application^.ExecDialog(P)<>ID_CANCEL then
      SelectLieferant:=L
    else
      SelectLieferant:=-1;
  end;

  (*
  Procedure RereadDBBuffers;
  Var Dlg: PPIDlg;
  Begin
    New(Dlg, Init(Application^.MainWindow, nil, -1, -1, MakeIntResource(WaitDlg)));
    Application^.MakeWindow(Dlg);
    SetCursor(LoadCursor(0, IDC_WAIT));
    ArtikelDB^.RefreshBuffer(Dlg);
    LieferDB^.RefreshBuffer(Dlg);
    BetriebeDB^.RefreshBuffer(Dlg);
    EKDB^.RefreshBuffer(Dlg);
    SetCursor(LoadCursor(0, IDC_ARROW));
    Dispose(Dlg, Done);
  End;
  *)

end.