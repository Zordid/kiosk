unit Betriebe;
interface
  uses
    Objects, OWindows, ODialogs, WinTypes, WinProcs,
    Globals, ListWin, DBServer, DBEditor;

  type
    TAnschrift= array[0..2, 0..40] of Char;

    PBetriebRec= ^TBetriebRec;
    TBetriebRec= record
      Nr: LongInt;
      Name: array[0..40] of Char;
      Anschrift: TAnschrift;
      Telefon, Telefax: array[0..30] of Char;
      Kind: Word;
    end;

    PBetriebeEditor= ^TBetriebeEditor;
    TBetriebeEditor= object(TDBEditor)
      procedure SetupWindow; virtual;
      function GetString(Rec: Pointer; Field: Byte): PChar; virtual;
      function EditItem(Data: Pointer): Boolean; virtual;
    end;

    PBetriebeWin= ^TBetriebeWin;
    TBetriebeWin= object(TListWindow)
      constructor Init;
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(var AWndClass: TWndClass); virtual;
    end;

    PBetriebDlg= ^TBetriebDlg;
    TBetriebDlg= object(TDialog)
      Betrieb: PBetriebRec;
      constructor Init(ABetrieb: PBetriebRec);
      procedure SetupWindow; virtual;
      procedure Ok(var Msg: TMessage); virtual id_First+id_Ok;
    end;

  const
    BetriebeDB: PDatabase= nil;

  function SelectBetrieb: LongInt;

implementation

{
== TBetriebeEditor (Object) ==
}
  procedure TBetriebeEditor.SetupWindow;
  begin
    LocalMenu:=BetriebMenu;
    DeleteQuery:=str_BetriebDeleteQuery;
    Range.X:=3;
    AddListCol(1, 350, GetResString(str_Betrieb), False);
    AddListCol(5, 200, GetResString(str_Ort), False);
    AddListCol(6, 200, GetResString(str_Telefon), False);
    TDBEditor.SetupWindow;
  end;

  function TBetriebeEditor.GetString(Rec: Pointer; Field: Byte): PChar;
  var L: PBetriebRec absolute Rec;
  begin
    if L<>nil then
    case Field of
      1: GetString:=L^.Name;
      3: GetString:=L^.Anschrift[0];
      4: GetString:=L^.Anschrift[1];
      5: GetString:=L^.Anschrift[2];
      6: GetString:=L^.Telefon;
      else GetString:=nil;
    end else
      GetString:=nil;
  end;

  function TBetriebeEditor.EditItem(Data: Pointer): Boolean;
  var Dlg: PBetriebDlg;
  begin
    New(Dlg, Init(PBetriebRec(Data)));
    EditItem:=Application^.ExecDialog(Dlg)=ID_OK;
    UpdateWindow(hMainWindow);
  end;

{
== TBetriebeWin (Object) ==
}
  constructor TBetriebeWin.Init;
  begin
    TListWindow.Init(Application^.MainWindow, GetResString(str_BetriebDB));
    Viewer:=New(PBetriebeEditor, Init(@Self, BetriebeDB));
  end;

  function TBetriebeWin.GetClassName: PChar;
  begin
    GetClassName:='WAWIS:Betriebe';
  end;

  procedure TBetriebeWin.GetWindowClass(var AWndClass: TWndClass);
  begin
    TListWindow.GetWindowClass(AWndClass);
    AWndClass.hIcon:=LoadIcon(hInstance, MakeIntResource(BetriebIcon));
  end;

{
== TBetriebDlg (Object) ==
}
  constructor TBetriebDlg.Init(ABetrieb: PBetriebRec);
  var
    E: PEdit;
    I: Byte;
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(BetriebDlg));
    Betrieb:=ABetrieb;
    New(E, InitResource(@Self, ID_BETRIEB, 41));
    for I:=0 to 2 do
      New(E, InitResource(@Self, ID_ANSCHRIFT+I, 41));
    New(E, InitResource(@Self, ID_TELEFON, 31));
    New(E, InitResource(@Self, ID_TELEFAX, 31));
    TransferBuffer:=@Betrieb^.Name;
  end;

  procedure TBetriebDlg.SetupWindow;
  begin
    TDialog.SetupWindow;
    SendDlgItemMsg(ID_BETRIEBSART+Betrieb^.Kind, BM_SETCHECK, 1, 0);
  end;

  procedure TBetriebDlg.Ok(var Msg: TMessage);
  begin
    with Betrieb^ do
    begin
      Kind:=0;
      while SendDlgItemMsg(ID_BETRIEBSART+Kind, BM_GETCHECK, 0, 0)<>1 do Inc(Kind);
    end;
    TDialog.Ok(Msg);
  end;

{
== TSelectBetriebDlg ==
}
  type
    PSelectBetriebDlg= ^TSelectBetriebDlg;
    TSelectBetriebDlg= object(TDialog)
      L: PListBox;
      Data: ^LongInt;
      NrColl: TCollection;
      constructor Init;
      destructor Done; virtual;
      procedure SetupWindow; virtual;
      procedure OK(var Msg: TMessage); virtual id_First+id_Ok;
      procedure Listbox(var Msg: TMessage); virtual id_First+id_ListBox;
    end;

  constructor TSelectBetriebDlg.Init;
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(SelectDlg));
    New(L, InitResource(@Self, id_ListBox));
  end;

  procedure TSelectBetriebDlg.SetupWindow;
  var
    E: PBufferElement;
    I: Integer;
    P: PBetriebRec;
    acS: array[0..100] of Char;
  begin
    TDialog.SetupWindow;
    SetWindowText(hWindow, 'Betrieb auswählen');
    SetWindowText(GetItemHandle(id_ListBoxText), '&Betriebe');
    NrColl.Init(10, 10);
    BetriebeDB^.Register(hWindow, 1);
    for I:=0 to BetriebeDB^.NumRecs(hWindow)-1 do
    begin
      P:=PBetriebRec(BetriebeDB^.CheckRec(hWindow, I));
      L^.AddString(P^.Name);
      NrColl.Insert(Pointer(P^.Nr));
    end;
    BetriebeDB^.Unregister(hWindow);
    EnableWindow(hMainWindow, False);
  end;

  destructor TSelectBetriebDlg.Done;
  begin
    NrColl.DeleteAll;
    NrColl.Done;
    TDialog.Done;
  end;

  procedure TSelectBetriebDlg.Ok(var Msg: TMessage);
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

  procedure TSelectBetriebDlg.ListBox;
  begin
    if Msg.lParamHi=lbn_DblClk then Ok(Msg);
  end;

  function SelectBetrieb: LongInt;
  var
    P: PSelectBetriebDlg;
    L: LongInt;
  begin
    New(P, Init);
    P^.Data:=@L;
    if Application^.ExecDialog(P)<>ID_CANCEL then
      SelectBetrieb:=L
    else
      SelectBetrieb:=-1;
  end;

end.
