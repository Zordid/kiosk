{$I KIOSKCO.PAS}
Unit CurrOrd;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, MsgBox, App,
    DateUtl, DosTools,
    KioskCmds, KioskRez, Artikel, Kunden, Orders;

  Type
    TTimeDateRec= Record
      Date: TDate;
      Time: TTime;
    End;

    PCurrentOrder= ^TCurrentOrder;
    TCurrentOrder= Object(TObject)
      Selected: Boolean;
      Kunde: TKundenRec;
      TimeDate: TTimeDateRec;
      FileNo: Word;
      Constructor Init(O: POrder);
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function GetFileName: String;
    End;

    PCurrentColl= ^TCurrentColl;
    TCurrentColl= Object(TSortedCollection)
      Counter: Word;
      Modified: Boolean;
      SelCount: Word;
      Constructor Init;
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function KeyOf(Item: Pointer): Pointer; virtual;
      Function Compare(Key1, Key2: Pointer): Integer; virtual;
      Function InsertOrder(O: POrder): String;
      Procedure Edit;
    End;

    PCurrentOrderViewer= ^TCurrentOrderViewer;
    TCurrentOrderViewer= Object(TListViewer)
      List: PCurrentColl;
      Function DataSize: Word; virtual;
      Procedure GetData(Var Rec); virtual;
      Procedure SetData(Var Rec); virtual;
      Procedure SetRange(ARange: Integer);
      Function GetText(Item, MaxLen: Integer): String; virtual;
      Procedure SelectItem(Item: Integer); virtual;
    End;

    PCurrentOrderDialog= ^TCurrentOrderDialog;
    TCurrentOrderDialog= Object(TDialog)
      Viewer: PCurrentOrderViewer;
      List: PCurrentColl;
      Procedure HandleEvent(Var Event: TEvent); virtual;
    End;

    POrderSumScroller= ^TOrderSumScroller;
    TOrderSumScroller= Object(TScroller)
      OrderSum: POrder;
      Constructor Init(Var Bounds: TRect; AHScrollbar, AVScrollbar: PScrollbar;
        O: POrder);
      Procedure Draw; virtual;
      Procedure HandleEvent(Var Event: TEvent); virtual;
      Destructor Done; virtual;
    End;

    POrderViewer= ^TOrderViewer;
    TOrderViewer= Object(TWindow)
      Constructor Init(O: POrder);
    End;

    POrderSum= ^TOrderSum;
    TOrderSum= Object(TSortedCollection)
      Function KeyOf(Item: Pointer): Pointer; virtual;
      Function Compare(Key1, Key2: Pointer): Integer; virtual;
      Procedure Add(P: POrderItem);
    End;

  Const
    RCurrentOrder: TStreamRec= (
      ObjType: 2013;
      VmtLink: Ofs(TypeOf(TCurrentOrder)^);
      Load: @TCurrentOrder.Load;
      Store: @TCurrentOrder.Store
    );
    RCurrentColl: TStreamRec= (
      ObjType: 2014;
      VmtLink: Ofs(TypeOf(TCurrentColl)^);
      Load: @TCurrentColl.Load;
      Store: @TCurrentColl.Store
    );
    RCurrentOrderViewer: TStreamRec= (
      ObjType: 3008;
      VmtLink: Ofs(TypeOf(TCurrentOrderViewer)^);
      Load: @TCurrentOrderViewer.Load;
      Store: @TCurrentOrderViewer.Store
    );
    RCurrentOrderDialog: TStreamRec= (
      ObjType: 3009;
      VmtLink: Ofs(TypeOf(TCurrentOrderDialog)^);
      Load: @TCurrentOrderDialog.Load;
      Store: @TCurrentOrderDialog.Store
    );

  Procedure OpenCurrentOrders;
  Procedure CloseCurrentOrders;
  Procedure EditCurrentOrders;
  Function AddOrder(O: POrder): String;

Implementation
  Type
    ViewerRec= Record
      List: PCurrentColl;
      F: Integer;
    End;

  Var
    CurrentOrder: PCurrentColl;

{== TCurrentOrders =========================================================}

  Constructor TCurrentOrder.Init(O: POrder);
  Begin
    TObject.Init;
    Move(O^.Kunde, Kunde, SizeOf(Kunde));
    TimeDate.Date.InitTDate(O^.Date);
    TimeDate.Time.InitTTime(O^.Time);
  End;

  Constructor TCurrentOrder.Load(Var S: TStream);
  Begin
    S.Read(Kunde, SizeOf(Kunde));
    TimeDate.Date.Load(S);
    TimeDate.Time.Load(S);
    S.Read(FileNo, SizeOf(FileNo));
    Selected:=False;
  End;

  Procedure TCurrentOrder.Store(Var S: TStream);
  Begin
    S.Write(Kunde, SizeOf(Kunde));
    TimeDate.Date.Store(S);
    TimeDate.Time.Store(S);
    S.Write(FileNo, SizeOf(FileNo));
  End;

  Function TCurrentOrder.GetFileName: String;
  Var F: String;
  Begin
    Str(LongInt(FileNo)+10000:5, F);
    Move(F[2], F[4], 4);
    F[0]:=#7; F[1]:='O'; F[2]:='R'; F[3]:='D';
    F:=F+'.ACT';
    GetFileName:=F;
  End;

{== TCurrentColl ===========================================================}

  Constructor TCurrentColl.Init;
  Begin
    TSortedCollection.Init(0, 5);
    Counter:=0;
    Modified:=True;
    SelCount:=0;
  End;

  Constructor TCurrentColl.Load(Var S: TStream);
  Begin
    TSortedCollection.Load(S);
    S.Read(Counter, SizeOf(Counter));
    Modified:=False;
    SelCount:=0;
  End;

  Procedure TCurrentColl.Store(Var S: TStream);
  Begin
    TSortedCollection.Store(S);
    S.Write(Counter, SizeOf(Counter));
  End;

  Function TCurrentColl.KeyOf(Item: Pointer): Pointer;
  Begin
    KeyOf:=@PCurrentOrder(Item)^.TimeDate;
  End;

  Function TCurrentColl.Compare(Key1, Key2: Pointer): Integer;
  Var
    DaysLeft: LongInt;
    Time1, Time2: LongInt;
  Begin
    DaysLeft:=TTimeDateRec(Key1^).Date.DaysLeftTill(TTimeDateRec(Key2^).Date);
    If DaysLeft>0 Then Compare:=-1 Else
      If DaysLeft<0 Then Compare:=+1 Else
      Begin
        With TTimeDateRec(Key1^).Time Do
          Time1:=GetSecond+GetMinute*60+GetHour*3600;
        With TTimeDateRec(Key2^).Time Do
          Time2:=GetSecond+GetMinute*60+GetHour*3600;
        If Time1<Time2 Then Compare:=-1 Else
          If Time1>Time2 Then Compare:=+1 Else
            Compare:=0;
      End;
  End;

  Function TCurrentColl.InsertOrder(O: POrder): String;
  Var C: PCurrentOrder;
  Begin
    C:=New(PCurrentOrder, Init(O));
    C^.FileNo:=Counter;
    Inc(Counter);
    Modified:=True;
    Insert(C);
    InsertOrder:=C^.GetFileName;
  End;

  Procedure TCurrentColl.Edit;
  Var
    Dlg: PCurrentOrderDialog;
    R: ViewerRec;
  Begin
    Dlg:=Message(DeskTop, evBroadcast, cmLookforCurrList, nil);
    If Dlg=nil Then
    Begin
      Dlg:=PCurrentOrderDialog(GetRez('CurrentDialog'));
      If Dlg<>nil Then
      Begin
        R.List:=@Self;
        R.F:=0;
        Dlg^.SetData(R);
        Dlg^.Viewer:=PCurrentOrderViewer(Dlg^.Current);
        If Count>0 Then
          Dlg^.Viewer^.FocusItem(Count-1);
        Dlg^.List:=@Self;
        DeskTop^.Insert(Dlg);
      End;
    End Else
      Dlg^.Select;
  End;

{== TCurrentOrderViewer ====================================================}

  Procedure TCurrentOrderViewer.SetRange(ARange: Integer);
  Begin
    TListViewer.SetRange(ARange);
    If ARange=0 Then
      DisableCommands(CurrentCmds)
    Else
      EnableCommands(CurrentCmds);
  End;

  Function TCurrentOrderViewer.DataSize: Word;
  Begin
    DataSize:=SizeOf(ViewerRec);
  End;

  Procedure TCurrentOrderViewer.SetData(Var Rec);
  Begin
    List:=ViewerRec(Rec).List;
    SetRange(List^.Count);
    FocusItem(ViewerRec(Rec).F);
  End;

  Procedure TCurrentOrderViewer.GetData(Var Rec);
  Begin
    ViewerRec(Rec).List:=List;
    ViewerRec(Rec).F:=Focused;
  End;

  Function TCurrentOrderViewer.GetText(Item, MaxLen: Integer): String;
  Var
    S: String;
    C: PCurrentOrder;
  Begin
    C:=PCurrentOrder(List^.At(Item));
    FillChar(S[1], Size.X, #32);
    S:='  '+C^.Kunde.Name;
    If C^.Kunde.Vorname<>'' Then S:=S+', '+C^.Kunde.Vorname;
    S[0]:=#33;
    If C^.Selected Then S[1]:=#251;
    GetText:=S+'  '+C^.TimeDate.Date.GetStrDate+', '+
      C^.TimeDate.Time.GetStrTime('.', tHour+tMinute);
  End;

  Procedure TCurrentOrderViewer.SelectItem(Item: Integer);
  Var S: Boolean;
  Begin
    S:=PCurrentOrder(List^.At(Item))^.Selected;
    PCurrentOrder(List^.At(Item))^.Selected:=Not S;
    If S Then Dec(List^.SelCount) Else Inc(List^.SelCount);
    If List^.SelCount<2 Then
      DisableCommands([cmCurrSumUp])
    Else
      EnableCommands([cmCurrSumUp]);
    TListViewer.SelectItem(Item);
    Draw;
  End;

{== TOrderSum ==============================================================}

  Function TOrderSum.KeyOf(Item: Pointer): Pointer;
  Begin
    KeyOf:=@POrderItem(Item)^.Artikel;
  End;

  Function TOrderSum.Compare(Key1, Key2: Pointer): Integer;
  Begin
    If LongInt(Key1^)<LongInt(Key2^) Then Compare:=-1 Else
      If LongInt(Key1^)>LongInt(Key2^) Then Compare:=+1 Else
        Compare:=0;
  End;

  Procedure TOrderSum.Add(P: POrderItem);
  Var
    I: Integer;
    N: POrderItem;
  Begin
    If Search(@P^.Artikel, I) Then
    Begin
      Inc(POrderItem(At(I))^.Quantity, P^.Quantity);
    End Else
    Begin
      New(N);
      N^.No:=P^.No;
      N^.Artikel:=P^.Artikel;
      N^.Liefer:=P^.Liefer;
      N^.Quantity:=P^.Quantity;
      N^.Remark.Init('');
      Insert(N);
    End;
  End;

{== TCurrentOrderDialog ====================================================}

  Procedure TCurrentOrderDialog.HandleEvent(Var Event: TEvent);

    Function GetOrder(F: String): POrder;
    Var
      Strm: TBufStream;
      O: POrder;
    Begin
      Strm.Init(F, stOpen, 1024);
      O:=POrder(Strm.Get);
      If (Strm.Status<>stOK) Or (O=nil) Then
      Begin
        MessageBox('Bestellung konnte nicht gelesen werden.', nil, mfError+mfOkButton);
        O:=nil;
      End;
      Strm.Done;
      GetOrder:=O;
    End;

    Procedure Edit;
    Var
      O: POrder;
      P: PCurrentOrder;
      F: String;
      V: POrderEditor;
    Begin
      P:=PCurrentOrder(List^.At(Viewer^.Focused));
      F:=P^.GetFileName;
      V:=Message(DeskTop, evBroadcast, cmLookforOrderFileE, @F);
      If V=nil Then
      Begin
        O:=GetOrder(F);
        If O<>nil Then DeskTop^.Insert(New(POrderEditor, Init(O)));
      End Else
        V^.Select;
    End;

    Procedure View;
    Var O: POrder;
    Begin
      O:=GetOrder(PCurrentOrder(List^.At(Viewer^.Focused))^.GetFileName);
      If O<>nil Then DeskTop^.Insert(New(POrderViewer, Init(O)));
    End;

    Procedure Del;
    Var
      P: PCurrentOrder;
      F: String;

      Function IsSelected(P: PCurrentOrder): Boolean; far;
      Begin
        IsSelected:=P^.Selected;
      End;

    Begin
      If MessageBox('Wollen Sie diese Bestellung(en) wirklich löschen?', nil,
        mfConfirmation+mfYesNoCancel)=cmYes Then
      Begin
        If List^.SelCount=0 Then
          Viewer^.SelectItem(Viewer^.Focused);
        While List^.SelCount>0 Do
        Begin
          P:=List^.FirstThat(@IsSelected);
          If P<>nil Then
          Begin
            F:=P^.GetFileName;
            If Message(DeskTop, evBroadcast, cmLookforOrderFile, @F)=nil Then
            Begin
              FileDelete(F);
              List^.AtFree(List^.IndexOf(P));
              List^.Modified:=True;
            End Else
            Begin
	      MessageBox('Bestellung von '+P^.Kunde.Name+' wird gerade bearbeitet.'#13+
                'Sie kann nicht gelöscht werden.', nil, mfInformation+mfOkButton);
              P^.Selected:=False;
	    End;
          End;
          Dec(List^.SelCount);
        End;
        DisableCommands([cmCurrSumUp]);
        Viewer^.SetRange(List^.Count);
        Redraw;
      End;
    End;

    Procedure SumUp;
    Var
      K: TKundenRec;
      I, J: Integer;
      Sum: POrderSum;
      C: PCurrentOrder;
      O, P: POrder;
    Begin
      Sum:=New(POrderSum, Init(5, 5));
      For I:=0 To List^.Count-1 Do
      Begin
        C:=PCurrentOrder(List^.At(I));
        If C^.Selected Then
        Begin
          O:=GetOrder(C^.GetFileName);
          If O<>nil Then
          Begin
            For J:=0 To O^.Count-1 Do Sum^.Add(POrderItem(O^.At(J)));
            Dispose(O, Done);
          End;
        End;
      End;
      FillChar(K, SizeOf(K), 0);
      K.Name:='Zusammenfassung';
      P:=New(POrder, Init(K, ''));
      For J:=0 To Sum^.Count-1 Do P^.Insert(POrderItem(Sum^.At(J)));
      Sum^.DeleteAll;
      Dispose(Sum, Done);
      DeskTop^.Insert(New(POrderViewer, Init(P)));
    End;

    Procedure Print;
    Var O: POrder;
    Begin
      O:=GetOrder(PCurrentOrder(List^.At(Viewer^.Focused))^.GetFileName);
      If O<>nil Then
      Begin
        PrintOrder(O);
        Dispose(O, Done);
      End;
    End;

  Begin
    TDialog.HandleEvent(Event);
    If Event.What=evCommand Then
    Begin
      If Viewer^.Range=0 Then Exit;
      Case Event.Command Of
        cmCurrEdit: Edit;
        cmCurrView: View;
        cmCurrPrint: Print;
        cmCurrSumUp: SumUp;
        cmDelete: Del;
        Else Exit;
      End;
      ClearEvent(Event);
    End;
    If (Event.What=evBroadcast) And (Event.Command=cmLookforCurrList) Then
    Begin
      Viewer^.SetRange(List^.Count);
      Redraw;
      ClearEvent(Event);
    End;
  End;

{== TOrderSumScroller ======================================================}

  Constructor TOrderSumScroller.Init(Var Bounds: TRect; AHScrollbar,
    AVScrollbar: PScrollbar; O: POrder);
  Begin
    TScroller.Init(Bounds, AHScrollbar, AVScrollbar);
    GrowMode:=gfGrowHiX+gfGrowHiY;
    SetLimit(110, O^.Count);
    OrderSum:=O;
  End;

  Procedure TOrderSumScroller.Draw;
  Var
    Color: Byte;
    I, Y: Integer;
    B: TDrawBuffer;
    O: POrderItem;
    A: TArtikelRec;
    S: String;
    P: Record
      N, M: PString;
      Q: LongInt;
      T: PString;
    End;
  Begin
    Color:=GetColor(1);
    P.N:=@A.Name;
    P.M:=@A.Menge;
    For Y:=0 To Size.Y-1 Do
    Begin
      MoveChar(B, ' ', Color, Size.X);
      If Delta.Y+Y<OrderSum^.Count Then
      Begin
        O:=POrderItem(OrderSum^.At(Delta.Y+Y));
        GetArtikelRec(O^.Artikel, A);
        P.Q:=O^.Quantity;
        P.T:=O^.Remark.P;
        FormatStr(S, '%-30s %-10s  %3dx  %-60s', P);
        MoveStr(B[1], Copy(S, Delta.X+1, Size.X-1), Color);
      End;
      WriteLine(0, Y, Size.X, 1, B);
    End;
  End;

  Procedure TOrderSumScroller.HandleEvent(Var Event: TEvent);
  Begin
    TScroller.HandleEvent(Event);
    If Event.What=evCommand Then
    Begin
      Case Event.KeyCode Of
        cmPrintOrder: PrintOrder(OrderSum);
        cmEditOrder: If OrderSum^.Kunde.Name<>'Zusammenfassung' Then
          Begin
            DeskTop^.Insert(New(POrderEditor, Init(OrderSum)));
            OrderSum:=nil;
            PWindow(Owner)^.Close;
	  End;
      End;
    End;
    If (Event.What=evBroadcast) Then
    Begin
      If (Event.Command=cmLookforOrderFile) And
        (PString(Event.InfoPtr)^=OrderSum^.OrderFile^) Then
        ClearEvent(Event);
      If (Event.Command=cmStammChanged) Then Draw;
    End;
  End;

  Destructor TOrderSumScroller.Done;
  Begin
    If OrderSum<>nil Then Dispose(OrderSum, Done);
    TScroller.Done;
  End;

{== TOrderViewer ===========================================================}

  Constructor TOrderViewer.Init(O: POrder);
  Var
    R: TRect;
    T: TTitleStr;
  Begin
    R.Assign(0, 0, 80, 23);
    With O^ Do
    Begin
      T:=Kunde.Name;
      If Kunde.Vorname<>'' Then T:=T+', '+Kunde.Vorname;
      T:=T+'  '+Date.GetStrDate+'  '+Time.GetStrTime('.', tHour+tMinute);
    End;
    TWindow.Init(R, T, wnNoNumber);
    HelpCtx:=hcOrderViewer;
    GetExtent(R);
    R.Grow(-1, -1);
    Insert(New(POrderSumScroller, Init(R, StandardScrollbar(sbHorizontal+sbHandleKeyboard),
      StandardScrollbar(sbVertical+sbHandleKeyboard), O)));
  End;

{== Prozeduren/Funktionen ==================================================}

  Procedure OpenCurrentOrders;
  Var Strm: TBufStream;
  Begin
    Strm.Init('ORDINDEX.ACT', stOpen, 1024);
    CurrentOrder:=PCurrentColl(Strm.Get);
    If Strm.Status<>stOK Then
    Begin
      MessageBox('Liste aktueller Bestellungen existiert nicht.'#13'Wird neu angelegt.',
        nil, mfInformation+mfOkButton);
      CurrentOrder:=New(PCurrentColl, Init);
    End;
    Strm.Done;
  End;

  Procedure CloseCurrentOrders;
  Var Strm: TBufStream;
  Begin
    If CurrentOrder^.Modified Then
    Begin
      Strm.Init('ORDINDEX.ACT', stCreate, 1024);
      Strm.Put(CurrentOrder);
      If Strm.Status<>stOK Then
        MessageBox('Liste aktueller Bestellung konnte nicht aktualisiert werden.',
          nil, mfError+mfOkButton);
      Strm.Done;
    End;
    Dispose(CurrentOrder, Done);
  End;

  Function AddOrder(O: POrder): String;
  Begin
    AddOrder:=CurrentOrder^.InsertOrder(O);
    Message(Desktop, evBroadcast, cmLookforCurrList, nil);
  End;

  Procedure EditCurrentOrders;
  Begin
    CurrentOrder^.Edit;
  End;

Begin
  RegisterType(RCurrentOrder);
  RegisterType(RCurrentColl);
  RegisterType(RCurrentOrderViewer);
  RegisterType(RCurrentOrderDialog);
End.