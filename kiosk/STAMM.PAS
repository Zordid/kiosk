{$I KIOSKCO.PAS}
Unit Stamm;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, MsgBox, App,
    StrObj, StrUtl,
    KioskCmds;

  Type
    PStammItem= ^TStammItem;
    TStammItem= Object(TObject)
      Key: TStr;
      DataRef: LongInt;
      Constructor Init;
      Procedure GetRec(Var Rec); virtual;
      Procedure GetListText(Var S: String; MaxLen: Integer); virtual;
      Function Edit: Word; virtual;
      Procedure Delete; virtual;
      Destructor Done; virtual;
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
    End;

    PStamm= ^TStamm;
    TStamm= Object(TSortedCollection)
      Changed: Boolean;
      Title, Lbl: PString;
      CmdBase: Word;
      Constructor Init;
      Constructor Load(Var S: TStream);
      Procedure InitStamm; virtual;
      Function KeyOf(Item: Pointer): Pointer; virtual;
      Function Compare(Key1, Key2: Pointer): Integer; virtual;
      Function GetNewItem: PStammItem; virtual;
      Function Find: Integer;
      Procedure Edit;
      Function Use(Modal: Boolean): Integer;
    End;

    PItemDialog= ^TItemDialog;
    TItemDialog= Object(TDialog)
      Stamm: PStamm;
      Function DupKeyMessage: Word; virtual;
      Function GetKeyOfData: String; virtual;
      Procedure HandleEvent(Var Event: TEvent); virtual;
    End;

Implementation

{== TStammViewer ==========================================================}

  Type
    PStammViewer= ^TStammViewer;
    TStammViewer= Object(TListViewer)
      Stamm: PStamm;
      SearchPos: Byte;
      Constructor Init(Var Bounds: TRect; ScrollBar: PScrollbar; S: PStamm);
      Function GetText(Item, MaxLen: Integer): String; virtual;
      Procedure HandleEvent(Var Event: TEvent); virtual;
      Procedure SetRange(ARange: Integer);
    End;

    PStammEditDlg= ^TStammEditDlg;
    TStammEditDlg= Object(TDialog)
      Stamm: PStamm;
      Viewer: PStammViewer;
      Constructor Init(S: PStamm);
      Procedure HandleEvent(Var Event: TEvent); virtual;
    End;

  Constructor TStammViewer.Init(Var Bounds: TRect; ScrollBar: PScrollBar; S: PStamm);
  Begin
    TListViewer.Init(Bounds, 1, nil, ScrollBar);
    GrowMode:=gfGrowHiX+gfGrowHiY;
    Options:=Options+ofPostProcess;
    Stamm:=S;
    ShowCursor;
    SetCursor(0, 1);
  End;

  Function TStammViewer.GetText(Item, MaxLen: Integer): String;
  Var S: String;
  Begin
    PStammItem(Stamm^.At(Item))^.GetListText(S, MaxLen);
    GetText:=S;
  End;

  Procedure TStammViewer.HandleEvent(Var Event: TEvent);
  Var
    OldValue, OldPos, I: Integer;
    SearchString: String;
    Space: Boolean;

    Function Equal(S1, S2: String; Count: Word): Boolean;
    Var I: Word;
    Begin
      Equal := False;
      If (Length(S1) < Count) Or (Length(S2) < Count) Then Exit;
      For I := 1 To Count Do
        If S1[I]<>S2[I] then Exit;
      Equal := True;
    End;

  Begin
    Space:=(Event.What=evKeyDown) And (Event.CharCode=#32);
    If Space Then ClearEvent(Event);
    OldValue:=Focused;
    TListViewer.HandleEvent(Event);
    If OldValue<>Focused Then SearchPos:=0;
    If ((Event.What=evKeyDown) And (Event.CharCode<>#0)) Or Space Then
    Begin
      If Space Then Event.CharCode:=#32;
      OldPos:=SearchPos;
      If Event.KeyCode=kbBack Then
      Begin
        If SearchPos>0 Then
        Begin
          Dec(SearchPos);
          SetCursor(Cursor.X-1, Cursor.Y);
        End;
      End Else
      If Event.CharCode>=#32 Then
      Begin
        Inc(SearchPos);
        SearchString:=PStammItem(Stamm^.At(Focused))^.Key.GetStr;
        SearchString[0]:=Char(SearchPos);
        SearchString[SearchPos]:=UpCaseG(Event.CharCode);
        Stamm^.Search(@SearchString, I);
        If (I<Stamm^.Count) And Equal(SearchString, PStammItem(Stamm^.At(I))^.Key.GetStr, SearchPos) Then
        Begin
          If OldValue<>I Then
          Begin
            FocusItem(I);
            { Assumes ListControl will set the cursor to the first character }
            { of the sfFocused item }
            SetCursor(Cursor.X+SearchPos, Cursor.Y);
          End Else
            SetCursor(Cursor.X+(SearchPos-OldPos), Cursor.Y);
        End Else
          SearchPos:=OldPos;
      End Else Exit;
      ClearEvent(Event);
    End;
    If (Event.What=evCommand) And (Event.Command=cmSearch) Then
    Begin
      I:=Stamm^.Find;
      If I<>-1 Then FocusItem(I);
      Select;
      ClearEvent(Event);
    End;
    If (Event.What=evBroadcast) And (Event.Command=cmDupKeys) Then
      FocusItem(Integer(Event.InfoPtr));
  End;

  Procedure TStammViewer.SetRange(ARange: Integer);
  Begin
    TListViewer.SetRange(ARange);
    If ARange=0 Then
      DisableCommands([cmDelete, cmEdit])
    Else
      EnableCommands([cmDelete, cmEdit]);
  End;

{== TStammEditDlg =========================================================}

  Constructor TStammEditDlg.Init(S: PStamm);
  Var R: TRect;
  Begin
    R.Assign(2, 1, 78, 22);
    TDialog.Init(R, S^.Title^);
    HelpCtx:=hcListEdit;
    Stamm:=S;
  End;

  Procedure TStammEditDlg.HandleEvent(Var Event: TEvent);

    Procedure EditItem;
    Var Item: PStammItem;
    Begin
      Item:=PStammItem(Stamm^.At(Viewer^.Focused));
      Stamm^.AtDelete(Viewer^.Focused);
      Viewer^.SetRange(Stamm^.Count);
      Item^.Edit;
      Stamm^.Insert(Item);
      Viewer^.SetRange(Stamm^.Count);
      Viewer^.FocusItem(Stamm^.IndexOf(Item));
    End;

    Procedure InsertItem;
    Var NewItem: PStammItem;
    Begin
      NewItem:=Stamm^.GetNewItem;
      If NewItem^.Edit<>cmCancel Then
      Begin
        Stamm^.Insert(NewItem);
        Viewer^.SetRange(Stamm^.Count);
        Viewer^.FocusItem(Stamm^.IndexOf(NewItem));
      End Else
        Dispose(NewItem, Done);
    End;

    Procedure DeleteItem;
    Begin
      If MessageBox('Datensatz wirklich löschen ?', nil, mfConfirmation+mfYesNoCancel)=cmYes Then
      Begin
        PStammItem(Stamm^.At(Viewer^.Focused))^.Delete;
        Stamm^.AtFree(Viewer^.Focused);
        Viewer^.SetRange(Stamm^.Count);
      End;
    End;

  Begin
    If (Event.What=evKeyDown) And ((Event.KeyCode=kbUp) Or (Event.KeyCode=kbDown)) Then
      Viewer^.Select;
    TDialog.HandleEvent(Event);
    If Event.What=evCommand Then
    Begin
      Case Event.Command Of
        cmEdit: If Stamm^.Count>0 Then EditItem;
        cmInsert: InsertItem;
        cmDelete: DeleteItem;
        Else Exit;
      End;
      Viewer^.Draw;
      Stamm^.Changed:=True;
      Message(DeskTop, evBroadcast, cmStammChanged, nil);
      ClearEvent(Event);
    End;
  End;

{== TStammUseDlg ==========================================================}

  Type
    PStammUseDlg= ^TStammUseDlg;
    TStammUseDlg= Object(TDialog)
      Stamm: PStamm;
      Viewer: PStammViewer;
      Constructor Init(S: PStamm);
      Procedure HandleEvent(Var Event: TEvent); virtual;
      Procedure SizeLimits(Var Min, Max: TPoint); virtual;
    End;

  Constructor TStammUseDlg.Init(S: PStamm);
  Var R: TRect;
  Begin
    R.Assign(41, 0, 80, 23);
    TDialog.Init(R, S^.Title^);
    Options:=Options+ofFirstClick;
    Flags:=Flags+wfGrow+wfZoom;
    HelpCtx:=hcListUse;
    Stamm:=S;
  End;

  Procedure TStammUseDlg.HandleEvent(Var Event: TEvent);
  Begin
    TDialog.HandleEvent(Event);
    If (Event.What=evBroadcast) And (Event.Command=cmStammChanged) Then
      Viewer^.Draw;
    If (Event.What And evMessage<>0) And (Event.Command=cmListItemSelected) Then
    Begin
      Viewer^.SearchPos:=0;
      Viewer^.SetCursor(1, Viewer^.Cursor.Y);
      If GetState(sfModal) Then
        EndModal(cmOk)
      Else
        Message(DeskTop, evBroadcast, Stamm^.CmdBase, Pointer(Viewer^.Focused));
      ClearEvent(Event);
    End;
    If (Event.What=evBroadcast) And (Event.Command=cmLookforStamm) And
      (Event.InfoPtr=Pointer(Stamm)) Then ClearEvent(Event);
  End;

  Procedure TStammUseDlg.SizeLimits(Var Min, Max: TPoint);
  Begin
    TDialog.SizeLimits(Min, Max);
    Inc(Min.X, 19);
    Inc(Min.Y, 5);
  End;

{== TItemDialog ===========================================================}

  Function TItemDialog.GetKeyOfData: String;
  Begin
    Abstract;
  End;

  Function TItemDialog.DupKeyMessage;
  Begin
    Abstract;
  End;

  Procedure TItemDialog.HandleEvent(Var Event: TEvent);
  Var
    Key: String;
    I: Integer;
  Begin
    If (Event.What=evCommand) And (Event.Command=cmOK) Then
    Begin
      Key:=GetKeyOfData;
      If Stamm^.Search(@Key, I) Then
      Begin
        Message(DeskTop, evBroadcast, cmDupKeys, Pointer(I));
        If DupKeyMessage=cmCancel Then
          Event.Command:=cmCancel
        Else
          ClearEvent(Event);
      End;
    End;
    TDialog.HandleEvent(Event);
  End;

{== TStammItem ============================================================}

  Constructor TStammItem.Init;
  Begin
    TObject.Init;
    Key.Init('');
    DataRef:=-1;
  End;

  Constructor TStammItem.Load(Var S: TStream);
  Begin
    Key.Load(S);
    S.Read(DataRef, SizeOf(DataRef));
  End;

  Procedure TStammItem.Store(Var S: TStream);
  Begin
    Key.Store(S);
    S.Write(DataRef, SizeOf(DataRef));
  End;

  Procedure TStammItem.GetRec(Var Rec);
  Begin
    Abstract;
  End;

  Procedure TStammItem.GetListText(Var S: String; MaxLen: Integer);
  Begin
    Abstract;
  End;

  Function TStammItem.Edit: Word;
  Begin
    Abstract;
  End;

  Procedure TStammItem.Delete;
  Begin
    Abstract;
  End;

  Destructor TStammItem.Done;
  Begin
    Key.Done;
    TObject.Done;
  End;

{== TStamm ================================================================}

  Constructor TStamm.Init;
  Begin
    TSortedCollection.Init(10, 10);
    Changed:=True;
    InitStamm;
  End;

  Constructor TStamm.Load(Var S: TStream);
  Begin
    TSortedCollection.Load(S);
    InitStamm;
    Changed:=False;
  End;

  Procedure TStamm.InitStamm;
  Begin
  End;

  Function TStamm.KeyOf(Item: Pointer): Pointer;
  Begin
    KeyOf:=PStammItem(Item)^.Key.P
  End;

  Function TStamm.Compare(Key1, Key2: Pointer): Integer;
  Begin
    If String(Key1^)<String(Key2^) then Compare:=-1 Else
      If StrEqu(String(Key1^), String(Key2^)) Then Compare:=0 Else
        Compare:=1;
  End;

  Function TStamm.GetNewItem: PStammItem;
  Begin
    Abstract;
  End;

  Function TStamm.Find: Integer;
  Var
    SearchStr: String;
    R: TRect;
    SB: PScrollbar;
    Dlg: PDialog;
    Viewer: PStammViewer;
    P: PStamm;
    I: Integer;
  Begin
    Find:=-1;
    SearchStr:='';
    If InputBox('Suchen', 'Bitte Suchtext angeben', SearchStr, 255)=cmOk Then
    Begin
      StrUprG(SearchStr);
      P:=New(PStamm, Init);
      For I:=0 To Count-1 Do
      Begin
        If Pos(SearchStr, PStammItem(At(I))^.Key.GetStr)<>0 Then
          P^.Insert(At(I));
      End;
      If P^.Count<>0 Then
      Begin
        If P^.Count>1 Then
        Begin
          R.Assign(12,3,69,19);
          New(Dlg, Init(R, 'Mehrere Datensätze gefunden...'));
          R.Assign(53,2,54,12);
          SB := New(PScrollbar, Init(R));
          Dlg^.Insert(SB);
          R.Assign(3,2,53,12);
          Viewer := New(PStammViewer, Init(R, SB, P));
          Viewer^.SetRange(P^.Count);
          Dlg^.Insert(Viewer);
          R.Assign(30,13,41,15);
          Dlg^.Insert(New(PButton, Init(R, 'OK', cmOK, bfDefault)));
          R.Assign(43,13,54,15);
          Dlg^.Insert(New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal)));
          Dlg^.SelectNext(False);
          If DeskTop^.ExecView(Dlg)=cmOk Then
            Find:=IndexOf(P^.At(Viewer^.Focused));
          Dispose(Dlg, Done);
        End Else
          Find:=IndexOf(P^.At(0));
      End Else
        MessageBox('Keine passenden Datensätze gefunden.', nil, mfInformation+mfOkButton);
      P^.DeleteAll;
      Dispose(P, Done);
    End;
  End;

  Procedure TStamm.Edit;
  Var
    R: TRect;
    Dlg: PStammEditDlg;
    AVScrollBar: PScrollBar;
    Control: PView;
    SUse: PStammUseDlg;
  Begin
    New(Dlg, Init(@Self));
    R.Assign(3, 1, 73, 2);
    Dlg^.Insert(New(PStaticText, Init(R, Lbl^)));
    R.Assign(73, 2, 74, 17);
    AVScrollBar:=New(PScrollBar, Init(R));
    Dlg^.Insert(AVScrollBar);
    R.Assign(2, 2, 73, 17);
    Control:=New(PStammViewer, Init(R, AVScrollBar, @Self));
    PStammViewer(Control)^.SetRange(Count);
    Dlg^.Insert(Control);
    Dlg^.Viewer:=PStammViewer(Control);
    R.Assign(1, 18, 13, 20);
    Dlg^.Insert(New(PButton, Init(R, '~S~uchen', cmSearch, bfNormal)));
    R.Assign(15, 18, 29, 20);
    Dlg^.Insert(New(PButton, Init(R, 'Ändern', cmEdit, bfDefault)));
    R.Assign(31, 18, 45, 20);
    Dlg^.Insert(New(PButton, Init(R, 'Einfügen', cmInsert, bfNormal)));
    R.Assign(47, 18, 61, 20);
    Dlg^.Insert(New(PButton, Init(R, 'Entfernen', cmDelete, bfNormal)));
    R.Assign(63, 18, 73, 20);
    Dlg^.Insert(New(PButton, Init(R, 'OK', cmOK, bfNormal)));
    Dlg^.SelectNext(False);
    SUse:=Message(Desktop, evBroadcast, cmLookforStamm, @Self);
    If SUse<>nil Then
      Dlg^.Viewer^.FocusItem(SUse^.Viewer^.Focused);
    DeskTop^.ExecView(Dlg);
    Dispose(Dlg, Done);
  End;

  Function TStamm.Use(Modal: Boolean): Integer;
  Var
    R: TRect;
    Dlg: PStammUseDlg;
    Button: PButton;
    AVScrollBar: PScrollBar;
  Begin
    Use:=-1;
    Dlg:=Message(DeskTop, evBroadcast, cmLookforStamm, @Self);
    If (Dlg=nil) Or Modal Then
    Begin
      Dlg:=New(PStammUseDlg, Init(@Self));
      R.Assign(36, 1, 37, 19);
      AVScrollBar:=New(PScrollBar, Init(R));
      Dlg^.Insert(AVScrollBar);
      R.Assign(2, 1, 36, 19);
      Dlg^.Viewer:=New(PStammViewer, Init(R, AVScrollBar, @Self));
      Dlg^.Viewer^.SetRange(Count);
      Dlg^.Insert(Dlg^.Viewer);
      R.Assign(1, 20, 11, 22);
      Button:=New(PButton, Init(R, 'Wählen', cmListItemSelected, bfDefault));
      Button^.GrowMode:=gfGrowHiY+gfGrowLoY;
      Dlg^.Insert(Button);
      R.Assign(12, 20, 22, 22);
      Button:=New(PButton, Init(R, '~S~uchen', cmSearch, bfNormal));
      Button^.GrowMode:=gfGrowHiY+gfGrowLoY;
      Dlg^.Insert(Button);
      If Modal Then
      Begin
        R.Assign(23, 20, 34, 22);
        Button:=New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal));
        Button^.GrowMode:=gfGrowHiY+gfGrowLoY;
        Dlg^.Insert(Button);
        R.Assign(2, 3, 78, 20);
        Dlg^.Locate(R);
      End;
      Dlg^.SelectNext(False);
      If Modal Then
      Begin
        If DeskTop^.ExecView(Dlg)=cmOk Then Use:=Dlg^.Viewer^.Focused;
        Dispose(Dlg, Done);
      End Else
        DeskTop^.Insert(Dlg);
    End Else
      Dlg^.Select;
  End;

End.