{$I KIOSKCO.PAS}
Unit OSViews;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, Fields, MsgBox, StdDlg, App,
    Crt, Printer, StrUtl, DosTools,
    KioskRez, KioskCmds, Artikel, Ordersatz, Drucker;

  Type
    TLineArray= Array[0..45] Of Integer;

    PTopLine= ^TTopLine;
    TTopLine= Object(TView)
      Txt: PString;
      Constructor Init(O, S: TPoint);
      Procedure Draw; virtual;
      Function GetPalette: PPalette; virtual;
      Procedure UpDate(P: PString);
    End;

    POSScroller= ^TOSScroller;
    TOSScroller= Object(TScroller)
      Focused: Word;
      OS: POrdersatz;
      LineArray: TLineArray;
      Top, Bottom: Word;
      TopLine: PTopLine;
      FastFind: String[5];
      Constructor Init(Var Bounds: TRect; SB: PScrollbar; AnOS: POrdersatz);
      Procedure FocusItem(Item: Integer); virtual;
      Procedure Draw; virtual;
      Procedure HandleEvent(Var Event: TEvent); virtual;
      Procedure CalcLineArray;
      Procedure ScrollUp(Up: Boolean);
      Procedure CalcLimit;
      Procedure SetLimit(X, Y: Integer);
      Function GetDataRef(Item: Integer): LongInt; virtual;
      Function GetText(Item, MaxLen: Integer): String; virtual;
      Procedure ChangeBounds(Var Bounds: TRect); virtual;
    End;

    TMode= (Ovr, Ins);
    PModeDisplay= ^TModeDisplay;
    TModeDisplay= Object(TView)
      Constructor Init(Var Bounds: TRect);
      Procedure Draw; virtual;
      Procedure HandleEvent(Var Event: TEvent); virtual;
      Function GetPalette: PPalette; virtual;
      Procedure SetState(AState: Word; Enable: Boolean); virtual;
    End;

    POSEditor= ^TOSEditor;
    TOSEditor= Object(TWindow)
      Mode: TMode;
      Modified: Boolean;
      OS: POrdersatz;
      Scroller: POSScroller;
      ModeDisplay: PModeDisplay;
      Constructor Init(AnOS: POrdersatz);
      Procedure SetState(AState: Word; Enable: Boolean); virtual;
      Procedure OSChanged;
      Procedure HandleEvent(Var Event: TEvent); virtual;
      Procedure SizeLimits(Var Min, Max: TPoint); virtual;
      Function Valid(Command: Word): Boolean; virtual;
      Function GetTitle(MaxSize: Integer): TTitleStr; virtual;
      Destructor Done; virtual;
    End;

  Procedure LoadOS;
  Function StoreOS(OS: POrdersatz): Boolean;
  Procedure PrintOS(OS: POrdersatz);

Implementation

{== TModeDisplay ===========================================================}
  Const
    CModeDisplay= #2#3#1;

  Constructor TModeDisplay.Init(Var Bounds: TRect);
  Begin
    TView.Init(Bounds);
    GrowMode:=gfGrowLoY + gfGrowHiY;
    EventMask:=evBroadcast + evMouseDown;
  End;

  Procedure TModeDisplay.Draw;
  Var
    Color: Byte;
    Frame: Char;
    B: TDrawBuffer;
  Begin
    Frame:=#196;
    If (Owner^.State And sfSelected <> 0) Then
    Begin
      If (State And sfDragging = 0) Then
      Begin
        Color:=GetColor(1);
        Frame:=#205;
      End Else Color:=GetColor(2);
    End Else Color:=GetColor(3);
    MoveChar(B, Frame, Color, Size.X);
    If POSEditor(Owner)^.Mode=Ovr Then
      MoveStr(B, ' Ovr ', Color)
    Else
      MoveStr(B, ' Ins ', Color);
    If POSEditor(Owner)^.Modified Then
      MoveChar(B[7], #15, Color, 1);
    WriteBuf(0, 0, Size.X, 1, B);
  End;

  Function TModeDisplay.GetPalette: PPalette;
  Const
    P: String[Length(CModeDisplay)]= CModeDisplay;
  Begin
    GetPalette:=@P;
  End;

  Procedure TModeDisplay.HandleEvent(Var Event: TEvent);
  Begin
    If Event.What=evMouseDown Then
    Begin
      Boolean(POSEditor(Owner)^.Mode):=Not Boolean(POSEditor(Owner)^.Mode);
      Draw;
      ClearEvent(Event);
    End;
    If (Event.What=evBroadcast) And (Event.Command=cmOSChanged) Then
      Draw;
  End;

  Procedure TModeDisplay.SetState;
  Begin
    TView.SetState(AState, Enable);
    If (AState=sfDragging) Or (AState=sfActive) Then DrawView;
  End;

{== TTopLine ===============================================================}

  Constructor TTopLine.Init(O, S: TPoint);
  Var R: TRect;
  Begin
    R.Assign(O.X, O.Y-1, O.X+S.X, O.Y);
    TView.Init(R);
    GrowMode:=gfGrowHiX;
  End;

  Procedure TTopLine.Draw;
  Var B: TDrawBuffer;
  Begin
    MoveChar(B, ' ', GetColor(1), Size.X);
    If Txt<>nil Then MoveStr(B[5], Txt^, GetColor(1));
    WriteBuf(0, 0, Size.X, 1, B);
  End;

  Function TTopLine.GetPalette: PPalette;
  Const P: String[1]= #6;
  Begin
    GetPalette:=@P;
  End;

  Procedure TTopLine.UpDate(P: PString);
  Begin
    Txt:=P;
    Draw;
  End;

{== TOSScroller ============================================================}

  Constructor TOSScroller.Init(Var Bounds: TRect; SB: PScrollbar; AnOS: POrdersatz);
  Begin
    Inc(Bounds.A.Y);
    TScroller.Init(Bounds, nil, SB);
    OS:=AnOS;
    GrowMode:=gfGrowHiX + gfGrowHiY;
    EventMask:=EventMask + evMouseAuto;
    Focused:=1;
    FastFind:='';
    CalcLimit;
  End;

  Procedure TOSScroller.ChangeBounds(Var Bounds: TRect);
  Begin
    TScroller.ChangeBounds(Bounds);
    CalcLimit;
  End;

  Procedure TOSScroller.CalcLimit;
  Var L: Integer;
  Begin
    L:=OS^.Items+OS^.WGruppen^.Count;
    SetLimit(0, L);
  End;

  Procedure TOSScroller.SetLimit(X, Y: Integer);
  Begin
    TScroller.SetLimit(X, Y);
    If OS^.Items>0 Then
    Begin
      If Focused<1 Then FocusItem(1);
      If Focused>OS^.Items Then FocusItem(OS^.Items);
    End Else
      Focused:=0;
  End;

  Procedure TOSScroller.FocusItem(Item: Integer);
  Begin
    Focused:=Item;
  End;

  Function TOSScroller.GetDataRef(Item: Integer): LongInt;
  Begin
    GetDataRef:=OS^.Liste^[Item];
  End;

  Function TOSScroller.GetText(Item, MaxLen: Integer): String;
  Var
    F: String;
    Len: Byte;
    Art: TArtikelRec;
    ParRec: Record
      No: LongInt;
      Artikel, Menge: PString;
    End;
  Begin
    ParRec.No:=Item;
    If GetDataRef(Item)<>0 Then
    Begin
      ParRec.Artikel:=@Art.Name;
      ParRec.Menge:=@Art.Menge;
      FillChar(Art.Name, 30, #32);
      GetArtikelRec(GetDataRef(Item), Art);
      Len:=MaxLen-18;
      If Len<15 Then Len:=15;
      If Len>30 Then Len:=30;
      Art.Name[0]:=Char(Len);
      FormatStr(F, ' %4d  %s %-10s', ParRec);
    End Else
      FormatStr(F, ' %4d', ParRec);
    GetText:=F;
  End;

  Procedure TOSScroller.Draw;
  Var
    C, Color, HiColor: Byte;
    Start: Word;
    Y, I: Integer;
    B: TDrawBuffer;
  Begin
    Color:=GetColor(1);
    HiColor:=GetColor(2);
    CalcLineArray;
    { Info-Line }
    If TopLine=nil Then
    Begin
      TopLine:=New(PTopLine, Init(Origin, Size));
      Owner^.Insert(TopLine);
    End;
    If LineArray[0]>0 Then
    Begin
      OS^.WGruppen^.SearchGruppe(Top, I);
      TopLine^.UpDate(PGruppe(OS^.WGruppen^.At(I))^.Name.P);
    End Else
      TopLine^.UpDate(nil);
    { Draw lines... }
    For Y:=0 To Size.Y-1 Do
    Begin
      MoveChar(B, ' ', Color, Size.X);
      I:=LineArray[Y];
      If I>0 Then
      Begin
        If I=Focused Then
        Begin
          MoveChar(B, ' ', HiColor, Size.X);
          C:=HiColor;
        End Else
          C:=Color;
        MoveStr(B, GetText(I, Size.X), C);
      End Else
        If I<0 Then MoveStr(B[5], PGruppe(OS^.WGruppen^.At(Abs(I)-1))^.Name.GetStr, Color);
      WriteLine(0, Y, Size.X, 1, B);
    End;
  End;

  Procedure TOSScroller.ScrollUp(Up: Boolean);
  Begin
    Case Up Of
      True: If Focused>1 Then FocusItem(Focused-1);
      False: If Focused<OS^.Items Then FocusItem(Focused+1);
    End;
    While Focused<Top Do ScrollTo(0, Delta.Y-1);
    While Focused>Bottom Do ScrollTo(0, Delta.Y+1);
  End;

  Procedure TOSScroller.HandleEvent(Var Event: TEvent);
  Var
    I, C: Integer;
    M: TPoint;
  Begin
    TScroller.HandleEvent(Event);
    { handle broadcast events }
    If (Event.What=evBroadcast) And
      ((Event.Command=cmOSChanged) Or (Event.Command=cmStammChanged)) Then
    Begin
      { reset limit & draw }
      CalcLimit;
      Draw;
      Exit;
    End;
    { no more handling if order form is empty }
    If OS^.Items=0 Then Exit;
    { handle keyboard }
    If Event.What=evKeyDown Then 
    Begin
      If (Event.CharCode>='0') And (Event.CharCode<='9') Then
      Begin
        If Length(FastFind)<4 Then
        Begin
          Val(FastFind+Event.CharCode, I, C);
          If (I>0) And (I<OS^.Items) Then
          Begin
            ChrCat(FastFind, Event.CharCode);
            If (I<Top) Or (I>Bottom) Then
            Begin
              C:=I-1;
              Repeat
                ScrollTo(0, C);
                Inc(C);
              Until I<=Bottom;
            End;
            FocusItem(I);
            Draw;
          End;
        End;
      End Else
      Begin
        FastFind:='';
        Case Event.Keycode Of
          kbUp: ScrollUp(True);
          kbDown: ScrollUp(False);
          kbPgUp:
            Begin
              Focused:=0;
              ScrollTo(0, Delta.Y-Size.Y+2);
              FocusItem(Top);
            End;
          kbPgDn:
            Begin
              Focused:=0;
              ScrollTo(0, Delta.Y+Size.Y-2);
              FocusItem(Bottom);
            End;
          Else Exit;
        End;
        Draw;
        ClearEvent(Event);
      End;
    End;
    { handle mouse }
    If (Event.What=evMouseDown) Then
    Begin
      FastFind:='';
      Repeat
        MakeLocal(Event.Where, M);
        If M.Y<0 Then ScrollUp(True) Else
          If M.Y>Size.Y Then ScrollUp(False) Else
        Begin
          I:=LineArray[M.Y];
          If (I>0) And (I<=1000) Then FocusItem(I);
          Draw;
        End;
      Until Not MouseEvent(Event, evMouseMove+evMouseAuto);
      ClearEvent(Event);
    End;
  End;

  Procedure TOSScroller.CalcLineArray;
  Var Y, I, L, P, NewP, Line: Integer;
  Begin
    Line:=Delta.Y+1;
    With OS^.WGruppen^ Do
    Begin
      If Line>1 Then
      Begin
        I:=Count-1;
        Repeat
          L:=PGruppe(At(I))^.From+I;
          If L>Line Then Dec(I);
        Until (I<0) Or (L<=Line);
        P:=PGruppe(At(I))^.From;
        If L<Line Then
        Begin
          L:=P+I;
          Inc(P, Line-L);
          Inc(I);
        End;
      End Else
      Begin
        I:=0;
        P:=1;
      End;
      Y:=0;
      Top:=P;
      L:=LastItem;
      While Y<Size.Y Do
      Begin
        If P<=L Then
        Begin
          If (I<Count) And (P=PGruppe(At(I))^.From) Then
          Begin
            LineArray[Y]:=-(I+1);
            Inc(Y);
            Inc(I);
          End;
          LineArray[Y]:=P;
          Inc(P);
        End Else
          LineArray[Y]:=0;
        Inc(Y);
      End;
      Y:=Size.Y-1;
      While (Y>1) And (LineArray[Y]<=0) Do Dec(Y);
      Bottom:=LineArray[Y];
    End;
  End;

{== TOSEditor ==============================================================}

  Constructor TOSEditor.Init(AnOS: POrdersatz);
  Var
    R: TRect;
    S: PScrollBar;
  Begin
    If AnOS=nil Then Fail;
    R.Assign(0, 0, 41, 23);
    TWindow.Init(R, '', wnNoNumber);
    Options:=Options+ofFirstClick;
    OS:=AnOS;
    Mode:=Ins;
    S:=StandardScrollBar(sbVertical);
    GetExtent(R);
    R.Grow(-1, -1);
    Scroller:=New(POSScroller, Init(R, S, OS));
    Insert(Scroller);
    R.Assign(3, 22, 18, 23);
    ModeDisplay:=New(PModeDisplay, Init(R));
    Insert(ModeDisplay);
    HelpCtx:=hcOSEditor;
    ArtikelStamm^.Use(False);
  End;

  Procedure TOSEditor.SetState(AState: Word; Enable: Boolean);
  Begin
    TWindow.SetState(AState, Enable);
    If AState=sfSelected Then
    Case Enable Of
      True: EnableCommands(OSCmds);
      False: DisableCommands(OSCmds);
    End;
  End;

  Function TOSEditor.GetTitle(MaxSize: Integer): TTitleStr;
  Const OSStr= 'Ordersatz: ';
  Var F: String[12];
  Begin
    If OS^.FName<>nil Then F:=FileName(OS^.FName^) Else F:='Unbenannt';
    If MaxSize>Length(F)+Length(OSStr) Then
      GetTitle:=OSStr+F
    Else
      GetTitle:=F;
  End;

  Procedure TOSEditor.OSChanged;
  Begin
    Modified:=True;
    Message(@Self, evBroadcast, cmOSChanged, nil);
  End;

  Procedure TOSEditor.HandleEvent(Var Event: TEvent);
  Begin
    TWindow.HandleEvent(Event);
    { handle commands }
    If Event.What=evCommand Then
    Begin
      Case Event.Command Of
        cmWGruppen: If OS^.WGruppen^.Edit(OS) Then
          Begin
            Modified:=True;
            ModeDisplay^.Draw;
          End;
        cmStoreOS: If StoreOS(OS) Then
          Begin
            Modified:=False;
            Redraw;
          End;
        cmPrintOS: PrintOS(OS);
        Else Exit;
      End;
      ClearEvent(Event);
    End;
    { handle broadcast }
    If (Event.What=evBroadcast) Then
    Begin
      If (Event.Command=cmArtikelBase) And (Scroller^.Focused<>0) Then
      Begin
        If Mode=Ovr Then
        Begin
          OS^.Liste^[Scroller^.Focused]:=
            PArtikel(ArtikelStamm^.At(Event.InfoLong))^.DataRef;
        End Else
        Begin
          If Not OS^.InsertItem(Scroller^.Focused, PArtikel(ArtikelStamm^.At(Event.InfoLong))^.DataRef) Then
          Begin
            ClearEvent(Event);
            Exit;
          End;
        End;
        OSChanged;
        Scroller^.ScrollUp(False);
        Scroller^.Draw;
        ClearEvent(Event);
      End;
      If (Event.Command=cmLookforOS) And (OS^.FName<>nil) And
        (StrEqu(OS^.FName^, PString(Event.InfoPtr)^)) Then
        ClearEvent(Event);
    End;
    { handle keyboard }
    If Event.What=evKeyDown Then
    Begin
      Case Event.KeyCode Of
        kbEnter: ArtikelStamm^.Use(False);
        kbIns:
          Begin
            Boolean(Mode):=Not Boolean(Mode);
            ModeDisplay^.Draw;
          End;
        kbDel: If Scroller^.Focused>0 Then
          Begin
            If Mode=Ovr Then
              OS^.Liste^[Scroller^.Focused]:=0
            Else
              OS^.DeleteItem(Scroller^.Focused);
            OSChanged;
          End;
        Else Exit;
      End;
      ClearEvent(Event);
    End;
  End;

  Function TOSEditor.Valid(Command: Word): Boolean;
  Var Cmd: Word;
  Begin
    If Command = cmValid then Valid := TWindow.Valid(Command) Else
    Begin
      Valid := True;
      If Modified Then
      Begin
        If OS^.FName<>nil Then
          Cmd:=MessageBox('Sollen Änderungen an %s gesichert werden?', @OS^.FName,
            mfConfirmation+mfYesNoCancel)
        Else
          Cmd:=MessageBox('Sollen Änderungen gesichert werden?', nil,
            mfConfirmation+mfYesNoCancel);
        Case Cmd Of
          cmYes: Valid:=StoreOS(OS);
          cmNo: Modified:=False;
          cmCancel: Valid:=False;
        End;
      End;
    End;
  End;

  Procedure TOSEditor.SizeLimits(Var Min, Max: TPoint);
  Begin
    TWindow.SizeLimits(Min, Max);
    Inc(Min.X, 4);
  End;

  Destructor TOSEditor.Done;
  Begin
    Dispose(OS, Done);
    TWindow.Done;
  End;

{== Prozeduren/Funktionen =================================================}

  Procedure LoadOS;
  Var
    OS: POrdersatz;
    Strm: TBufStream;
    Dlg: PFileDialog;
    F: String;
    OSEditor: POSEditor;
  Begin
    OS:=nil;
    New(Dlg, Init('*.ORD', 'Ordersatz laden', '~N~ame', fdOpenButton, 101));
    If DeskTop^.ExecView(Dlg)<>cmCancel Then
    Begin
      Dlg^.GetFileName(F);
      OSEditor:=Message(DeskTop, evBroadcast, cmLookforOS, @F);
      If OSEditor=nil Then
      Begin
        Strm.Init(F, stOpen, 1024);
        If Strm.Status=stOK Then
        Begin
          OS:=POrdersatz(Strm.Get);
          OS^.FName:=NewStr(F);
          DeskTop^.Insert(New(POSEditor, Init(OS)));
        End Else
          MessageBox('Ordersatz konnte nicht geladen werden !', nil, mfError+mfOKButton);
        Strm.Done;
      End Else
        OSEditor^.Select;
    End;
    Dispose(Dlg, Done);
  End;

  Function StoreOS(OS: POrdersatz): Boolean;
  Var
    Dlg: PFileDialog;
    Strm: TBufStream;
    F: String;
    S: Integer;
  Begin
    StoreOS:=False;
    If OS^.FName=nil Then
    Begin
      New(Dlg, Init('*.ORD', 'Ordersatz sichern', '~N~ame', fdOKButton, 101));
      If DeskTop^.ExecView(Dlg)<>cmCancel Then
      Begin
        Dlg^.GetFileName(F);
        OS^.FName:=NewStr(F);
      End;
      Dispose(Dlg, Done);
      If Message(Desktop, evBroadcast, cmLookforOS, OS^.FName)<>nil Then
      Begin
        MessageBox('Der Ordersatz '+FileName(OS^.FName^)+' wird gerade editiert. Er darf nicht überschrieben werden!',
          nil, mfInformation+mfOkButton);
        DisposeStr(OS^.FName);
        OS^.FName:=nil;
      End;
      If (OS^.FName=nil) Or
        ((FileExists(OS^.FName^)) And (MessageBox('Ordersatz '+FileName(OS^.FName^)+
        ' überschreiben?', nil, mfConfirmation+mfYesNoCancel)<>cmYes)) Then Exit;
    End;
    Strm.Init(OS^.FName^, stCreate, 1024);
    Strm.Put(OS);
    S:=Strm.Status;
    Strm.Done;
    If Strm.Status<>stOK Then
      MessageBox('Ordersatz konnte nicht gesichert werden !', nil, mfError+mfOKButton)
    Else
      StoreOS:=True;
  End;

  Procedure PrintOS(OS: POrdersatz);
  Var
    N: String;
    Pg, C: Byte;
    E: TEvent;
    G: PGruppe;
    Ln, P, I: Integer;
    A: TArtikelRec;
    Seven: Boolean;
  Begin
    If OS^.Items=0 Then
    Begin
      MessageBox('Der Ordersatz enthält keine Artikel !', nil, mfInformation+mfOkButton);
      Exit;
    End;
    N:='';
    If InputBox('Ordersatz drucken', 'Bitte Bezeichnung angeben', N, 20)<>cmOk Then
      Exit;
    If Not InitPrinter(0) Then Exit;
    With OS^ Do
    Begin
      Seven:=(ParamStr(1)='7') Or (ParamStr(2)='7');
      Write(Lst, #27'D'#32#44#0);
      Pg:=0;
      P:=1;
      G:=nil;
      Writeln(Lst, ThickOn, 'Ordersatz: ', WideOn, N, WideOff, ThickOff);
      Ln:=2;
      Repeat
        SetSingleLineFeed;
        Inc(Pg);
        If Pg>1 Then
        Begin
          Writeln(Lst, #9#9'           Seite: ', Pg);
          Inc(Ln);
        End;
        Writeln(Lst, '      ARTIKEL'#9'GE INH'#9'MENGE');
        ResetLineFeed(0);
        Writeln(Lst, '--------------------------------------------------------------------------');
        Inc(Ln, 2);
        While (Ln<LPP) And (P<=Items) Do
        Begin
          If (G=nil) Or (P>G^.UpTo) Then
          Begin
            If Ln+3<LPP Then
            Begin
              WGruppen^.SearchGruppe(P, I);
              G:=PGruppe(WGruppen^.At(I));
              SetSingleLineFeed;
              Writeln(Lst);
              Write(Lst, ThickOn, WideOn);
              Writeln(Lst, '   ', G^.Name.GetStr);
              Write(Lst, ThickOff, WideOff);
              Writeln(Lst);
              ResetLineFeed(0);
              Inc(Ln, 3);
            End Else
              Ln:=LPP;
          End Else
          Begin
            Write(Lst, P:4, '  ');
            If Liste^[P]>0 Then
            Begin
              GetArtikelRec(Liste^[P], A);
              If Length(A.Name)>25 Then Write(Lst, #15);
              Write(Lst, A.Name, #18#9);
              Write(Lst, A.Menge);
            End Else
              Write(Lst, #9);
            Write(Lst, #9);
            Write(Lst, 'I___I___I___I___I___I___I');
            If Seven Then Write(Lst, '___I');
            Writeln(Lst, P:4);
            Inc(P);
            Inc(Ln);
          End;
          If (KeyPressed) And (ReadKey=#27) Then Exit;
        End;
        Write(Lst, #12);
        Ln:=0;
      Until P>Items;
    End;
  End;

End.