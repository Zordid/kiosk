unit Einkauf;
interface
  uses
    Objects, OWindows, ODialogs,
    WinTypes, WinProcs, Strings, DlgObj, WaitDlg,
    Globals, BarCodes, Dialogs, ListWin, DBServer, Artikel, Lieferanten;

  const
    TabsArtikel: array[0..3] of Integer= (110, 130, 150, 190);

  type
    PArtikelEKRec= ^TArtikelEKRec;
    TArtikelEKRec= record
      Nr: LongInt;
      ChangeRev: Byte;
      ArtikelNr: LongInt;
      LieferantenNr: LongInt;
      LieferArtNr: array[0..13] of Char;
      UVMenge: Integer;
      UVPreis: Single;
    End;

    PEKListe= ^TEKListe;
    TEKListe= object(TSortedCollection)
      Owner: THandle;
      Lieferant: LongInt;
      Sort: Integer;
      constructor Init(AnOwner: THandle; ALieferant: LongInt; ASort: Integer);
      destructor Done; virtual;
      procedure FreeItem(Item: Pointer); virtual;
      function KeyOf(Item: Pointer): Pointer; virtual;
      function Compare(Key1, Key2: Pointer): Integer; virtual;
      procedure InsertRec(ANr: LongInt);
      procedure UpdateRec(I: Integer);
      procedure DeleteRec(I: Integer);
      procedure ChangeParams(ALieferant, ASort: Integer);
      procedure GetString(I: Integer; P: PChar);
    end;

    PEKEditor= ^TEKEditor;
    TEKEditor= object(TListViewer)
      EKListe: PEKListe;
      Lieferant: LongInt;
      constructor Init(AParent: PWindowsObject; ALieferant: LongInt);
      destructor Done; virtual;
      procedure SetupWindow; virtual;
      function GetData(Line: Integer): Pointer; virtual;
      function GetString(Rec: Pointer; Field: Byte): PChar; virtual;
      procedure WMInitMenu(var Msg: TMessage); virtual wm_First+wm_InitMenu;
      procedure WMLButtonDblClk(var Msg: TMessage); virtual wm_First+wm_LButtonDblClk;
      procedure WMDBMessage(var Msg: TMessage); virtual wm_First+wm_DBMessage;
      procedure IDMPaste(var Msg: TMessage); virtual cm_First+idm_Paste;
      procedure IDMUpdate(var Msg: TMessage); virtual cm_First+idm_Update;
      procedure IDMDelete(var Msg: TMessage); virtual cm_First+idm_Delete;
      procedure IDMSorting(var Msg: TMessage); virtual cm_First+idm_Sorting; 
    end;

    PEKWindow= ^TEKWindow;
    TEKWindow= object(TListWindow)
      constructor Init(LieferantNr: LongInt);
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(var AWndClass: TWndClass); virtual;
    end;

    PArtikelEKDlg= ^TArtikelEKDlg;
    TArtikelEKDlg= object(TDialog)
      Artikel: PArtikelRec;
      ArtikelEK: PArtikelEKRec;
      Lieferant: PLieferRec;
      Preis: Single;
      constructor Init(AnArtikelEK: PArtikelEKRec; AnArtikel: PArtikelRec; ALieferant: PLieferRec);
      procedure SetupWindow; virtual;
      procedure Ok(var Msg: TMessage); virtual id_First+id_Ok;
    end;

  function SelectEKArtikel: LongInt;    

implementation

  constructor TEKListe.Init(AnOwner: THandle; ALieferant: LongInt; ASort: Integer);
  begin
    TSortedCollection.Init(ArtikelDB^.NumRecs(0), 100);
    Owner:=AnOwner;
    Duplicates:=True;
    EKDB^.Register(Owner, 2);
    ChangeParams(ALieferant, ASort);
  end;

  destructor TEKListe.Done;
  begin
    EKDB^.Unregister(Owner);
    ArtikelDB^.Unregister(Owner);
    TSortedCollection.Done;
  end;

  procedure TEKListe.FreeItem(Item: Pointer);
  begin
  end;

  function TEKListe.KeyOf(Item: Pointer): Pointer;
  begin
    KeyOf:=Pointer(ArtikelDB^.IndexOf(Owner, PArtikelEKRec(Item)^.ArtikelNr));
  end;

  function TEKListe.Compare(Key1, Key2: Pointer): Integer;
  begin
    if LongInt(Key1)<LongInt(Key2) then Compare:=-1 else
      if LongInt(Key1)=LongInt(Key2) then Compare:=0 else
        Compare:=+1;
  end;

  procedure TEKListe.InsertRec(ANr: LongInt);
  var A: TArtikelEKRec;
  begin
    FillChar(A, SizeOf(A), 0);
    A.LieferantenNr:=Lieferant;
    A.ArtikelNr:=ANr;
    A.UVMenge:=1;
    EKDB^.InsertRec(A);
    Insert(EKDB^.GetRecNr(A.Nr));
  end;

  procedure TEKListe.UpdateRec(I: Integer);
  var
    ArtikelEK: PArtikelEKRec;
    Artikel: PArtikelRec;
    Liefer: PLieferRec;
  begin
    ArtikelEK:=PArtikelEKRec(At(I));
    ArtikelEK:=EKDB^.LockRec(Owner, EKDB^.IndexOf(Owner, ArtikelEK^.Nr));
    if ArtikelEK<>nil then
    begin
      Artikel:=ArtikelDB^.GetRecNr(ArtikelEK^.ArtikelNr);
      Liefer:=LieferDB^.GetRecNr(Lieferant);
      if (Artikel<>nil) and (Liefer<>nil) then
      begin
        if Application^.ExecDialog(New(PArtikelEKDlg, Init(ArtikelEK, Artikel, Liefer)))=ID_OK Then
          EKDB^.UpdateRec(Owner, EKDB^.IndexOf(Owner, ArtikelEK^.Nr), ArtikelEK^);
      end;
      EKDB^.UnlockRec(Owner);
    end;
  end;

  procedure TEKListe.DeleteRec(I: Integer);
  var ArtikelEK: PArtikelEKRec;
  begin
    ArtikelEK:=PArtikelEKRec(At(I));
    if EKDB^.DeleteRec(Owner, EKDB^.IndexOf(Owner, ArtikelEK^.Nr)) then AtDelete(I);
  end;

  procedure TEKListe.ChangeParams(ALieferant, ASort: Integer);
  var
    i, Max: Integer;
    Ready: Boolean;
    P: PArtikelEKRec;
    Dlg: PWaitDlg;
  begin
    if ALieferant>=0 then Lieferant:=ALieferant;
    if ASort<0 then ASort:=UserSettings.DefaultArtikelEKSort;
    if Sort<>ASort then
    begin
      Sort:=ASort;
      ArtikelDB^.Unregister(Owner);
      ArtikelDB^.Register(Owner, Sort);
    end;
    FreeAll;
    New(Dlg, Init(Application^.MainWindow, -1, -1, MakeIntResource(LoadingDlg)));
    Application^.MakeWindow(Dlg);
    Dlg^.SetText('Sortiere...');
    Max:=EKDB^.NumRecs(Owner)-1;
    i:=0;
    Ready:=False;
    while i<=Max do
    begin
      P:=PArtikelEKRec(EKDB^.GetRec(Owner, i));
      Inc(i);
      if (i Mod 50)=0 then Dlg^.SetPos(i, Max);
      if P^.LieferantenNr=Lieferant then
      begin
        Ready:=True;
        Insert(P);
      end else
      if Ready then
      begin
        Dispose(Dlg, Done);
        Exit;
      end;
    end;
    Dispose(Dlg, Done);
  end;

  procedure TEKListe.GetString(I: Integer; P: PChar);
  var
    ArtikelEK: PArtikelEKRec;
    Artikel: PArtikelRec;
    Arg: record
      Name: PChar;
      WG: Integer;
      EVArt, EVInhalt: PChar;
      UVMenge: Integer;
    end;
  begin
    ArtikelEK:=PArtikelEKRec(At(I));
    Artikel:=PArtikelRec(ArtikelDB^.GetRecNr(ArtikelEK^.ArtikelNr));
    if Artikel<>nil then
    begin
      with Artikel^ do
      begin
        Arg.Name:=Name;
        Arg.WG:=WarenGruppe;
        Arg.EVArt:=EVArt;
        Arg.EVInhalt:=EVInhalt;
      end;
      Arg.UVMenge:=ArtikelEK^.UVMenge;
      wvsprintf(P, '%s'#9'%02i'#9'%s'#9'%s'#9'%i', Arg);
    end else
      StrCopy(P, GetResString(str_ArtikelDeleted)); 
  end;

{
== TEKEditor (Object) ==
}
  var
    ArtikelRec: PArtikelRec;

  constructor TEKEditor.Init(AParent: PWindowsObject; ALieferant: LongInt);
  begin
    TListViewer.Init(AParent);
    Lieferant:=ALieferant;
  end;

  destructor TEKEditor.Done;
  begin
    LockLieferant(False, Lieferant);
    Dispose(EKListe, Done);
    TListViewer.Done;
  end;

  procedure TEKEditor.SetupWindow;
  var
    L: PLieferRec;
    acS: Array[0..80] Of Char;
  begin
    Range.X:=7;
    AddListCol(1, 200, GetResString(str_Bezeichnung), False);
    AddListCol(2, 25, GetResString(str_Warengruppe), True);
    AddListCol(3, 40, GetResString(str_EVArt), False);
    AddListCol(4, 60, GetResString(str_EVInhalt), False);
    AddListCol(10, 60, GetResString(str_UVMenge), True);
    AddListCol(11, 120, GetResString(str_ArtikelNummer), True);
    AddListCol(12, 60, GetResString(str_UVPreis), True);
    LocalMenu:=ArtikelEKMenu;
    TListViewer.SetupWindow;
    New(EKListe, Init(hWindow, Lieferant, -1));
    Range.Y:=EKListe^.Count;
    L:=LieferDB^.GetRecNr(Lieferant);
    StrCat(StrCopy(acS, 'EK Liste: '), L^.Name);
    SetWindowText(Parent^.hWindow, acS);
  end;

  function TEKEditor.GetData(Line: Integer): Pointer;
  var P: PArtikelEKRec;
  begin
    P:=EKListe^.At(Line);    
    ArtikelRec:=ArtikelDB^.GetRecNr(P^.ArtikelNr);
    GetData:=P;        
  end;

  function TEKEditor.GetString(Rec: Pointer; Field: Byte): PChar;
  const
    acS: array[0..13] of Char= #0;
  var
    A: PArtikelEKRec absolute Rec;
  begin
    GetString:=nil;
    if A<>nil then
    begin
      if ArtikelRec=nil then
      begin
        if Field=1 then GetString:=GetResString(str_ArtikelDeleted);
      end else
      case Field of
        1: GetString:=ArtikelRec^.Name;
        2: begin
             Str(ArtikelRec^.Warengruppe, acS);
             GetString:=@acS;
           end;
        3: GetString:=ArtikelRec^.EVArt;
        4: GetString:=ArtikelRec^.EVInhalt;
        5: GetString:=@GlobalSettings.MwStString[ArtikelRec^.MwSt];
        10: begin
              Str(A^.UVMenge, acS);
              GetString:=@acS;
            end;
        11: GetString:=A^.LieferArtNr;
        12: begin
              Str(A^.UVPreis:0:2, acS);
              ExchangeChar(acS, '.', ',');
              GetString:=@acS;
            end;
      end;
    end;
  end;

  Procedure TEKEditor.WMInitMenu(Var Msg: TMessage);
  Begin
    if Range.Y>0 then 
      EnableMenuItem(hMainMenu, IDM_SELECTALL, MF_ENABLED);
    if IsClipboardFormatAvailable(cf_Artikel) then
      EnableMenuItem(hMainMenu, IDM_PASTE, MF_ENABLED);
  End;

  Procedure TEKEditor.WMLButtonDblClk(Var Msg: TMessage);
  Begin
    TListViewer.WMLButtonDblClk(Msg);
    If Msg.lParamLo>XOffset Then IDMUpdate(Msg);
  End;

  procedure TEKEditor.WMDBMessage(var Msg: TMessage);
  var
    Action: Word;
  begin
    Action:=Msg.wParam and (Not db_Reread+db_Reorder);
    if (Pointer(Msg.lParam)=@ArtikelDB) and (Action=db_Updated) then
      RefreshLines;
  end;

  Procedure TEKEditor.IDMPaste(Var Msg: TMessage);
  Var
    GlbMem: THandle;
    GlbPtr: Pointer;
    ANr: LongInt;
    I, C: Integer;
  Begin
    OpenClipboard(hMainWindow);
    GlbMem:=GetClipboardData(cf_Artikel);
    If GlbMem<>0 Then
    Begin
      GlbPtr:=GlobalLock(GlbMem);
      If GlbPtr<>nil Then
      Begin
        Move(GlbPtr^, C, SizeOf(C));
        Inc(LongInt(GlbPtr), SizeOf(C));
        For I:=1 To C Do
        Begin
          Move(GlbPtr^, ANr, SizeOf(LongInt));
          Inc(LongInt(GlbPtr), SizeOf(LongInt));
          EKListe^.InsertRec(ANr);
        End;
        Range.Y:=EKListe^.Count;
        SetScrollBars;
        RefreshLines;
        GlobalUnlock(GlbMem);
      End;
    End;
    CloseClipboard;
  End;

  Procedure TEKEditor.IDMUpdate(Var Msg: TMessage);
  Begin
    If GetFocused=-1 Then Exit;
    EKListe^.UpdateRec(GetFocused);
    UpdateWindow(hWindow);
    RefreshLines;
  End;

  procedure TEKEditor.IDMDelete(var Msg: TMessage);
  var
    Cancel, All: Boolean;
    D: PDeleteDlg;
    i: Integer;
    acS: array[0..100] of Char;
    acD: array[0..30] of Char;

    function DoDelete(Line: Integer): Boolean; 
    var
      ok: Boolean;
      Cmd: Integer;
      ArtikelEK: PArtikelEKRec;
      Artikel: PArtikelRec;
      P: Pointer;
    begin
      DoDelete:=False;
      if Cancel then Exit;
      if not All then
      begin
        ArtikelEK:=PArtikelEKRec(EKListe^.At(Line));
        Artikel:=ArtikelDB^.GetRecNr(ArtikelEK^.ArtikelNr);
        if Artikel=nil then
        begin
          StrCopy(acD, GetResString(str_ArtikelDeleted));
          P:=@acD;
        end else
          P:=@Artikel^.Name;
        wvsprintf(acS, GetResString(str_EKArtikelDeleteQuery), P);
        New(D, Init(acS, Selected.Count>0));
        Cmd:=Application^.ExecDialog(D);
        ok:=(Cmd=ID_YES) or (Cmd=ID_ALL);
        All:=Cmd=ID_ALL;
        Cancel:=Cmd=ID_CANCEL;
      end;
      if ok then
      begin
        EKListe^.DeleteRec(Line);
        DoDelete:=True;
        Selected.DeleteLine(Line);
        Range.Y:=EKListe^.Count;
        if GetFocused>=Range.Y then SetFocused(Range.Y-1);
        SetScrollBars;
        RefreshLines;
      end;
    end;

  begin
    if (GetFocused=-1) and (Selected.Count=0) then Exit;
    Cancel:=False;
    All:=False;
    if Selected.Count>0 then
    begin
      i:=0;
      while i<Selected.Count do
        if not DoDelete(Integer(Selected.At(i))) then Inc(i);
    end else
      DoDelete(GetFocused);
  end;

  procedure TEKEditor.IDMSorting;
  var
    Dlg: PSortDlg;
    S: Integer;
    NEK: PEKListe;
  begin
    New(Dlg, Init(@Self, 'Einkaufsliste', MakeIntResource(ArtikelSortDlg)));
    S:=EKListe^.Sort;
    Dlg^.Keypath:=@S;
    if (Application^.ExecDialog(Dlg)=ID_OK) and (S<>EKListe^.Sort) then
    begin
      UpdateWindow(hMainWindow);
      EKListe^.ChangeParams(-1, S);
      Selected.DeleteAll;
      InvalidateRect(hWindow, nil, False);
    end;
  end;

{
== TEKWindow (Object) ==
}
  constructor TEKWindow.Init(LieferantNr: LongInt);
  begin
    TListWindow.Init(Application^.MainWindow, nil);
    Viewer:=New(PEKEditor, Init(@Self, LieferantNr));
  end;

  function TEKWindow.GetClassName: PChar;
  begin
    GetClassName:='WAWIS:EKListe';
  end;

  procedure TEKWindow.GetWindowClass(var AWndClass: TWndClass);
  begin
    TListWindow.GetWindowClass(AWndClass);
    AWndClass.hIcon:=LoadIcon(hInstance, MakeIntResource(EKListeIcon));
  end;

{
== TArtikelEKDlg (Object) ==
}
  Constructor TArtikelEKDlg.Init(AnArtikelEK: PArtikelEKRec; AnArtikel: PArtikelRec;
    ALieferant: PLieferRec);
  Var
    E: PEdit;
    V: PValueEdit;
  Begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(ArtikelEKDlg));
    Artikel:=AnArtikel;
    ArtikelEK:=AnArtikelEK;
    Lieferant:=ALieferant;
    New(E, InitResource(@Self, ID_ARTIKELNR, SizeOf(AnArtikelEK^.LieferArtNr)));
    New(V, InitResource(@Self, ID_MENGE, kInteger));
    New(V, InitResource(@Self, ID_PREIS, kSingle));
    TransferBuffer:=@ArtikelEK^.LieferArtNr;
  End;

  Procedure TArtikelEKDlg.SetupWindow;
  Begin
    TDialog.SetupWindow;
    With Artikel^ Do
    Begin
      SetWindowText(GetItemHandle(ID_BEZEICHNUNG), Name);
      If Warengruppe>0 Then
        SetWindowText(GetItemHandle(ID_WARENGRUPPE), GlobalSettings.Warengruppe[Warengruppe]);
      SetWindowText(GetItemHandle(ID_EVART), EVArt);
      SetWindowText(GetItemHandle(ID_EVINHALT), EVInhalt);
    End;
    With Lieferant^ Do
      SetWindowText(GetItemHandle(ID_FIRMA), Name);
  End;

  Procedure TArtikelEKDlg.Ok(Var Msg: TMessage);
  var
    acS: array[0..20] of Char;
    B: TBarCode;
  Begin
    GetWindowText(GetItemHandle(id_ArtikelNr), acS, SizeOf(acS));
    B.Init(acS);
    if B.Typ=None then
    begin
      MessageBeep(0);
      MessageBox(hWindow, 'EAN-Code ungültig !', 'Achtung', mb_IconExclamation or mb_Ok);
    end;
    B.Done;
    TDialog.Ok(Msg);
  End;

{== SelectEKArtikel function ==}
  type
    PSelectEKDlg= ^TSelectEKDlg;
    TSelectEKDlg= object(TDialog)
      LieferantenNr: TCollection;
      ActLieferant: LongInt;
      ActEKListe: PEKListe;
      Data: PLongInt;
      constructor Init;
      procedure SetupWindow; virtual;
      destructor Done; virtual;
      procedure IDCB(var Msg: TMessage); virtual id_First+id_Lieferanten;
      procedure Ok(var Msg: TMessage); virtual id_First+id_Ok;
     private
      CB: PComboBox;
      LB: PListBox;
    end;

  constructor TSelectEKDlg.Init;
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(SelectEKDlg));
    New(CB, InitResource(@Self, id_Lieferanten, 30));
    New(LB, InitResource(@Self, id_Einkauf));
    ActLieferant:=-1;
    ActEKListe:=nil;
  end;

  procedure TSelectEKDlg.SetupWindow;
  var
    i: Integer;
    L: PLieferRec;
  begin
    TDialog.SetupWindow;
    SendMessage(LB^.hWindow, lb_SetTabStops, SizeOf(TabsArtikel) Div 2, LongInt(@TabsArtikel));
    LieferDB^.Register(hWindow, 1);
    LieferantenNr.Init(10, 10);
    for i:=0 to LieferDB^.NumRecs(hWindow)-1 do
    begin
      L:=PLieferRec(LieferDB^.GetRec(hWindow, i));
      CB^.AddString(L^.Name);
      LieferantenNr.Insert(Pointer(L^.Nr));
    end;
    CB^.SetSelIndex(-1);
    LieferDB^.Unregister(hWindow);
  end;

  destructor TSelectEKDlg.Done;
  begin
    LieferantenNr.DeleteAll;
    LieferantenNr.Done;
    if ActEKListe<>nil then Dispose(ActEKListe, Done);
    TDialog.Done;
  end;

  procedure TSelectEKDlg.IDCB;
  var
    i: Integer;
    acS: array[0..100] of Char;
  begin
    if Msg.lParamHi=cbn_SelChange then
    begin
      ActLieferant:=LongInt(LieferantenNr.At(CB^.GetSelIndex));
      if ActEKListe=nil then
        New(ActEKListe, Init(hWindow, ActLieferant, -1))
      else
        ActEKListe^.ChangeParams(ActLieferant, -1);
      LB^.ClearList;
      for i:=0 to ActEKListe^.Count-1 do
      begin
        ActEKListe^.GetString(i, acS);
        LB^.AddString(acS);
      end;
      SetActiveWindow(hWindow);
      EnableWindow(Parent^.hWindow, False);
    end;
  end;

  procedure TSelectEKDlg.Ok;
  begin
    if LB^.GetSelIndex>=0 then
    begin
      Data^:=PArtikelEKRec(ActEKListe^.At(LB^.GetSelIndex))^.Nr;
      TDialog.Ok(Msg);
    end else
      MessageBeep(0);
  end;

  function SelectEKArtikel: LongInt;
  var
    EKArtikel: LongInt;
    D: PSelectEKDlg;
  begin
    New(D, Init);
    D^.Data:=@EKArtikel;
    EKArtikel:=-1;
    Application^.ExecDialog(D);
    SelectEKArtikel:=EKArtikel;
  end;

end.