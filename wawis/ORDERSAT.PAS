unit Ordersatz;
interface
  uses
    Objects, OWindows, ODialogs, OStdDlgs,
    WinTypes, WinProcs, BWCC, Strings, DlgObj, WinDos,
    Win31, CommDlg, MDITools,
    Globals, Communication, Dialogs, DBServer, Artikel, Lieferanten, Einkauf;

  const
    TabsOS: array[0..5] of Integer= (5, 25, 150, 170, 210, 250);

  { Ordersatz Definitionen }
  type
    POSItem= ^TOSItem;
    TOSItem= object(TObject)
      ArtikelEKNr: LongInt;
      Count: Word;
      constructor Init(AnArtikelEKNr: LongInt);
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
    end;

    POSGroup= ^TOSGroup;
    TOSGroup= object(TObject)
      Index: Integer;
      Name: PChar;
      constructor Init(AName: PChar);
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
      destructor Done; virtual;
    end;

    TGroups= object(TSortedCollection)
      procedure FreeItem(Item: Pointer); virtual;
      function KeyOf(Item: Pointer): Pointer; virtual;
      function Compare(Key1, Key2: Pointer): Integer; virtual;
    end;

    POrdersatz= ^TOrdersatz;
    TOrdersatz= object(TCollection)
      Name: PChar;
      Changed: Boolean;
      HasExtras: Boolean;
      constructor Init;
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
      destructor Done; virtual;
      procedure FreeItem(Item: Pointer); virtual;
      procedure InsertGroup(Index: Integer; AGroup: POSGroup);
      procedure InsertItem(Index: Integer; AnItem: POSItem; ACount: Integer);
      procedure DeleteItem(Index: Integer);
      procedure GetStr(Index: Integer; P: PChar; Line: PInteger);
      function GetLineNo(Index: Integer): Integer;
      function GetIndex(LineNo: Integer): Integer;
      function IsGroup(Index: Integer): Boolean;
     private
      Groups: TGroups;
      procedure ShiftGroups(From, By: Integer);
    end;

  { Ordersatzeditor }
  const
    id_Ordersatz   = 202;
    id_NameEdit    = 203;

  type
    POrdersatzWin= ^TOrdersatzWin;
    TOrdersatzWin= object(TWindow)
      LieferantenNr: TCollection;
      ActLieferant: LongInt;
      ActEKListe: PEKListe;
      ActOS: POrdersatz;
      ActStream: PShareStream;
      ActSorting: Integer;
      FileName: PChar;
      Mode: Word;
      WindowTitle: PChar;
      constructor Init(AFileName: PChar; ATitle: PChar; AMode: Word);
      destructor Done; virtual;
      procedure SetupWindow; virtual;
      function CanClose: Boolean; virtual;
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(var AWndClass: TWndClass); virtual;
      procedure WMSize(var Msg: TMessage); virtual wm_First+wm_Size;
      procedure WMInitMenu(var Msg: TMessage); virtual wm_First+wm_InitMenu;
      procedure WMLocalMenu(var Msg: TMessage); virtual wm_First+wm_LocalMenu;
      { Editierfunktionen }
      procedure IDLieferanten(var Msg: TMessage); virtual id_First+id_Lieferanten;
      procedure IDNameEdit(var Msg: TMessage); virtual id_First+id_NameEdit;
      procedure IDInsert(var Msg: TMessage); virtual id_First+id_Insert;
      procedure IDDelete(var Msg: TMessage); virtual id_First+id_Delete;
      procedure IDItem(var Msg: TMessage); virtual id_First+id_Item;
      procedure IDGroup(var Msg: TMessage); virtual id_First+id_Group;
      procedure IDSave(var Msg: TMessage); virtual id_First+id_Save;
      function GetNewFilename: Boolean;
      procedure IDMSave(var Msg: TMessage); virtual cm_First+idm_OSSave;
      procedure IDMSaveAs(var Msg: TMessage); virtual cm_First+idm_OSSaveAs;
      procedure IDMInsert(var Msg: TMessage); virtual cm_First+idm_Insert;
      procedure IDMDelete(var Msg: TMessage); virtual cm_First+idm_Delete;
      procedure IDMUpdate(var Msg: TMessage); virtual cm_First+idm_Update;
      procedure IDMExport(var Msg: TMessage); virtual cm_First+idm_Export;
      procedure IDMSorting(var Msg: TMessage); virtual cm_First+idm_Sorting;
      procedure IDMHorzVert(var Msg: TMessage); virtual cm_First+idm_HorzVert;
     private
      CBLieferanten: PComboBox;
      LBEinkauf, LBOrdersatz: PListBox;
      NameEdit: PEdit;
      B1, B2, B3, B4, B5: PButton;
      GB1, GB2, GB3: PBGroupBox;
      Font: HFont;
      DisplayMode: Byte;
      procedure UpdateOrdersatz;
      function SaveOrdersatz(SaveAs: Boolean): Boolean;
    end;

  procedure ActiveOSList;
  function SelectOrdersatz: LongInt;
  procedure InitOpenFNBuffer(var OpenFN: TOpenFileName; Title: PChar);
  procedure RegisterOrdersatz;
  function LoadOrdersatz(OSNr, BetriebeExtras: LongInt): POrdersatz;
  function AddExtra(BetriebeExtras: LongInt): Boolean;

implementation

  constructor TOSItem.Init(AnArtikelEKNr: LongInt);
  begin
    TObject.Init;
    ArtikelEKNr:=AnArtikelEKNr;
    Count:=0;
  end;

  constructor TOSItem.Load(var S: TStream);
  begin
    S.Read(ArtikelEKNr, SizeOf(ArtikelEKNr));
    Count:=0;
  end;

  procedure TOSItem.Store(var S: TStream);
  begin
    S.Write(ArtikelEKNr, SizeOf(ArtikelEKNr));
  end;

  constructor TOSGroup.Init(AName: PChar);
  begin
    TObject.Init;
    Name:=StrNew(AName);
  end;

  constructor TOSGroup.Load(var S: TStream);
  begin
    S.Read(Index, SizeOf(Index));
    Name:=S.StrRead;
  end;

  procedure TOSGroup.Store(var S: TStream);
  begin
    S.Write(Index, SizeOf(Index));
    S.StrWrite(Name);
  end;

  destructor TOSGroup.Done;
  begin
    StrDispose(Name);
    TObject.Done;
  end;

{== TGroups ==}
  procedure TGroups.FreeItem;
  begin
  end;

  function TGroups.KeyOf(Item: Pointer): Pointer;
  begin
    KeyOf:=@POSGroup(Item)^.Index;
  end;

  function TGroups.Compare(Key1, Key2: Pointer): Integer;
  var
    I1: PInteger absolute Key1;
    I2: PInteger absolute Key2; 
  begin
    if I1^<I2^ then Compare:=-1 else
      if I1^>I2^ then Compare:=+1 else
        Compare:=0;
  end;

{== TOrdersatz ==}
  const
    OSVer: Byte= 0;

  constructor TOrdersatz.Init;
  begin
    TCollection.Init(200, 200);
    Groups.Init(10, 10);
    Name:=nil;
    Changed:=False;
    HasExtras:=False;
  end;

  constructor TOrdersatz.Load(var S: TStream);
  var
    V: Byte;
    C: Integer;
    Item: PObject;

  begin
    TCollection.Load(S);
    S.Read(V, SizeOf(V));
    Name:=S.StrRead;
    Groups.Init(10, 10);
    for C:=0 to Count-1 do
    begin
      Item:=At(C);
      if (Item<>nil) and (TypeOf(Item^)=TypeOf(TOSGroup)) then
      begin
        POSGroup(Item)^.Index:=C;
        Groups.Insert(Item);
      end;
    end;
    Changed:=False;
    HasExtras:=False;
  end;

  procedure TOrdersatz.Store(var S: TStream);
  begin
    TCollection.Store(S);
    S.Write(OSVer, SizeOf(OSVer));
    S.StrWrite(Name);
  end;

  destructor TOrdersatz.Done;
  begin
    Groups.Done;
    TCollection.Done;
  end;

  procedure TOrdersatz.FreeItem(Item: Pointer);
  var i: Integer;
  begin
    if Item<>nil then
    begin
      i:=Groups.IndexOf(Item);
      if i>=0 then Groups.AtDelete(i);
      TCollection.FreeItem(Item);
    end;
  end;

  procedure TOrdersatz.InsertGroup(Index: Integer; AGroup: POSGroup);
  begin
    AGroup^.Index:=Index;
    ShiftGroups(Index, 1);
    Groups.Insert(AGroup);
    AtInsert(Index, AGroup);
    Changed:=True;
  end;

  procedure TOrdersatz.InsertItem(Index: Integer; AnItem: POSItem; ACount: Integer);
  var c: Integer;
  begin
    ShiftGroups(Index, ACount);
    for c:=1 to ACount do AtInsert(Index, AnItem);
    Changed:=True;
  end;

  procedure TOrdersatz.DeleteItem(Index: Integer);
  begin
    ShiftGroups(Index, -1);
    AtFree(Index);
    Changed:=True;
  end;

  procedure TOrdersatz.ShiftGroups(From, By: Integer);
  var i: Integer;
  begin
    Groups.Search(@From, i);
    while i<Groups.Count do
    begin
      Inc(POSGroup(Groups.At(i))^.Index, By);
      Inc(i);
    end;
  end;

  function TOrdersatz.GetLineNo(Index: Integer): Integer;
  var i, c: Integer;
  begin
    c:=0;
    while (c<Groups.Count) and (POSGroup(Groups.At(c))^.Index<=Index) do Inc(c);
    GetLineNo:=Index-(c-1);
  end;

  function TOrdersatz.GetIndex(LineNo: Integer): Integer;
  var
    i, l, c, Idx: Integer;
    Itm: POSItem;
  begin
    Idx:=-1;
    l:=0;
    i:=0;
    while (l<>LineNo) and (i<Count) do
    begin
      Itm:=POSItem(At(i));
      if (Itm=nil) or (TypeOf(Itm^)<>TypeOf(TOSGroup)) then Inc(l);
      inc(i);
    end;
    dec(i);
    if (l=LineNo) and ((Itm=nil) or (TypeOf(Itm^)<>TypeOf(TOSGroup))) then
      Idx:=i;
    {
    if LineNo>0 then
    begin
      c:=0;
      l:=0;
      while (c<Groups.Count) and (l<LineNo) do
      begin
        while (c<Groups.Count-1) and
          (POSGroup(Groups.At(c+1))^.Index=POSGroup(Groups.At(c))^.Index+1) do
          Inc(c);
        i:=POSGroup(Groups.At(c))^.Index+1;
        l:=i-c;
        Inc(c);
      end;
      if l>LineNo then
        Idx:=i-(l-LineNo)-1
      else
        Idx:=i+(LineNo-l);
    end;
    if Idx>=Count then Idx:=-1;
    }
    GetIndex:=Idx;
  end;

  function TOrdersatz.IsGroup(Index: Integer): Boolean;
  var i: Integer;
  begin
    IsGroup:=Groups.Search(@Index, i);
  end;

  procedure TOrdersatz.GetStr(Index: Integer; P: PChar; Line: PInteger);
  var
    Arg: record
      Line: Integer;
      Name, EVArt, EVInhalt: PChar;
      UVMenge: Integer;
    end;
    Item: POSItem;
    ArtikelEK: PArtikelEKRec;
    Artikel: PArtikelRec;
    acS: array[0..10] of Char;
    S: PChar;
  begin
    if At(Index)=nil then
    begin
      Arg.Line:=GetLineNo(Index);
      wvsprintf(P, #9'%d', Arg);
    end else
    if not IsGroup(Index) then
    begin
      P^:=#0;
      Item:=POSItem(At(Index));
      ArtikelEK:=PArtikelEKRec(EKDB^.GetRecNr(Item^.ArtikelEKNr));
      if ArtikelEK<>nil then
      begin
        Artikel:=PArtikelRec(ArtikelDB^.GetRecNr(ArtikelEK^.ArtikelNr));
        if Artikel<>nil then
        begin
          Arg.Line:=GetLineNo(Index);
          with Artikel^ do
          begin
            Arg.Name:=Name;
            Arg.EVArt:=EVArt;
            Arg.EVInhalt:=EVInhalt;
          end;
          Arg.UVMenge:=ArtikelEK^.UVMenge;
          wvsprintf(P, #9'%d'#9'%s'#9'%s'#9'%s'#9'%d', Arg);
          if Item^.Count>0 then
          begin
            Str(Item^.Count, acS);
            S:=StrEnd(P);
            StrCopy(StrECopy(StrECopy(S, #9), acS), 'x');
          end;
        end;
      end;
      if P^=#0 then
      begin
        Arg.Line:=GetLineNo(Index);
        Arg.Name:=GetResString(str_ArtikelDeleted);
        wvsprintf(P, #9'%d'#9'%s', Arg);
      end;
    end else
    begin
{      if POSGroup(At(Index))^.Name<>nil then}
        StrCopy(P, POSGroup(At(Index))^.Name);
{      else
        P^:=#0;}
    end;
  end;

{== TOrdersatzWin ==}
  constructor TOrdersatzWin.Init(AFileName: PChar; ATitle: PChar; AMode: Word);
  begin
    TWindow.Init(Application^.MainWindow, nil);
    New(GB1,           Init(@Self, -1, 'Einkauf', 0, 0, 0, 0));
    New(GB2,           Init(@Self, -1, 'Ordersatz', 0, 0, 0, 0));
    New(GB3,           Init(@Self, -1, 'Name des Ordersatzes', 0, 0, 0, 0));
    New(CBLieferanten, Init(@Self, id_Lieferanten, 0, 0, 0, 0, cbs_DropDownList, 30));
    New(LBEinkauf,     Init(@Self, id_Einkauf,     0, 0, 0, 0));
    New(LBOrdersatz,   Init(@Self, id_Ordersatz,   0, 0 ,0 ,0));
    New(NameEdit,      Init(@Self, id_NameEdit, nil, 0, 0, 0, 0, 100, False));
    New(B1,            Init(@Self, id_Group, nil, 0, 0, 0, 0, False));
    New(B2,            Init(@Self, id_Insert, nil, 0, 0, 0, 0, False));
    New(B3,            Init(@Self, id_Delete, nil, 0, 0, 0, 0, False));
    New(B4,            Init(@Self, id_Item, nil, 0, 0, 0, 0, False));
    New(B5,            Init(@Self, id_Save,   nil, 0, 0, 0, 0, False));
    GB1^.Attr.Style:=GB1^.Attr.Style or bss_Caption;
    GB2^.Attr.Style:=GB2^.Attr.Style or bss_Caption;
    GB3^.Attr.Style:=GB3^.Attr.Style or bss_Caption;
    LBEinkauf^.Attr.Style:=LBEinkauf^.Attr.Style
      and (not lbs_Sort) or lbs_HasStrings or lbs_UseTabStops or lbs_NoIntegralHeight;
    LBOrdersatz^.Attr.Style:=LBEinkauf^.Attr.Style;
    ActLieferant:=-1;
    ActEKListe:=nil;
    FileName:=StrNew(AFileName);
    WindowTitle:=StrNew(ATitle);
    Mode:=AMode;
    if (AFileName<>nil) and FileExist(AFileName) then
    begin
      New(ActStream, Init(FileName, Mode or of_Share_Deny_Write, 0));
      if ActStream^.Status<>stOk then
      begin
        Dispose(ActStream, Done);
        MessageBeep(0);
        if MessageBox(hWindow, GetResString(str_OSLocked), Title,
          MB_ICONEXCLAMATION or MB_YESNO)<>idYes then Fail;
        New(ActStream, Init(FileName, of_Read or of_Share_Deny_None, 0));
        ActOS:=POrdersatz(ActStream^.Get);
        Dispose(ActStream, Done);
        if ActOS=nil then
        begin
          MessageBeep(0);
          MessageBox(hWindow, GetResString(str_OSLoadError), Title, MB_ICONHAND or MB_OK);
          Fail;
        end;
        ActStream:=nil;
        StrDispose(FileName);
        FileName:=nil;
      end else
      begin
        ActOS:=POrdersatz(ActStream^.Get);
        if ActOS=nil then
        begin
          Dispose(ActStream, Done);
          MessageBeep(0);
          MessageBox(hWindow, GetResString(str_OSLoadError), Title, MB_ICONHAND or MB_OK);
          Fail;
        end;
      end;
    end else
    begin
      New(ActOS, Init);
      ActStream:=nil;
      if FileName<>nil then SaveOrdersatz(False);
    end;
    ActSorting:=UserSettings.DefaultArtikelEKSort;
    DisplayMode:=GetPrivateProfileInt(pf_User, 'OSSplitting', 0, ProfileFile);
  end;

  destructor TOrdersatzWin.Done;
  begin
    if ActStream<>nil then Dispose(ActStream, Done);
    if ActOS<>nil then Dispose(ActOS, Done);
    if ActEKListe<>nil then Dispose(ActEKListe, Done);
    StrDispose(FileName);
    StrDispose(WindowTitle);
    LieferantenNr.DeleteAll;
    LieferantenNr.Done;
    DeleteObject(Font);
    TWindow.Done;
  end;

  procedure TOrdersatzWin.SetupWindow;
  var
    i: Integer;
    L: PLieferRec;
    Title: array[0..30] of Char;
  begin
    TWindow.SetupWindow;
    Font:=CreateFont(8, 0, 0, 0, fw_Bold, 0, 0, 0, Ansi_CharSet, Out_Default_Precis,
      Clip_Default_Precis, Default_Quality, Default_Pitch or ff_DontCare, 'MS Sans Serif');
    SendMessage(LBEinkauf^.hWindow, wm_SetFont, Font, 0);
    SendMessage(LBOrdersatz^.hWindow, wm_SetFont, Font, 0);
    SendMessage(CBLieferanten^.hWindow, wm_SetFont, Font, 0);
    SendMessage(LBEinkauf^.hWindow, lb_SetTabStops, SizeOf(TabsArtikel) Div 2, LongInt(@TabsArtikel));
    SendMessage(LBOrdersatz^.hWindow, lb_SetTabStops, SizeOf(TabsOS) Div 2, LongInt(@TabsOS));
    LieferDB^.Register(hWindow, 1);
    LieferantenNr.Init(10, 10);
    for i:=0 to LieferDB^.NumRecs(hWindow)-1 do
    begin
      L:=PLieferRec(LieferDB^.GetRec(hWindow, i));
      CBLieferanten^.AddString(L^.Name);
      LieferantenNr.Insert(Pointer(L^.Nr));
    end;
    CBLieferanten^.SetSelIndex(-1);
    LieferDB^.Unregister(hWindow);
    if WindowTitle=nil then
    begin
      if FileName<>nil then
      begin
        GetFileTitle(FileName, Title, SizeOf(Title));
        SetWindowText(hWindow, StrCat(GetResString(str_Ordersatzeditor), Title));
      end else
        SetWindowText(hWindow, StrCat(GetResString(str_Ordersatzeditor), 'Neu'));
    end else
    begin
      SetWindowText(hWindow, WindowTitle);
      ShowWindow(NameEdit^.hWindow, sw_Hide);
      ShowWindow(GB3^.hWindow, sw_Hide);
      ShowWindow(B1^.hWindow, sw_Hide);
    end;
    if ActOS^.Name<>nil then
      SetWindowText(NameEdit^.hWindow, ActOS^.Name);
    ActOS^.Changed:=False;
    UpdateOrdersatz;
  end;

  function TOrdersatzWin.CanClose: Boolean;
  var Cmd: Word;
  begin
    CanClose:=TWindow.CanClose;
    if ActOS^.Changed then
    begin
      Cmd:=MessageBox(hWindow, 'Ordersatz wurde verändert. Soll er jetzt gespeichert'+
        ' werden ?', Title, MB_ICONQUESTION or MB_YESNOCANCEL);
      if Cmd=idYes then CanClose:=SaveOrdersatz(False) else
        if Cmd=idCancel then CanClose:=False;
    end;
  end;

  function TOrdersatzWin.GetClassName: PChar;
  begin
    GetClassName:='WAWIS:Ordersatz';
  end;

  procedure TOrdersatzWin.GetWindowClass(var AWndClass: TWndClass);
  begin
    TWindow.GetWindowClass(AWndClass);
    with AWndClass do
    begin
      hIcon:=LoadIcon(hInstance, MakeIntResource(OrdersatzIcon));
      hbrBackground:=GetStockObject(LtGray_Brush);
    end;
  end;

  procedure TOrdersatzWin.WMSize;
  var S, H, W: Word;
  begin
    H:=(Msg.lParamHi-65);
    if DisplayMode=0 then
    begin
      W:=(Msg.lParamLo-20) div 2;
      MoveWindow(GB1^.hWindow,           5,     0, W,    H,    False);
      MoveWindow(GB2^.hWindow,           W+15,  0, W,    H,    False);
      MoveWindow(CBLieferanten^.hWindow, 10,   25, W-10, 160,  False);
      MoveWindow(LBEinkauf^.hWindow,     10,   50, W-10, H-55, False);
      MoveWindow(LBOrdersatz^.hWindow,   W+20, 25, W-10, H-30, False);
    end else
    begin
      W:=H Div 2;      
      MoveWindow(GB1^.hWindow,           5,     0, Msg.lParamLo-10,  W-5, False); 
      MoveWindow(GB2^.hWindow,           5,     W, Msg.lParamLo-10,  W, False); 
      MoveWindow(CBLieferanten^.hWindow, 10,   25, Msg.lParamLo-20, 160, False);
      MoveWindow(LBEinkauf^.hWindow,     10,   47, Msg.lParamLo-20, W-57, False);
      MoveWindow(LBOrdersatz^.hWindow,   10, W+25, Msg.lParamLo-20, W-30, False);
    end;
    MoveWindow(GB3^.hWindow,      5, H+3, Msg.lParamLo-400, 55, False);
    MoveWindow(NameEdit^.hWindow, 10, H+27, Msg.lParamLo-410, 24, False);
    S:=Msg.lParamLo-380;
    MoveWindow(B1^.hWindow, S,     H+13, 63, 39, False);
    MoveWindow(B2^.hWindow, S+75,  H+13, 63, 39, False);
    MoveWindow(B3^.hWindow, S+150, H+13, 63, 39, False);
    MoveWindow(B4^.hWindow, S+225, H+13, 63, 39, False);
    MoveWindow(B5^.hWindow, S+300, H+13, 63, 39, False);
    TWindow.WMSize(Msg);
  end;

  procedure TOrdersatzWin.WMInitMenu;
  begin
    if Bool(Msg.wParam) then
    begin
      EnableMenuItem(hMainMenu, IDM_OSSAVE, MF_ENABLED);
      EnableMenuItem(hMainMenu, IDM_OSSAVEAS, MF_ENABLED);
    end else
    begin
      EnableMenuItem(hMainMenu, IDM_OSSAVE, MF_GRAYED);
      EnableMenuItem(hMainMenu, IDM_OSSAVEAS, MF_GRAYED);
    end;
    EnableMenuItem(hMainMenu, idm_Export, MF_ENABLED);
    EnableMenuItem(hMainMenu, idm_OSSaveAs, Byte(WindowTitle<>nil));
  end;

  procedure TOrdersatzWin.WMLocalMenu;
  begin
    GlbLocalMenu:=MakeIntResource(OrdersatzMenu);
    GlbLocalMenuWin:=hWindow;
  end;

  procedure TOrdersatzWin.IDNameEdit;
  begin
    if Msg.lParamHi=en_Update then ActOS^.Changed:=True;
  end;

  procedure TOrdersatzWin.IDLieferanten;
  var
    I: Integer;
    acS: array[0..100] of Char;
  begin
    if Msg.lParamHi=cbn_SelChange then
    begin
      ActLieferant:=LongInt(LieferantenNr.At(CBLieferanten^.GetSelIndex));
      if ActEKListe=nil then 
        New(ActEKListe, Init(hWindow, ActLieferant, ActSorting))
      else
        ActEKListe^.ChangeParams(ActLieferant, ActSorting);  
      LBEinkauf^.ClearList;
      for I:=0 to ActEKListe^.Count-1 do
      begin
        ActEKListe^.GetString(i, acS);
        LBEinkauf^.AddString(acS);
      end;
    end;
  end;

  procedure TOrdersatzWin.IDInsert;
  var
    Count, Index: Integer;
    acS: array[0..10] of Char;
    D: PInputDialog;
  begin
    StrCopy(acS, '1');
    New(D, Init(@Self, 'Leerzeilen einfügen', 'Wie viele Zeilen einfügen ?', acS, SizeOf(acS)));
    if Application^.ExecDialog(D)=idOk then
    begin
      Val(acS, Count, Index);
      if (Index=0) and (Count>0) and (Count<=5000) then
      begin
        Index:=LBOrdersatz^.GetSelIndex;
        if Index<0 then Index:=ActOS^.Count;
        ActOS^.InsertItem(Index, nil, Count);
        UpdateOrdersatz;
      end else
        MessageBeep(0);
    end;
    SetFocus(LBOrdersatz^.hWindow);
  end;

  procedure TOrdersatzWin.IDDelete;
  var Index: Integer;
  begin
    if Msg.lParamHi=bn_DoubleClicked then Exit;
    Index:=LBOrdersatz^.GetSelIndex;
    if (Index>=0) and (Index<ActOS^.Count) then
    begin
      ActOS^.DeleteItem(Index);
      UpdateOrdersatz;
    end else
      MessageBeep(0);
  end;

  procedure TOrdersatzWin.IDItem;
  var
    OSItem: Pointer; 
    ItemIndex, OSIndex: Integer;
    ArtikelEK: PArtikelEKRec;
    acS: array[0..100] of Char;
  begin
    ItemIndex:=LBEinkauf^.GetSelIndex;
    OSIndex:=LBOrdersatz^.GetSelIndex;
    if (ItemIndex>=0) and (OSIndex>=0) and (OSIndex<ActOS^.Count) then
    begin
      OSItem:=ActOS^.At(OSIndex);
      if (OSItem=nil) or (ActOS^.Groups.IndexOf(OSItem)=-1) then
      begin 
        ArtikelEK:=PArtikelEKRec(ActEKListe^.At(ItemIndex));
        if ArtikelEK<>nil then
        with ActOS^, LBOrdersatz^ do
        begin
          AtFree(OSIndex);
          AtInsert(OSIndex, New(POSItem, Init(ArtikelEK^.Nr)));
          GetStr(OSIndex, acS, nil);
          DeleteString(OSIndex);
          InsertString(acS, OSIndex);
          SetSelIndex(OSIndex+1);
          SetFocus(LBEinkauf^.hWindow);
          Changed:=True;
        end else
          MessageBeep(0);
      end else
        MessageBeep(0);
    end else
      MessageBeep(0);
  end;

  procedure TOrdersatzWin.IDGroup;
  var
    Index, Line: Integer;
    D: PInputDialog;
    acS: array[0..100] of Char;
  begin
    Index:=LBOrdersatz^.GetSelIndex;
    if Index<0 then Index:=0;
    acS[0]:=#0;
    New(D, Init(@Self, 'Gruppe einfügen', 'Gruppenname:', acS, 30));
    if Application^.ExecDialog(D)=idOk then
      if acS[0]<>#0 then
      with ActOS^, LBOrdersatz^ do
      begin
        InsertGroup(Index, New(POSGroup, Init(acS)));
        GetStr(Index, acS, nil);
        InsertString(acS, Index);
        SetSelIndex(Index+1);
      end else
        MessageBox(hWindow, 'Bitte Namen angeben !', Title, MB_ICONINFORMATION or MB_OK);
  end;

  procedure TOrdersatzWin.IDSave;
  begin
    SaveOrdersatz(False);
  end;

  function TOrdersatzWin.GetNewFilename: Boolean;
  var
    SaveFN: TOpenFilename;
    Title: array[0..20] of Char;
    FullFilename: array[0..100] of Char;
    OFS: TOfStruct;
  begin
    InitOpenFNBuffer(SaveFN, GetResString(str_OSSaveAs));
    with SaveFN do
    begin
      lpstrFile:=FullFileName;
      nMaxFile:=SizeOf(FullFileName);
      lpstrFileTitle:=Title;
      nMaxFileTitle:=SizeOf(Title);
      FullFilename[0]:=#0;
      if FileName<>nil then StrCopy(FullFilename, FileName);
    end;
    GetNewFilename:=False;
    if GetSaveFileName(SaveFN) then
    begin
      StrDispose(Filename);
      Filename:=StrNew(FullFilename);
      SetWindowText(hWindow, StrCat(GetResString(str_Ordersatzeditor), Title));
      GetNewFilename:=True;
    end;
  end;

  procedure TOrdersatzWin.IDMSave;
  begin
    SaveOrdersatz(False);
  end;

  procedure TOrdersatzWin.IDMSaveAs;
  begin
    SaveOrdersatz(True);
  end;

  procedure TOrdersatzWin.IDMInsert;
  begin
    IDInsert(Msg);
  end;

  procedure TOrdersatzWin.IDMDelete;
  begin
    Msg.lParamHi:=bn_Clicked;
    IDDelete(Msg);
  end;

  procedure TOrdersatzWin.IDMUpdate;
  begin
    IDItem(Msg);
  end;

  procedure TOrdersatzWin.IDMExport;
  const
    CrLf= #13#10;
    Options: TExportOptions= (
      AllData: 1; SelectedData: 0;
      ToClipboard: 1; ToFile: 0; AFileName: #0;
      ToAnsi: 1; ToOem: 0;
      UseTab: 1; UseSpace: 0; UseKomma: 0; UseSonst: 0; AChar: #0); 
  var
    Dlg: PExportDlg;
    Buf: TExportColl;
    Count, i: Integer;
    acS: array[0..100] of Char;
  begin
    New(Dlg, Init);
    Dlg^.TransferBuffer:=@Options;
    if Application^.ExecDialog(Dlg)=id_Ok then
    with LBOrdersatz^ do
    begin
      Count:=GetCount-1;
      if Count=0 then Exit;
      Buf.Init(Count);
      for i:=0 to Count-1 do
      begin
        GetString(acS, i);
        StrCat(acS, CrLf);
        Buf.InsertStr(acS);
      end;
      if Options.ToFile<>0 then
        Buf.SendToFile(Options.AFileName)
      else
      if OpenClipboard(hMainWindow) then
      begin
        EmptyClipboard;
        Buf.SendToClipboard(Options.ToOem<>0);
        CloseClipboard;
      end;
      Buf.Done;
    end;
  end;

  procedure TOrdersatzWin.IDMSorting;
  var Dlg: PSortDlg;
  begin
    New(Dlg, Init(@Self, 'Einkaufslistensortierung', MakeIntResource(ArtikelSortDlg)));
    Dlg^.Keypath:=@ActSorting;
    if Application^.ExecDialog(Dlg)=id_Ok then
    begin
      Msg.lParamHi:=cbn_SelChange;
      IDLieferanten(Msg);
    end;
  end;

  procedure TOrdersatzWin.IDMHorzVert;
  var
    R: TRect;
    acS: array[0..1] of Char;
  begin
    Boolean(DisplayMode):=Not Boolean(DisplayMode);
    acS[0]:=Char(DisplayMode+Ord('0')); acS[1]:=#0;
    WritePrivateProfileString(pf_User, 'OSSplitting', acS, ProfileFile);
    GetWindowRect(hWindow, R);
    SetWindowPos(hWindow, 0, 0, 0, R.Right-R.Left+1, R.Bottom-R.Top, swp_NoZOrder or swp_NoMove or swp_NoRedraw);
    SetWindowPos(hWindow, 0, 0, 0, R.Right-R.Left, R.Bottom-R.Top, swp_NoZOrder or swp_NoMove);
  end;

  procedure TOrdersatzWin.UpdateOrdersatz;
  var
    Sel, Index, Line: Integer;
    acS: array[0..100] of Char;
  begin
    with LBOrdersatz^ do
    begin
      Sel:=GetSelIndex;
      ClearList;
      for Index:=0 to ActOS^.Count-1 do
      begin
        ActOS^.GetStr(Index, acS, @Line);
        AddString(acS);
      end;
      AddString(#0);
      SetSelIndex(Sel);
    end;
  end;

  function TOrdersatzWin.SaveOrdersatz(SaveAs: Boolean): Boolean;
  var
    acS: array[0..100] of Char;
    Ok: Boolean;
  begin
    SaveOrdersatz:=False;
    if SaveAs or (FileName=nil) then
      if not GetNewFilename then Exit;
    if FileName<>nil then
    begin
      GetWindowText(NameEdit^.hWindow, acS, SizeOf(acS));
      StrDispose(ActOS^.Name);
      ActOS^.Name:=StrNew(acS);
      if ActStream<>nil then Dispose(ActStream, Done);
      repeat
        New(ActStream, Init(FileName, of_Create, 0));
        if ActStream^.Status=0 then
        begin 
          ActStream^.Put(ActOS);
          Dispose(ActStream, Done);
          New(ActStream, Init(FileName, of_ReadWrite or of_Share_Deny_Write, 0));
          ActOS^.Changed:=False;
          SaveOrdersatz:=True;
          Exit;
        end else
          Dispose(ActStream, Done);
      until not GetNewFilename;
    end;
  end;

{*********************************************************************************}
{ Aktive Ordersätze                                                               }
{*********************************************************************************}
  type
    PActiveOS= ^TActiveOS;
    TActiveOS= object(TObject)
      Nr: LongInt;
      Name: PChar;
      Time: TTime;
      constructor Init(ANr: LongInt; AName: PChar);
      destructor Done; virtual;
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
    end;

  constructor TActiveOS.Init(ANr: LongInt; AName: PChar);
  begin
    Nr:=ANr;
    Name:=StrNew(AName);
    Time.Init;
  end;

  destructor TActiveOS.Done;
  begin
    Time.Done;
    StrDispose(Name);
  end;

  constructor TActiveOS.Load;
  begin
    S.Read(Nr, SizeOf(Nr));
    Name:=S.StrRead;
    Time.Load(S);
  end;

  procedure TActiveOS.Store;
  begin
    S.Write(Nr, SizeOf(Nr));
    S.StrWrite(Name);
    Time.Store(S);    
  end;

{*********************************************************************************}
  type
    PActiveOSDlg= ^TActiveOSDlg;
    TActiveOSDlg= object(TDialog)
      ActiveOS: PCollection;
      OSLB: PListBox;
      Strm: TShareStream;
      constructor Init;
      procedure SetupWindow; virtual;
      destructor Done; virtual;
      procedure ReadList;
      procedure WriteList;
      procedure DisplayList;
      procedure Neu(var Msg: TMessage); virtual id_First+id_NewOS;
      procedure Delete(var Msg: TMessage); virtual id_First+id_DeleteOS;
      procedure Rename(var Msg: TMessage); virtual id_First+id_RenameOS;
    end;

  constructor TActiveOSDlg.Init;
  var FName: array[0..fsPathName] of Char;
  begin
    StrCopy(FName, OSPathFile(OSAListFile, 0));
    if Debug and (not FileExist(FName)) then
      if MessageBox(hMainWindow, 'Datei '+OSAListFile+' neu anlegen ?', Title, mb_IconQuestion or mb_YesNo)=id_Yes then
      begin
        Strm.Init(FName, of_Create, 0);
        Strm.Done;
      end;
    Strm.Init(FName, of_ReadWrite or of_Share_Deny_Write, 0);
    if Strm.Status<>stOk then
    begin
      Strm.Done;
      MessageBox(hMainWindow, GetResString(str_ActiveOSLocked), Title,
        mb_IconExclamation or mb_Ok);
      Fail;
    end;
    TDialog.Init(Application^.MainWindow, MakeIntResource(AktiveOSDlg));
    New(OSLB, InitResource(@Self, id_AktiveOS));
    ActiveOS:=nil;
    ReadList;
    if ActiveOS=nil then Fail;    
  end;

  procedure TActiveOSDlg.SetupWindow;
  begin
    TDialog.SetupWindow;
    DisplayList;
  end;

  destructor TActiveOSDlg.Done;
  begin
    if ActiveOS<>nil then Dispose(ActiveOS, Done);
    Strm.Done;
    TDialog.Done;
  end;

  procedure TActiveOSDlg.ReadList;
  begin
    if ActiveOS<>nil then Dispose(ActiveOS, Done);
    ActiveOS:=nil;
    if Strm.GetSize>0 then
    begin
      Strm.Seek(0);
      ActiveOS:=PCollection(Strm.Get);
    end else
      New(ActiveOS, Init(10, 10));
  end;

  procedure TActiveOSDlg.WriteList;
  begin
    Strm.Seek(0);
    Strm.Put(ActiveOS);
    Strm.Flush;
  end;

  procedure TActiveOSDlg.DisplayList;
  var
    i: Integer;
    A: PActiveOS;
  begin
    if ActiveOS<>nil then
    begin
      OSLB^.ClearList;
      for i:=0 to ActiveOS^.Count-1 do
      begin
        A:=PActiveOS(ActiveOS^.At(i));        
        if A^.Name<>nil then OSLB^.AddString(A^.Name);
      end;
    end;
  end;

  procedure TActiveOSDlg.Neu;
  var
    OpenFN: TOpenFileName;
    FName: array[0..fsPathName] of Char;
    NewNr: LongInt;
    OS: POrdersatz;
    S: TShareStream;
    P: PChar;

    procedure SearchMax(P: PActiveOS); far;
    begin
      if P^.Nr>NewNr then NewNr:=P^.Nr;
    end;

  begin
    InitOpenFNBuffer(OpenFN, 'Ordersatz auswählen...');
    OpenFN.nFilterIndex:=0;
    OpenFN.lpstrFile:=@FName;
    OpenFN.nMaxFile:=SizeOf(FName);
    OpenFN.hwndOwner:=hWindow;
    FName[0]:=#0;
    if GetOpenFileName(OpenFN) then
    begin
      S.Init(FName, of_Read or of_Share_Deny_None, 0);
      if S.Status=stOk then
      begin
        OS:=POrdersatz(S.Get);
        if OS<>nil then
        begin
          S.Done;
          NewNr:=0;
          ActiveOS^.ForEach(@SearchMax);
          Inc(NewNr);
          P:=OS^.Name;
          if P=nil then P:=StrRScan(FName, '\')+1;
          ActiveOS^.Insert(New(PActiveOS, Init(NewNr, P)));
          WriteList;
          DisplayList;
          S.Init(OSPathFile(OSAFile, NewNr), of_Create, 0);
          if Strm.Status<>0 then MessageBeep(0);
          S.Put(OS);
          Dispose(OS, Done);
        end;
      end;
      S.Done;
      if ActiveOS=nil then Cancel(Msg);
    end;
  end;

  procedure TActiveOSDlg.Delete;
  var
    S: TShareStream;
    A: PActiveOS;
  begin
    if OSLB^.GetSelIndex>=0 then
    begin
      if MessageBox(hWindow, 'Wollen Sie den Ordersatz wirklich löschen ?',
        Title, mb_IconQuestion or mb_YesNo or mb_DefButton2)=id_Yes then
      begin
        A:=PActiveOS(ActiveOS^.At(OSLB^.GetSelIndex));
        S.Init(OSPathFile(OSAFile, A^.Nr), of_Delete, 0);
        if S.Status=0 then
        begin
          ActiveOS^.AtFree(OSLB^.GetSelIndex);
          WriteList;
          DisplayList;
        end else
          MessageBeep(0);
      end;        
    end else
      MessageBeep(0);
  end;

  procedure TActiveOSDlg.Rename;
  var
    acS: array[0..100] of Char;
    A: PActiveOS;
  begin
    if OSLB^.GetSelIndex>=0 then
    begin
      A:=PActiveOS(ActiveOS^.At(OSLB^.GetSelIndex));      
      StrLCopy(acS, A^.Name, SizeOf(acS));
      if Application^.ExecDialog(New(PInputDialog,
        Init(@Self, 'Ordersatz benennen', '&Name des Ordersatzes',
        acS, SizeOf(acS))))=id_Ok then
      begin
        StrDispose(A^.Name);
        A^.Name:=StrNew(acS);
        WriteList;
        DisplayList;
      end;               
    end else
      MessageBeep(0);
  end;

  procedure ActiveOSList;
  var Dlg: PActiveOSDlg;
  begin
    New(Dlg, Init);
    if Dlg<>nil then
      Application^.ExecDialog(Dlg);
  end;

{*********************************************************************************}
{ SelectOrdersatz                                                                 }
{*********************************************************************************}
  type
    PSelectOSDlg= ^TSelectOSDlg;
    TSelectOSDlg= object(TDialog)
      ActiveOS: PCollection;
      L: PListBox;
      Data: ^LongInt;
      OnlyOne: LongInt;
      NrColl: TCollection;
      constructor Init;
      procedure SetupWindow; virtual;
      procedure OK(var Msg: TMessage); virtual id_First+id_Ok;
      procedure WMDestroy(var Msg: TMessage); virtual wm_First+wm_Destroy;
      procedure Listbox(var Msg: TMessage); virtual id_First+id_ListBox;
    end;

  constructor TSelectOSDlg.Init;
  var S: TShareStream;
  begin
    S.Init(OSPathFile(OSAListFile, 0), of_Read or of_Share_Deny_None, 0);
    ActiveOS:=PCollection(S.Get);
    S.Done;
    if (ActiveOS=nil) or (ActiveOS^.Count=0) then
    begin
      MessageBox(hMainWindow, 'Keine aktiven Ordersätze vorhanden!', Title,
        mb_IconExclamation or mb_Ok);
      Fail;
    end;
    if ActiveOS^.Count=1 then
      OnlyOne:=PActiveOS(ActiveOS^.At(0))^.Nr
    else
      OnlyOne:=-1;
    TDialog.Init(Application^.MainWindow, MakeIntResource(SelectDlg));
    New(L, InitResource(@Self, id_ListBox));
  end;

  procedure TSelectOSDlg.SetupWindow;
  var
    A: PActiveOS;
    E: PBufferElement;
    I: Integer;
    P: PLieferRec;
  begin
    TDialog.SetupWindow;
    SetWindowText(hWindow, 'Ordersatz auswählen');
    SetWindowText(GetItemHandle(id_ListBoxText), 'Aktive &Ordersätze');
    NrColl.Init(10, 10);
    for i:=0 to ActiveOS^.Count-1 do
    begin
      A:=PActiveOS(ActiveOS^.At(i));
      if A^.Name<>nil then
      begin
        L^.AddString(A^.Name);
        NrColl.Insert(Pointer(A^.Nr));
      end;
    end;
    Dispose(ActiveOS, Done);
  end;

  procedure TSelectOSDlg.Ok(var Msg: TMessage);
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

  procedure TSelectOSDlg.WMDestroy;
  begin
    NrColl.DeleteAll;
    NrColl.Done;
    TDialog.WMDestroy(Msg);
  end;

  procedure TSelectOSDlg.ListBox;
  begin
    if Msg.lParamHi=lbn_DblClk then Ok(Msg);
  end;

  function SelectOrdersatz: LongInt;
  var
    P: PSelectOSDlg;
    L: LongInt;
  begin
    SelectOrdersatz:=-1;
    New(P, Init);
    if P<>nil then
    begin
      if P^.OnlyOne=-1 then
      begin
        P^.Data:=@L;
        if Application^.ExecDialog(P)<>ID_CANCEL then SelectOrdersatz:=L;
      end else
      begin
        SelectOrdersatz:=P^.OnlyOne;
        Dispose(P, Done);
      end;
    end;
  end;

{*********************************************************************************}

  procedure InitOpenFNBuffer(var OpenFN: TOpenFileName; Title: PChar);
  const
    DefExt= 'os';
    Filter: array[0..100] of Char= '';
  var
    P: PChar;
  begin
    FillChar(Filter, SizeOf(Filter), #0);
    P:=Filter;
    P:=StrECopy(P, 'Ordersätze (*.os)')+1;
    P:=StrECopy(P, '*.os')+1;
    if Debug then
    begin
      P:=StrECopy(P, 'Aktive Ordersätze (*.osa)')+1;
      P:=StrECopy(P, '*.osa')+1;
      P:=StrECopy(P, 'Extra Ordersätze (*.osx)')+1;
      StrCopy(P, '*.osx');
    end;
    FillChar(OpenFN, SizeOf(TOpenFileName), #0);
    with OpenFN do
    begin
      hInstance     := hInstance;
      hwndOwner     := hMainWindow;
      lpstrTitle    := Title;
      lpstrDefExt   := DefExt;
      lpstrFilter   := Filter;
      lpstrInitialDir:= OSPath;
      flags         :=
        ofn_FileMustExist or ofn_HideReadOnly or ofn_OverWritePrompt or ofn_ShareAware;
      lStructSize   := sizeof(TOpenFileName);
      nFilterIndex  := 1;       
    end;
  end;

  function LoadOrdersatz(OSNr, BetriebeExtras: LongInt): POrdersatz;
  var
    S: TShareStream;
    P, E: POrdersatz;
    FName: array[0..100] of Char;
    i: Integer;
    Item: POSItem;
  begin
    LoadOrdersatz:=nil;
    P:=nil; E:=nil;
    if OSNr<>-1 then
    begin
      StrCopy(FName, OSPathFile(OSAFile, OSNr));
      S.Init(FName, of_Read or of_Share_Deny_Write, 0);
      if S.Status=stOk then P:=POrdersatz(S.Get);
      S.Done;
    end;
    if BetriebeExtras<>-1 then
    begin
      StrCopy(FName, OSPathFile(OSXFile, BetriebeExtras));
      if FileExist(FName) then
      begin
        S.Init(FName, of_Read or of_Share_Deny_Write, 0);
        if S.Status<>stOk then
        begin
          MessageBeep(0);
          if MessageBox(hMainWindow, GetResString(str_ExtrasLocked), Title,
            mb_IconQuestion or mb_YesNo)=id_No then
          begin
            if P<>nil then Dispose(P, Done);
            P:=nil;
          end;
        end else
          E:=POrdersatz(S.Get);
        S.Done;
      end;
    end;
    if (P<>nil) and (E<>nil) and (E^.Count>0) then
    begin
      P^.HasExtras:=True;
      P^.InsertGroup(P^.Count, New(POSGroup, Init('Extras')));
      for i:=0 to E^.Count-1 do
      begin
        Item:=POSItem(E^.At(i));
        if (Item<>nil) and (TypeOf(Item^)=TypeOf(TOSGroup)) then
          P^.InsertGroup(P^.Count, POSGroup(Item))
        else
          P^.InsertItem(P^.Count, Item, 1);
      end; 
    end else
    if P=nil then P:=E;
    LoadOrdersatz:=P;
  end;

  function AddExtra(BetriebeExtras: LongInt): Boolean;
  var
    ArtikelEKNr: LongInt;
    OS: POrdersatz;
    FName: array[0..100] of Char;
    S: TShareStream;
  begin
    AddExtra:=False;
    StrCopy(FName, OSPathFile(OSXFile, BetriebeExtras));
    if not FileExist(FName) then
    begin
      S.Init(FName, of_Create, 0);
      S.Done;
    end;
    S.Init(FName, of_ReadWrite or of_Share_Exclusive, 0);
    if S.Status=stOk then
    begin
      if S.GetSize>0 then
        OS:=POrdersatz(S.Get)
      else
        New(OS, Init);
      if OS<>nil then
      begin
        ArtikelEKNr:=SelectEKArtikel;
        if ArtikelEKNr>=0 then
        begin
          OS^.InsertItem(OS^.Count, New(POSItem, Init(ArtikelEKNr)), 1);
          S.Seek(0);
          S.Put(OS);
          AddExtra:=S.Status=stOk;
        end;
        Dispose(OS, Done);
      end;
      S.Done;
    end else
      MessageBox(hMainWindow, 'Extras werden gerade im Netz bearbeitet.', Title,
        mb_IconExclamation or mb_Ok);
  end;

  const
    ROSItem: TStreamRec= (
      ObjType: 1500;
      VmtLink: Ofs(TypeOf(TOSItem)^);
      Load: @TOSItem.Load;
      Store: @TOSItem.Store);
    ROSGroup: TStreamRec= (
      ObjType: 1501;
      VmtLink: Ofs(TypeOf(TOSGroup)^);
      Load: @TOSGroup.Load;
      Store: @TOSGroup.Store);
    RGroups: TStreamRec= (
      ObjType: 1502;
      VmtLink: Ofs(TypeOf(TGroups)^);
      Load: @TGroups.Load;
      Store: @TGroups.Store);
    ROrdersatz: TStreamRec= (
      ObjType: 1503;
      VmtLink: Ofs(TypeOf(TOrdersatz)^);
      Load: @TOrdersatz.Load;
      Store: @TOrdersatz.Store);
    RActiveOS: TStreamRec= (
      ObjType: 1504;
      VmtLink: Ofs(TypeOf(TActiveOS)^);
      Load: @TActiveOS.Load;
      Store: @TActiveOS.Store);

  procedure RegisterOrdersatz;
  begin
    RegisterType(RCollection); 
    RegisterType(ROSItem);
    RegisterType(ROSGroup);
    RegisterType(RGroups);
    RegisterType(ROrdersatz);
    RegisterType(RActiveOS);
  end;

end.