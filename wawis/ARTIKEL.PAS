unit Artikel;
interface
  uses
    Objects, OWindows, ODialogs,
    WinTypes, WinProcs,
    Globals, ListWin, DBServer, DBEditor;

  type
    PArtikelRec= ^TArtikelRec;
    TArtikelRec= record
      Nr: LongInt;
      Name: array[0..30] of Char;
      Warengruppe: Byte;
      EVArt: array[0..5] of Char;
      EVInhalt: array[0..10] of Char;
      MwSt: Byte;
      ChangeRev: Byte;
    end;

    PArtikelEditor= ^TArtikelEditor;
    TArtikelEditor= object(TDBEditor)
      procedure SetupWindow; virtual;
      function GetString(Rec: Pointer; Field: Byte): PChar; virtual;
      function EditItem(Data: Pointer): Boolean; virtual;
    end;

    PArtikelWin= ^TArtikelWin;
    TArtikelWin= object(TListWindow)
      constructor Init;
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(var AWndClass: TWndClass); virtual;
    end;

    PArtikelDlg= ^TArtikelDlg;
    TArtikelDlg= object(TDialog)
      Artikel: PArtikelRec;
      constructor Init(AnArtikel: PArtikelRec);
      procedure SetupWindow; virtual;
      procedure Ok(var Msg: TMessage); virtual id_First+id_Ok;
      procedure IDWGNr(var Msg: TMessage); virtual id_First+id_WGNR;
      procedure IDWGName(var Msg: TMessage); virtual id_First+ID_WGNAME;
    end;

  const
    ArtikelDB: PDatabase= nil;

implementation
  uses DlgObj;

{
== TArtikelEditor (Object) ==
}
  procedure TArtikelEditor.SetupWindow;
  begin
    LocalMenu:=ArtikelMenu;
    DeleteQuery:=str_ArtikelDeleteQuery;
    SortDialog:=ArtikelSortDlg;
    Range.X:=5;
    AddListCol(1, 200, GetResString(str_Bezeichnung), False);
    AddListCol(2, 25, GetResString(str_Warengruppe), True);
    AddListCol(3, 40, GetResString(str_EVArt), False);
    AddListCol(4, 60, GetResString(str_EVInhalt), False);
    AddListCol(5, 50, GetResString(str_MwSt), True);
    DefaultSort:=UserSettings.DefaultArtikelSort;
    ClipboardFormat:=cf_Artikel;
    TDBEditor.SetupWindow;
  end;

  function TArtikelEditor.GetString(Rec: Pointer; Field: Byte): PChar;
  const
    acS: array[0..3] of Char= #0;
  var
    A: PArtikelRec absolute Rec;
  begin
    if A<>nil then
    case Field of
      1: GetString:=A^.Name;
      2: begin
           Str(A^.Warengruppe, acS);
           GetString:=@acS;           
         end;  
      3: GetString:=A^.EVArt;
      4: GetString:=A^.EVInhalt;
      5: GetString:=@GlobalSettings.MwStString[A^.MwSt];
      else GetString:=nil;
    end else
      GetString:=nil;
  end;

  function TArtikelEditor.EditItem(Data: Pointer): Boolean;
  var
    Dlg: PArtikelDlg;
    Original: TArtikelRec;
  begin
    Move(Data^, Original, SizeOf(Original));
    New(Dlg, Init(PArtikelRec(Data)));
    EditItem:=Application^.ExecDialog(Dlg)=ID_OK;
    UpdateWindow(hMainWindow);
    if not CompareData(Original.EVArt, PArtikelRec(Data)^.EVArt,
      SizeOf(Original.EVArt)+SizeOf(Original.EVInhalt)+SizeOf(Original.MwSt)) then
      Inc(PArtikelRec(Data)^.ChangeRev);
  end;

{
== TArtikelWin (Object) ==
}
  constructor TArtikelWin.Init;
  begin
    TListWindow.Init(Application^.MainWindow, GetResString(str_ArtikelDB));
    Viewer:=New(PArtikelEditor, Init(@Self, ArtikelDB));
  end;

  function TArtikelWin.GetClassName: PChar;
  begin
    GetClassName:='WAWIS:Artikel';
  end;

  procedure TArtikelWin.GetWindowClass(Var AWndClass: TWndClass);
  begin
    TListWindow.GetWindowClass(AWndClass);
    AWndClass.hIcon:=LoadIcon(hInstance, MakeIntResource(ArtikelIcon)); 
  end;

{
== TArtikelDlg (Object) ==
}
  constructor TArtikelDlg.Init(AnArtikel: PArtikelRec);
  var
    E: PEdit;
    V: PValueEdit;
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(ArtikelDlg));
    Artikel:=AnArtikel;
    New(E, InitResource(@Self, ID_BEZEICHNUNG, 31));
    New(V, InitResource(@Self, ID_WGNR, kByte));
    New(E, InitResource(@Self, ID_EVART, 6));
    New(E, InitResource(@Self, ID_EVINHALT, 11));
    TransferBuffer:=@Artikel^.Name;
  end;

  procedure TArtikelDlg.SetupWindow;
  const
    None: array[0..7] of Char= '<keine>'#0;
  var I: Byte;
  begin
    TDialog.SetupWindow;
    SendDlgItemMsg(ID_MWST1+Artikel^.MwSt, BM_SETCHECK, 1, 0);
    for I:=0 to 2 do
      SetWindowText(GetItemHandle(ID_MWST1+I), GlobalSettings.MwStString[I]);
    SendDlgItemMsg(ID_WGNAME, CB_ADDSTRING, 0, LongInt(@None));
    for I:=1 to 10 do
      SendDlgItemMsg(ID_WGNAME, CB_ADDSTRING, 0,
        LongInt(@GlobalSettings.Warengruppe[I]));
    SendDlgItemMsg(ID_WGNAME, CB_SETCURSEL, Artikel^.Warengruppe, 0);
  end;

  procedure TArtikelDlg.IDWGNr(var Msg: TMessage);
  var
    acS: array[0..10] of Char;
    I, C: Integer;
  begin
    if (Msg.lParamHi=en_Update) then
    begin
      GetWindowText(Msg.lParamLo, acS, 11);
      Val(acS, I, C);
      if (I<0) or (I>10) then
      begin
        MessageBeep(0);
        I:=0;
        acS[0]:=#0;
        SetWindowText(Msg.lParamLo, acS);
      end;
      SendDlgItemMsg(ID_WGNAME, CB_SETCURSEL, I, 0);
    end;
  end;

  procedure TArtikelDlg.IDWGName(var Msg: TMessage);
  var
    I: LongInt;
    acS: array[0..2] of Char;
  begin
    if (Msg.lParamHi=cbn_SelChange) then
    begin
      I:=SendDlgItemMsg(ID_WGNAME, CB_GETCURSEL, 0, 0);
      Str(I, acS);
      SetWindowText(GetItemHandle(ID_WGNR), acS);
    end;
  end;

  procedure TArtikelDlg.Ok(var Msg: TMessage);
  begin
    with Artikel^ do
    begin
      MwSt:=0;
      while SendDlgItemMsg(ID_MWST1+MwSt, BM_GETCHECK, 0, 0)<>1 do Inc(MwSt);
    end;
    TDialog.Ok(Msg);
  end;

end.