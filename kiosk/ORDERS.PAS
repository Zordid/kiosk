{$I KIOSKCO.PAS}
{$O+,F+}
Unit Orders;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, Fields, MsgBox, App,
    Crt, Printer, StrObj, StrUtl, DataFile, DateUtl,
    KioskCmds, Artikel, Kunden, Lieferanten,
    Ordersatz, OSViews, OSActive, Drucker;

  Type
    POrderItem= ^TOrderItem;
    TOrderItem= Record
      No: Integer;
      Artikel: LongInt;
      Liefer: Word;
      Quantity: Word;
      Remark: TStr;
    End;

    POrder= ^TOrder;
    TOrder= Object(TSortedCollection)
      Date: TDate;
      Time: TTime;
      Kunde: TKundenRec;
      OSFile: PString;
      OrderFile: PString;
      Total, TotalQuantity: Word;
      Modified: Boolean;
      Constructor Init(K: TKundenRec; O: String);
      Procedure PutItem(Var S: TStream; Item: Pointer); virtual;
      Function GetItem(Var S: TStream): Pointer; virtual;
      Procedure FreeItem(Item: Pointer); virtual;
      Function KeyOf(Item: Pointer): Pointer; virtual;
      Function Compare(Key1, Key2: Pointer): Integer; virtual;
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Procedure OrderNo(No: Integer; Art: LongInt; L: Word; Quant: Word; Rem: String);
      Procedure ZeroOut(No: Integer);
    End;

    PSpezItem= ^TSpezItem;
    TSpezItem= Record
      Item: Integer;
      DataRef: LongInt;
    End;

    PSpezPos= ^TSpezPos;
    TSpezPos= Object(TSortedCollection)
      Modified: Boolean;
      Constructor Init;
      Constructor Load(Var S: TStream);
      Procedure PutItem(Var S: TStream; Item: Pointer); virtual;
      Function GetItem(Var S: TStream): Pointer; virtual;
      Procedure FreeItem(Item: Pointer); virtual;
      Function KeyOf(Item: Pointer): Pointer; virtual;
      Function Compare(Key1, Key2: Pointer): Integer; virtual;
      Procedure Belegen(Item: Integer; DataRef: LongInt);
      Procedure Loeschen(Item: Integer);
    End;

    POrderScroller= ^TOrderScroller;
    TOrderScroller= Object(TOSScroller)
      Order: POrder;
      Spez: PSpezPos;
      TxtScrollbar: PScrollbar;
      SpezFlag: Boolean;
      Constructor Init(Var Bounds: TRect; SB, TSB: PScrollbar; AnOS: POrdersatz; AnOrder: POrder; AnSpez: PSpezPos);
      Procedure FocusItem(Item: Integer); virtual;
      Function GetDataRef(Item: Integer): LongInt; virtual;
      Function GetText(Item, MaxLen: Integer): String; virtual;
      Procedure HandleEvent(Var Event: TEvent); virtual;
    End;

    POrderEditor= ^TOrderEditor;
    TOrderEditor= Object(TWindow)
      Order: POrder;
      OS: POrdersatz;
      Spez: PSpezPos;
      Viewer: POrderScroller;
      Constructor Init(AnOrder: POrder);
      Procedure SetState(AState: Word; Enable: Boolean); virtual;
      Procedure HandleEvent(Var Event: TEvent); virtual;
      Function Valid(Command: Word): Boolean; virtual;
      Destructor Done; virtual;
    End;

  Const
    ROrder: TStreamRec= (
      ObjType: 2011;
      VmtLink: Ofs(TypeOf(TOrder)^);
      Load: @TOrder.Load;
      Store: @TOrder.Store
    );
    RSpezPos: TStreamRec= (
      ObjType: 2012;
      VmtLink: Ofs(TypeOf(TSpezPos)^);
      Load: @TSpezPos.Load;
      Store: @TSpezPos.Store
    );

  Procedure Bestellung_Annehmen;
  Procedure PrintOrder(O: POrder);

Implementation
  Uses
    CurrOrd;

{== TSpezPos ===============================================================}

  Constructor TSpezPos.Init;
  Begin
    TSortedCollection.Init(1, 5);
    Modified:=True;
  End;

  Constructor TSpezPos.Load(Var S: TStream);
  Begin
    TSortedCollection.Load(S);
    Modified:=False;
  End;

  Procedure TSpezPos.PutItem(Var S: TStream; Item: Pointer);
  Begin
    S.Write(Item^, SizeOf(TSpezItem));
  End;

  Function TSpezPos.GetItem(Var S: TStream): Pointer;
  Var P: PSpezItem;
  Begin
    New(P);
    S.Read(P^, SizeOf(TSpezItem));
    GetItem:=Pointer(P);
  End;

  Procedure TSpezPos.FreeItem(Item: Pointer);
  Begin
    FreeMem(Item, SizeOf(TSpezItem));
  End;

  Function TSpezPos.KeyOf(Item: Pointer): Pointer;
  Begin
    KeyOf:=@PSpezItem(Item)^.Item;
  End;

  Function TSpezPos.Compare(Key1, Key2: Pointer): Integer;
  Begin
    If Integer(Key1^)<Integer(Key2^) Then Compare:=-1 Else
      If Integer(Key1^)>Integer(Key2^) Then Compare:=+1 Else
        Compare:=0;
  End;

  Procedure TSpezPos.Belegen(Item: Integer; DataRef: LongInt);
  Var
    I: Integer;
    S: PSpezItem;
  Begin
    If Search(@Item, I) Then
    Begin
      PSpezItem(At(I))^.DataRef:=DataRef;
    End Else
    Begin
      New(S);
      S^.Item:=Item;
      S^.DataRef:=DataRef;
      Insert(S);
    End;
    Modified:=True;
  End;

  Procedure TSpezPos.Loeschen(Item: Integer);
  Var I: Integer;
  Begin
    If Search(@Item, I) Then
    Begin
      AtFree(I);
      Modified:=True;
    End;
  End;

{== TOrder =================================================================}

  Constructor TOrder.Init(K: TKundenRec; O: String);
  Begin
    TSortedCollection.Init(5, 5);
    Date.InitToday;
    Time.InitNow;
    Kunde:=K;
    OSFile:=NewStr(O);
    Modified:=True;
  End;

  Procedure TOrder.PutItem(Var S: TStream; Item: Pointer);
  Begin
    S.Write(Item^, SizeOf(TOrderItem)-SizeOf(PString));
    POrderItem(Item)^.Remark.Store(S);
  End;

  Function TOrder.GetItem(Var S: TStream): Pointer;
  Var P: POrderItem;
  Begin
    New(P);
    S.Read(P^, SizeOf(TOrderItem)-SizeOf(PString));
    P^.Remark.Load(S);
    GetItem:=Pointer(P);
  End;

  Procedure TOrder.FreeItem(Item: Pointer);
  Begin
    POrderItem(Item)^.Remark.Done;
    FreeMem(Item, SizeOf(TOrderItem));
  End;

  Function TOrder.KeyOf(Item: Pointer): Pointer;
  Begin
    KeyOf:=@POrderItem(Item)^.No;
  End;

  Function TOrder.Compare(Key1, Key2: Pointer): Integer;
  Begin
    If Integer(Key1^)<Integer(Key2^) Then Compare:=-1 Else
      If Integer(Key1^)>Integer(Key2^) Then Compare:=+1 Else
        Compare:=0;
  End;

  Constructor TOrder.Load(Var S: TStream);
  Begin
    TSortedCollection.Load(S);
    Date.Load(S);
    Time.Load(S);
    S.Read(Kunde, SizeOf(Kunde));
    OSFile:=S.ReadStr;
    OrderFile:=S.ReadStr;
    S.Read(Total, 2*SizeOf(Word));
    Modified:=False;
  End;

  Procedure TOrder.Store(Var S: TStream);
  Begin
    TSortedCollection.Store(S);
    Date.Store(S);
    Time.Store(S);
    S.Write(Kunde, SizeOf(Kunde));
    S.WriteStr(OSFile);
    S.WriteStr(OrderFile);
    S.Write(Total, 2*SizeOf(Word));
  End;

  Procedure TOrder.OrderNo(No: Integer; Art: LongInt; L: Word; Quant: Word; Rem: String);
  Var
    I: Integer;
    P: POrderItem;
  Begin
    If Search(@No, I) Then With POrderItem(At(I))^ Do
    Begin
      Inc(TotalQuantity, Quant-Quantity);
      Quantity:=Quant;
      Remark.SetStr(Rem);
    End Else
    Begin
      Inc(Total);
      Inc(TotalQuantity, Quant);
      New(P);
      P^.No:=No;
      P^.Artikel:=Art;
      P^.Liefer:=L;
      P^.Quantity:=Quant;
      P^.Remark.Init(Rem);
      Insert(P);
    End;
    Modified:=True;
  End;

  Procedure TOrder.ZeroOut(No: Integer);
  Var I: Integer;
  Begin
    If Search(@No, I) Then
    Begin
      Dec(Total);
      Dec(TotalQuantity, POrderItem(At(I))^.Quantity);
      AtFree(I);
      Modified:=True;
    End;
  End;

{== TOrderScroller =========================================================}

  Constructor TOrderScroller.Init(Var Bounds: TRect; SB, TSB: PScrollbar; AnOS: POrdersatz;
    AnOrder: POrder; AnSpez: PSpezPos);
  Begin
    TOSScroller.Init(Bounds, SB, AnOS);
    Order:=AnOrder;
    Spez:=AnSpez;
    TxtScrollbar:=TSB;
    TxtScrollbar^.SetParams(0, 0, 0, 20, 1);
    FocusItem(1);
  End;

  Procedure TOrderScroller.FocusItem(Item: Integer);
  Var I: Integer;
  Begin
    TOSScroller.FocusItem(Item);
    If (Order^.Search(@Item, I)) And (POrderItem(Order^.At(I))^.Remark.P<>nil) Then
      TxtScrollBar^.SetRange(1, Length(POrderItem(Order^.At(I))^.Remark.GetStr))
    Else
      TxtScrollBar^.SetRange(0, 0);
  End;

  Function TOrderScroller.GetDataRef(Item: Integer): LongInt;
  Var
    I, J: Integer;
  Begin
    SpezFlag:=Spez^.Search(@Item, I);
    If Not Order^.Search(@Item, J) Then
    Begin
      If SpezFlag Then
        GetDataRef:=PSpezItem(Spez^.At(I))^.DataRef
      Else
        GetDataRef:=TOSScroller.GetDataRef(Item);
    End Else
      GetDataRef:=POrderItem(Order^.At(J))^.Artikel;
  End;

  Function TOrderScroller.GetText(Item, MaxLen: Integer): String;
  Var
    S: String;
    T: String[5];
    I, P: Integer;
  Begin
    S:=TOSScroller.GetText(Item, MaxLen);
    If Order^.Search(@Item, I) Then
    Begin
      FillChar(S[Length(S)+1], (50)-Length(S), #32);
      S[0]:=Chr(50);
      Str(POrderItem(Order^.At(I))^.Quantity:3, T);
      StrCat(S, T, 255);
      ChrCat(S, 'x');
      If POrderItem(Order^.At(I))^.Remark.P<>nil Then
      Begin
        StrCat(S, '   ', 255);
        If Focused=Item Then P:=TxtScrollbar^.Value Else P:=1;
        StrCat(S, Copy(POrderItem(Order^.At(I))^.Remark.GetStr, P, 20), 255)
      End;
    End;
    If SpezFlag Then S[1]:='K';
    GetText:=S;
  End;

  Procedure TOrderScroller.HandleEvent(Var Event: TEvent);
  Begin
    If (Event.What=evBroadcast) And (Event.Command=cmScrollBarChanged) And
      (Event.InfoPtr=Pointer(TxtScrollBar)) Then
    Begin
      Draw;
      ClearEvent(Event);
    End;
    TOSScroller.HandleEvent(Event);
  End;

{== TKundenDisplay =========================================================}

  Type
    PKundenDisplay= ^TKundenDisplay;
    TKundenDisplay= Object(TView)
      Order: POrder;
      Constructor Init(AnOrder: POrder);
      Procedure Draw; virtual;
      Function GetPalette: PPalette; virtual;
    End;

  Const
    CDisplay= #6#7;

  Constructor TKundenDisplay.Init(AnOrder: POrder);
  Var R: TRect;
  Begin
    R.Assign(2, 1, 50, 5);
    TView.Init(R);
    Options:=Options+ofFramed;
    Order:=AnOrder;
  End;

  Procedure TKundenDisplay.Draw;
  Var
    B: TDrawBuffer;
    C: Word;
  Begin
    C:=GetColor(1);
    With Order^ Do
    Begin
      MoveChar(B, ' ', C, Size.X);
      MoveStr(B[1], 'Datum: '+Date.GetStrDate+'    Uhrzeit: '+
        Time.GetStrTime('.', tHour+tMinute), C);
      WriteLine(0, 0, Size.X, 1, B);
      MoveChar(B, ' ', C, Size.X);
      MoveStr(B[1], Kunde.Name+', '+Kunde.Vorname, C);
      WriteLine(0, 1, Size.X, 1, B);
      MoveChar(B, ' ', C, Size.X);
      MoveStr(B[1], Kunde.Strasse, C);
      WriteLine(0, 2, Size.X, 1, B);
      MoveChar(B, ' ', C, Size.X);
      MoveStr(B[1], Kunde.Ort, C);
      WriteLine(0, 3, Size.X, 1, B);
    End;
  End;

  Function TKundenDisplay.GetPalette: PPalette;
  Const P: String[Length(CDisplay)]= CDisplay;
  Begin
    GetPalette:=@P;
  End;

{== TMengenDisplay =========================================================}

  Type
    PMengenDisplay= ^TMengenDisplay;
    TMengenDisplay= Object(TView)
      Order: POrder;
      Constructor Init(AnOrder: POrder);
      Procedure Draw; virtual;
      Function GetPalette: PPalette; virtual;
    End;

  Constructor TMengenDisplay.Init(AnOrder: POrder);
  Var R: TRect;
  Begin
    R.Assign(51, 1, 78, 5);
    TView.Init(R);
    Options:=Options+ofFramed;
    Order:=AnOrder;
  End;

  Procedure TMengenDisplay.Draw;
  Var
    B: TDrawBuffer;
    C: Word;
    T, TQ: String[5];
  Begin
    Str(Order^.Total:5, T);
    Str(Order^.TotalQuantity:5, TQ);
    C:=GetColor(1);
    MoveChar(B, ' ', C, Size.X);
    WriteLine(0, 0, Size.X, 1, B);
    WriteLine(0, 3, Size.X, 1, B);
    MoveStr(B[1], 'Bestellte Artikel: '+T, C);
    WriteLine(0, 1, Size.X, 1, B);
    MoveChar(B, ' ', C, Size.X);
    MoveStr(B[9], 'insgesamt: '+TQ, C);
    WriteLine(0, 2, Size.X, 1, B);
  End;

  Function TMengenDisplay.GetPalette: PPalette;
  Const P: String[Length(CDisplay)]= CDisplay;
  Begin
    GetPalette:=@P;
  End;


{== TOrderEditor ===========================================================}

  Constructor TOrderEditor.Init(AnOrder: POrder);
  Var
    R: TRect;
    Strm: PBufStream;
    HScrollbar, VScrollbar: PScrollbar;
    Idx: TResourceFile;
  Begin
    R.Assign(0, 0, 80, 23);
    TWindow.Init(R, 'Bestellung', 0);
    Flags:=Flags - wfGrow - wfZoom;
    HelpCtx:=hcBestellung;
    Order:=AnOrder;
    Strm:=New(PBufStream, Init(Order^.OSFile^, stOpen, 1024));
    If Strm^.Status=stOk Then
    Begin
      Idx.Init(Strm);
      OS:=POrdersatz(Idx.Get('OS'));
      With Order^.Kunde Do Spez:=PSpezPos(Idx.Get('.'+Name+#0+Vorname));
      Idx.Done;
      If OS<>nil Then
      Begin
        If Spez=nil Then New(Spez, Init);
        { Horizontaler Scrollbalken }
        GetExtent(R);
        Dec(R.B.X, 2);
        R.A.X:=R.B.X-20;
        R.A.Y:=R.B.Y-1;
        HScrollbar:=New(PScrollBar, Init(R));
        HScrollbar^.Options:=HScrollbar^.Options+ofPreProcess;
        Insert(HScrollbar);
        { Vertikaler Scrollbalken }
        GetExtent(R);
        R.A.X:=R.B.X-1;
        Dec(R.B.Y, 1);
        Inc(R.A.Y, 6);
        VScrollbar:=New(PScrollbar, Init(R));
        Insert(VScrollbar);
        { Scroller }
        GetExtent(R);
        R.Grow(-1, -1);
        Inc(R.A.Y, 5);
        Viewer:=New(POrderScroller, Init(R, VScrollbar, HScrollbar, OS, Order, Spez));
        Insert(Viewer);
        Insert(New(PKundenDisplay, Init(Order)));
        Insert(New(PMengenDisplay, Init(Order)));
      End Else
      Begin
        MessageBox('Ordersatzdatei %s ist nicht lesbar.', @Order^.OSFile, mfError+mfOkButton);
        Fail;
      End;
    End Else
    Begin
      Dispose(Strm, Done);
      MessageBox('Ordersatzdatei %s existiert nicht.', @Order^.OSFile, mfError+mfOkButton);
      Fail;
    End;
  End;

  Procedure TOrderEditor.SetState(AState: Word; Enable: Boolean);
  Begin
    TWindow.SetState(AState, Enable);
    If AState=sfSelected Then
    Case Enable Of
      True: EnableCommands(OrderCmds);
      False: DisableCommands(OrderCmds);
    End;
  End;

  Type
    PIntInputLine= PNumInputLine;

  Procedure TOrderEditor.HandleEvent(Var Event: TEvent);

    Procedure EnterOrder(Item: Integer);
    Var
      Dlg: PDialog;
      DlgRec: Record
        Q: LongInt;
        R: String[60];
      End;
      I: Integer;
      R: TRect;
      Control: PView;
      DataRef: LongInt;
      Art: TArtikelRec;
      T: String[80];
    Begin
      DataRef:=Viewer^.GetDataRef(Item);
      If DataRef>0 Then
      Begin
        GetArtikelRec(DataRef, Art);
        If Order^.Search(@Item, I) Then
        Begin
          DlgRec.Q:=POrderItem(Order^.At(I))^.Quantity;
          DlgRec.R:=POrderItem(Order^.At(I))^.Remark.GetStr;
        End Else
          FillChar(DlgRec, SizeOf(DlgRec), 0);
        T:=Art.Name;
        If Art.Menge<>'' Then T:=T+', '+Art.Menge;
        R.Assign(11,7,71,15);
        New(Dlg, Init(R, T));
        R.Assign(3,3,15,4);
        Control := New(PIntInputLine, Init(R, 10, 0, 999));
        Dlg^.Insert(Control);
        R.Assign(3,2,10,3);
        Dlg^.Insert(New(PLabel, Init(R, '~A~nzahl', Control)));
        R.Assign(17,3,57,4);
        Control := New(PInputLine, Init(R, 60));
        Dlg^.Insert(Control);
        R.Assign(17,2,27,3);
        Dlg^.Insert(New(PLabel, Init(R, '~B~emerkung', Control)));
        R.Assign(16,5,36,7);
        Dlg^.Insert(New(PButton, Init(R, 'OK', cmOK, bfDefault)));
        R.Assign(37,5,57,7);
        Dlg^.Insert(New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal)));
        Dlg^.SelectNext(False);
        Dlg^.SetData(DlgRec);
        If DeskTop^.ExecView(Dlg)=cmOk Then
        Begin
          Dlg^.GetData(DlgRec);
          If DlgRec.Q=0 Then
            Order^.ZeroOut(Item)
          Else
            Order^.OrderNo(Item, DataRef, Art.Lieferant, DlgRec.Q, DlgRec.R);
          Viewer^.FocusItem(Viewer^.Focused);
          Redraw;
        End;
        Dispose(Dlg, Done);
      End Else
      Begin
        Sound(1000);
        Delay(50);
        Sound(500);
        Delay(100);
        Sound(1000);
        Delay(50);
        NoSound;
        If MessageBox('Kundenspezifisch belegen ?',
          nil, mfConfirmation+mfYesNoCancel)=cmYes Then
        Begin
          Event.What:=evCommand;
          Event.Command:=cmInsSpez;
          PutEvent(Event);
        End;
      End;
    End;

    Procedure InsertSpez(Item: Integer);
    Var Artikel: Integer;
    Begin
      If (OS^.Liste^[Item]<>0) And (MessageBox('Wollen Sie den Artikel wirklich überschreiben?',
        nil, mfConfirmation+mfYesNoCancel)<>cmYes) Then Exit;
      Artikel:=Artikelstamm^.Use(True);
      If Artikel<>-1 Then
      Begin
        Order^.ZeroOut(Item);
        Spez^.Belegen(Item, PArtikel(Artikelstamm^.At(Artikel))^.DataRef);
        Redraw;
      End;
    End;

    Procedure DeleteSpez(Item: Integer);
    Var I: Integer;
    Begin
      If Spez^.Search(@Item, I) Then
      Begin
        If MessageBox('Kundenspezifische Belegung zurücknehmen?',
          nil, mfConfirmation+mfYesNoCancel)=cmYes Then
        Begin
          Order^.ZeroOut(Item);
          Spez^.Loeschen(Item);
          Redraw;
        End;
      End Else
        MessageBox('Es liegt keine kundenspezifische Belegung vor.', nil,
          mfInformation+mfOkButton);
    End;

    Procedure DeleteAllSpez;
    Var I: Integer;
    Begin
      If MessageBox('Wollen Sie wirklich alle kundenspezifischen Belegungen zurücknehmen ????',
        nil, mfConfirmation+mfYesNoCancel)=cmYes Then
      Begin
        For I:=0 To Spez^.Count-1 Do
          Order^.ZeroOut(PSpezItem(Spez^.At(I))^.Item);
        Spez^.FreeAll;
        Redraw;
      End;
    End;

  Begin
    If (Event.What=evCommand) And (Event.Command=cmSaveOrder) Then
      Event.Command:=cmClose;
    TWindow.HandleEvent(Event);
    If (Event.What=evKeyDown) And (Event.KeyCode=kbEnter) Then
    Begin
      EnterOrder(Viewer^.Focused);
      ClearEvent(Event);
    End;
    If Event.What=evCommand Then
    Begin
      Case Event.Command Of
        cmInsSpez: InsertSpez(Viewer^.Focused);
        cmDelSpez: DeleteSpez(Viewer^.Focused);
        cmDelAllSpez: DeleteAllSpez;
        Else Exit;
      End;
      ClearEvent(Event);
    End;
    If Event.What=evBroadcast Then
    Begin
      If Event.Command=cmLookforOrder Then
        With Order^.Kunde Do
          If PString(Event.InfoPtr)^=Name+#0+Vorname Then
            ClearEvent(Event);
      If (Event.Command=cmLookforActiveOS) And (PString(Event.InfoPtr)^=Order^.OSFile^) Then
        ClearEvent(Event);
      If ((Event.Command=cmLookforOrderFile) Or (Event.Command=cmLookforOrderFileE)) And
        (Order^.OrderFile<>nil) And
        (PString(Event.InfoPtr)^=Order^.OrderFile^) Then
        ClearEvent(Event);
    End;
  End;

  Function TOrderEditor.Valid(Command: Word): Boolean;
  Var
    Cmd: Word;
    Strm: PBufStream;
    Idx: TResourceFile;
    Ok: Boolean;
  Begin
    If Command=cmValid Then Valid:=TWindow.Valid(Command) Else
    Begin
      Valid:=True;
      Ok:=True;
      If Spez^.Modified Then
      Begin
        Strm:=New(PBufStream, Init(Order^.OSFile^, stOpen, 1024));
        Idx.Init(Strm);
        With Order^.Kunde Do
          Idx.Put(Spez, '.'+Name+#0+Vorname);
        Ok:=Strm^.Status=stOk;
        Idx.Done;
        If (Not Ok) And (MessageBox('Kundenspezifische Liste kann nicht gesichert werden.'+#13+
            'Änderungen verwerfen ?', nil, mfError+mfYesNoCancel)<>cmYes) Then
        Begin
          Valid:=False;
          Exit;
        End;
      End;
      Ok:=False;
      If Order^.OrderFile=nil Then
      Begin
        If Order^.Total=0 Then
        Case MessageBox('Es wurden keine Artikel bestellt. Soll Bestellung verworfen werden?',
          nil, mfConfirmation+mfYesNoCancel) Of
          cmYes: Order^.Modified:=False;
          cmNo, cmCancel: Valid:=False;
        End Else
        Case MessageBox('Soll Bestellung gesichert werden?', nil, mfConfirmation+mfYesNoCancel) Of
          cmYes:
            Begin
              Order^.OrderFile:=NewStr(AddOrder(Order));
              Ok:=True;
            End;
          cmNo: Order^.Modified:=False;
          cmCancel: Valid:=False;
        End;
      End Else
      If Order^.Modified Then
      Case MessageBox('Sollen Änderungen an der Bestellung gesichert werden?', nil, mfConfirmation+mfYesNoCancel) Of
        cmYes: Ok:=True;
        cmNo: Order^.Modified:=False;
        cmCancel: Valid:=False;
      End;
      If Ok Then
      Begin
        Strm:=New(PBufStream, Init(Order^.OrderFile^, stCreate, 1024));
        Strm^.Put(Order);
        If Strm^.Status<>stOK Then
          If MessageBox('Bestellung konnte nicht gesichert werden. Nicht schließen?',
            nil, mfError+mfYesNoCancel)=cmYes Then Valid:=False;
        Dispose(Strm, Done);
      End;
    End;
  End;

  Destructor TOrderEditor.Done;
  Begin
    Dispose(Spez, Done);
    Dispose(OS, Done);
    Dispose(Order, Done);
    TWindow.Done;
  End;

{== Prozeduren/Funktionen ==================================================}

  Procedure PrintOrder(O: POrder);
  Var
    Pg, Ln: Byte;
    L, Art: Integer;
    LP: PLieferant;
    Liefer: TLieferantenRec;
    Item: POrderItem;
    A: TArtikelRec;
    F: String[80];
    ParRec: Record
      N, M, Nr: PString;
    End;
    Sum: Boolean;

    Function FindKundenNr: LongInt;
    Var I: Byte;
    Begin
      For I:=1 To 5 Do
        If O^.Kunde.Nr[I].Lfr=Liefer.LieferNr Then
        Begin
          FindKundenNr:=O^.Kunde.Nr[I].Nr;
          Exit;
        End;
      FindKundenNr:=0;
    End;

    Function FindLiefer(P: POrderItem): Boolean; far;
    Begin
      FindLiefer:=P^.Liefer=Liefer.LieferNr;
    End;

  Begin
    If Not InitPrinter(1) Then Exit;
    Sum:=O^.Kunde.Name='Zusammenfassung';
    ParRec.N:=@A.Name;
    ParRec.M:=@A.Menge;
    ParRec.Nr:=@A.ArtikelNr;
    For L:=0 To LieferantenStamm^.Count-1 Do With O^ Do
    Begin
      LP:=PLieferant(Lieferantenstamm^.At(L));
      GetLieferRec(LP^.DataRef, Liefer);
      Ln:=0;
      If FirstThat(@FindLiefer)<>nil Then
      Begin
        If Not DeskJet Then Write(Lst, ThickOn);
        If Sum Then
        Begin
          Writeln(Lst, 'Zusammenfassung vom ', Date.GetStrDate,
            ', ', Time.GetStrTime('.', tHour+tMinute));
          Writeln(Lst);
          Inc(Ln, 2);
        End Else
        Begin
          Writeln(Lst, 'An Firma');
          Writeln(Lst, Liefer.Name);
          Writeln(Lst, 'Telefon: '+Liefer.Telefon);
          Writeln(Lst, 'Telefax: '+Liefer.Telefax);
          Writeln(Lst);
          Writeln(Lst, 'Bestellung vom ', Date.GetStrDate);
          Writeln(Lst);
          Write(Lst, 'Kunde: ', Kunde.Name, ', ', Kunde.Ort);
          If FindKundenNr<>0 Then
            Write(Lst, '          Kundennr.:', FindKundenNr);
          Writeln(Lst);
          Writeln(Lst, 'Telefon: '+Kunde.Telefon);
          Writeln(Lst);
          Inc(Ln, 10);
        End;
        If Not Deskjet Then Write(Lst, ThickOff);
        Art:=0;
        Pg:=1;
        Repeat
          If Pg>1 Then
          Begin
            If Not DeskJet Then Write(Lst, ThickOn);
            Writeln(Lst, '  Seite ', Pg);
            If Not Sum Then
            Begin
              Writeln(Lst, 'An Firma: ', Liefer.Name);
              Writeln(Lst, 'Kunde: ', Kunde.Name, ',  ', Kunde.Ort);
              Inc(Ln, 3);
            End;
            Writeln(Lst);
            Inc(Ln);
            If Not DeskJet Then Write(Lst, ThickOff);
          End;
          Write(Lst, '  ARTIKEL                      GE INH        ARTIKELNR.  MENGE');
          If Not Sum Then Write(Lst, ' ÄNDERUNG');
          Writeln(Lst);
          Writeln(Lst, '------------------------------------------------------------------------');
          Inc(Ln, 2);
          While (Ln<LPP) And (Art<Count) Do
          Begin
            Item:=POrderItem(At(Art));
            If Item^.Liefer=Liefer.LieferNr Then
            Begin
              GetArtikelRec(Item^.Artikel, A);
              FormatStr(F, '%-30s %-10s %12s  ', ParRec);
              Write(Lst, F);
              If DeskJet Then
                Write(Lst, Item^.Quantity:5)
              Else
                Write(Lst, ThickOn, Item^.Quantity:5, ThickOff);
              If Not Sum Then Write(Lst, '   I_____I');
              Writeln(Lst);
              Inc(Ln);
              If Item^.Remark.P<>nil Then
              Begin
                Inc(Ln);
                If DeskJet Then
                  Writeln(Lst, '     ', Item^.Remark.GetStr)
                Else
                  Writeln(Lst, ThickOn, '     ', Item^.Remark.GetStr, ThickOff);
              End;
            End;
            Inc(Art);
            If Keypressed And (Readkey=#27) Then Exit;
          End;
          Write(Lst, #12);
          Inc(Pg);
          Ln:=0;
        Until Art>=Count;
      End;
    End;
  End;

  Procedure Bestellung_Annehmen;
  Var
    Kunde: TKundenRec;
    K: String;
    OS: String;
    I: Integer;
  Begin
    If Kundenstamm^.Count>0 Then
    Begin
      I:=Kundenstamm^.Use(True);
      If I>=0 Then
      Begin
        GetKundenRec(PKunde(Kundenstamm^.At(I))^.DataRef, Kunde);
        With Kunde Do K:=Name+#0+Vorname;
        If Message(DeskTop, evBroadcast, cmLookforOrder, @K)=nil Then
        Begin
          OS:=GetActiveOS;
          If OS<>'' Then
            DeskTop^.Insert(New(POrderEditor, Init(New(POrder, Init(Kunde, OS)))));
        End Else
          MessageBox('Es wird bereits eine Bestellung dieses Kunden angenommen.',
            nil, mfInformation+mfOkButton);
      End;
    End Else
      MessageBox('Der Kundenstamm ist leer.', nil, mfInformation+mfOkButton);
  End;

Begin
  RegisterType(ROrder);
  RegisterType(RSpezPos);
End.