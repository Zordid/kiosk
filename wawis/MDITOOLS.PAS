{===========================================================}
{ Erweiterungen zu MDI Fenstern. Implementiert eine Toolbar }
{ und eine Statuszeile in OWL-Programmen                    }
{                                                           }
{ Letzte Änderung: 12.2.95                                  }
{                                                           }
{ (c) Copyright 1993-95 by Olaf Gottschalk Software         }
{===========================================================}

{$A+,B-,D+,F-,G+,I+,K+,L+,N-,P+,Q-,R-,S+,T-,V+,W-,X+,Y+}
{$R MDITOOLS.RES}
unit MDITools;
interface
  uses
    Objects, OWindows, WinTypes, WinProcs, Win31, Strings;

  const
    BorderPos= 100;

  {== ToolBar Typen ==}
  type
    TControlType= (Button, Separator);

    PBitmapDesc= ^TBitmapDesc;
    TBitmapDesc= object(TObject)
      Handle: array[0..1] of HBitmap;
      TypeOfControl: TControlType;
      Command: Word;
      MultipleBM: Boolean;
      HintText: PChar;
      Next: PBitmapDesc;
    end;

    PToolBar= ^TToolBar;
    TToolBar= object(TWindow)
      Select, Dim: TPoint;
      ButtonSize: Integer;
      ButtonPressed, MouseThere: Boolean;
      Tools: PBitmapDesc;
      NoOfBitmaps: Integer; 
      constructor Init(aParent: PWindowsObject;
        aTitle: PChar; X, Y: Integer; 
	TheTools: PBitmapDesc; aButtonSize, Rows: Integer);
      destructor Done; virtual;
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(var AWndClass: TWndClass); virtual;
      procedure Paint(PaintDC: HDC; var PaintInfo: TPaintStruct); virtual;
      procedure WMGetMinMaxInfo(var Msg: TMessage); virtual
        wm_First + wm_GetMinMaxInfo;
      procedure WMLButtonDown(var Msg: TMessage); virtual
        wm_First + wm_LButtonDown;
      procedure WMLButtonUp(var Msg: TMessage); virtual
        wm_First + wm_LButtonUp;
      procedure WMMouseMove(var Msg: TMessage); virtual
        wm_First + wm_MouseMove;
      function SelectedBitmap: PBitmapDesc;
    end;

  {== Statuszeilen Typen ==}
  type
    THint= array[0..79] of Char;

    PStatusWindow= ^TStatusWindow;
    TStatusWindow= object(TWindow)
      TheHint,
      MenuString: THint;
      MenuActive: Boolean;
      LineNo, MaxNo: LongInt;
      BMBackground: HBitmap;
      Font: HFont;
      constructor Init(AParent: PWindowsObject);
      destructor Done; virtual;
      procedure Paint(PaintDC: HDC; var PaintInfo: TPaintStruct); virtual;
      procedure WMSize(var Msg: TMessage); virtual wm_First + wm_Size;
      procedure BlastStatusLine(PaintDC: HDC);
    end;

  {== Extended MDI Fenster ==}
  type
    PExtMDIWindow= ^TExtMDIWindow;
    TExtMDIWindow= object(TMDIWindow)
      ToolBar: PToolBar;
      StatusLine: PStatusWindow;
      ToolBarSpace, StatusLineSpace: Integer;
      constructor Init(ATitle: PChar; AMenu: HMenu); 
      procedure InitToolBar; virtual;
      procedure InitStatusLine; virtual;
      procedure SetupWindow; virtual;
      procedure Paint(PaintDC: HDC; var PaintInfo: TPaintStruct); virtual;
      procedure WMSize(var Msg: TMessage); virtual wm_First+wm_Size;
      procedure WMMenuSelect(var Msg: TMessage); virtual wm_First+wm_MenuSelect;
      destructor Done; virtual;
      { neue Funktionen }
      Procedure DisplayHint(Hint: PChar);
      procedure DisplayMenuHint(Hint: PChar);
      Procedure DisplayLine(Line,Max: LongInt);
      Procedure GetMenuHint(var Msg: TMessage; var Hint: THint); virtual;
    End;

  {== Local menu procedure ==}
  const
    lm_MenuHandle= $1;  lm_MenuName= $2;

  procedure PopupMenu(ParentWin: HWnd; P: TPoint; Flag: Word; Menu: PChar);
  procedure DrawBitmap(DC: HDC; BitMap: HBitmap; X, Y: Integer);
  function NewButton(RezName: PChar; aCommand: Word; aHint: PChar; aNext: PBitmapDesc): PBitmapDesc;
  function NewMultiButton(RezNumber: Word; aCommand: Word; aHint: PChar; aNext: PBitmapDesc): PBitmapDesc;
  function NewSeparator(aNext: PBitmapDesc): PBitmapDesc;
  procedure DisplayHint(Hint: PChar);
  procedure DisplayLine(Line, Max: LongInt);

implementation

{== Toolbar Objekte ==}

  { TToolBar }
  constructor TToolBar.Init(aParent: PWindowsObject; aTitle: PChar;
    X, Y: Integer; TheTools: PBitmapDesc; aButtonSize, Rows: Integer);
  var P: PBitmapDesc;
  begin
    inherited Init(aParent, aTitle);
    SetFlags(wb_MDIChild, False);
    Tools:=TheTools;
    ButtonPressed := False;
    Select.X := -1;
    Select.Y := -1;
    ButtonSize:=aButtonSize;
    P:=Tools;
    NoOfBitmaps:=0;
    while P<>nil do
    begin
      Inc(NoOfBitmaps);
      P:=P^.Next;
    end;  	
    if Rows<0 then
    begin
      Dim.X:=-Rows;
      Dim.Y:=NoOfBitmaps div Dim.X;
      if Dim.X*Dim.Y<NoOfBitmaps then Inc(Dim.Y);
    end else
    begin
      Dim.Y:=Rows;
      Dim.X:=NoOfBitmaps div Dim.Y;
      if Dim.X*Dim.Y<NoOfBitmaps then Inc(Dim.X);
    end;
    if aTitle=nil then
    begin
      Attr.Style := ws_Child or ws_Visible;
      Attr.X := X;
      Attr.Y := Y;
    end;
    Attr.W := ButtonSize*Dim.X;
    Attr.H := (ButtonSize-1)*Dim.Y+(21*Ord(aTitle<>nil));
  end;

  destructor TToolBar.Done;
    procedure DisposeDesc(P: PBitmapDesc);
    begin
      if P^.Next<>nil then DisposeDesc(P^.Next);
      if P^.Handle[0]<>0 then DeleteObject(P^.Handle[0]);
      if P^.Handle[1]<>0 then DeleteObject(P^.Handle[1]);
      Dispose(P);
    end;
  begin
    DisposeDesc(Tools);
    inherited Done;
  end;

  function TToolBar.GetClassName: PChar;
  begin
    GetClassName:='TP_ToolBar';
  end;

  procedure TToolBar.GetWindowClass(var AWndClass: TWndClass);
  begin
    inherited GetWindowClass(AWndClass);
    AWndClass.hbrBackground:=GetStockObject(LTGRAY_BRUSH);
  end;

  procedure TToolBar.WMMouseMove(var Msg: TMessage);
  var
    P: TPoint;
    M, N: Boolean;
  begin
    if ButtonPressed then
    begin
      P := TPoint(Msg.LParam);
      N:=(P.X<0) or (P.Y<0);
      P.X := P.X div ButtonSize;
      P.Y := P.Y div ButtonSize;
      M:=(P.X=Select.X) and (P.Y=Select.Y) and (not N);
      if M<>MouseThere then InvalidateRect(hWindow, nil, False);
      MouseThere:=M;
    end;
  end;

  procedure TToolBar.WMLButtonUp(var Msg: TMessage);
  var
    BM: PBitMapDesc;
  begin
    if ButtonPressed then
    begin
      ReleaseCapture;
      InvalidateRect(hWindow, nil, False);
      if MouseThere then
      begin
	BM:=SelectedBitmap;
        if BM<>nil then
        begin
          PExtMDIWindow(Parent)^.DisplayMenuHint(nil);
          PostMessage(Parent^.HWindow, wm_Command, BM^.Command, 0);
        end;
      end;
      ButtonPressed := False;
      MouseThere := False;
      Select.X := -1;
      Select.Y := -1;
    end;
  end;

  procedure TToolBar.WMLButtonDown(var Msg: TMessage);
  begin
    Select.X := Msg.lParamLo div ButtonSize;
    Select.Y := Msg.lParamHi div ButtonSize;
    if SelectedBitmap<>nil then
    begin
      InvalidateRect(HWindow, nil, False);
      ButtonPressed := True;
      MouseThere := True;
      SetCapture(hWindow);
    end;
  end;

  function TToolBar.SelectedBitmap: PBitmapDesc;
  var
    I: Integer;
    P: PBitmapDesc;
  begin
    if Select.X<>-1 then
    begin
      I := (Select.X) + (Select.Y) * Dim.X;
      P:=Tools;
      while (I>0) and (P<>nil) do
      begin
        P:=P^.Next;
        Dec(I);
      end;
      if (P<>nil) and (P^.TypeOfControl=Separator) then P:=nil;
    end else
      P:=nil;
    SelectedBitmap:=P;
  end;

  Procedure TToolBar.Paint(PaintDC: HDC; Var PaintInfo: TPaintStruct);
  Var
    X, Y: Integer;
    P, S: PBitmapDesc;
    H: HBitmap;
    Hint: THint;
  Begin
    P:=Tools;
    S:=SelectedBitmap;
    For Y:=0 To Dim.Y-1 Do
      For X:=0 To Dim.X-1 Do
	If P<>nil Then
	Begin
          if P^.TypeOfControl<>Separator then
          begin
            H:=P^.Handle[0];
            If (P^.MultipleBM) And MouseThere Then H:=P^.Handle[1];
            If H<>0 Then DrawBitMap(PaintDC, H, ButtonSize*X, ButtonSize*Y);
          end;
          MoveTo(PaintDC, ButtonSize*(X+1)-1, ButtonSize*Y);
          LineTo(PaintDC, ButtonSize*(X+1)-1, ButtonSize*(Y+1));
	  P:=P^.Next;
	End;
    If S<>nil Then
    Begin
      If MouseThere Then
      Begin
        If Not S^.MultipleBM Then
          PatBlt(PaintDC, Select.X*ButtonSize, Select.Y*ButtonSize, ButtonSize-1, ButtonSize, PatInvert);
        If HiWord(LongInt(S^.HintText))=0 Then
        Begin
          LoadString(hInstance, LoWord(LongInt(S^.HintText)), Hint, SizeOf(Hint));
          PExtMDIWindow(Parent)^.DisplayMenuHint(Hint);
        End Else    
          PExtMDIWindow(Parent)^.DisplayMenuHint(S^.HintText)
      End Else
        PExtMDIWindow(Parent)^.DisplayMenuHint(nil);
    End;
  End;

  Procedure TToolBar.WMGetMinMaxInfo(Var Msg: TMessage);
  Type
    PointArray = Array[0..4] Of TPoint;
    PSizeInfo = ^PointArray;
  Begin
    PSizeInfo(Msg.LParam)^[3].X := ButtonSize*Dim.X+2;
  End;

{== Stauszeilen Objekt ==}

  { TStatusWindow }
  Constructor TStatusWindow.Init(AParent: PWindowsObject);
  Begin
    inherited Init(AParent, nil);
    SetFlags(wb_MDIChild, False);
    Attr.Style:=ws_Child;
    Attr.W:=1;
    BMBackground := 0;
    LineNo := 0;
    FillChar(TheHint, SizeOf(TheHint), 0);
    FillChar(MenuString, SizeOf(MenuString), 0);
    MenuActive := False;
    Font:=0;
  End;

  Destructor TStatusWindow.Done;
  Begin
    DeleteObject(Font);
    DeleteObject(BMBackground);
    inherited Done;
  End;

  Procedure TStatusWindow.WMSize(Var Msg: TMessage);
  Var
    DC: HDC;
    SrcDC,
    DestDC: HDC;
    BM, BMDivide: HBitmap;
    B: TBitmap;
    OldSrc,
    OldDest: HBitmap;
    Rect: TRect;
    Org: TPoint;
  Begin
    inherited WMSize(Msg);
    GetClientRect(HWindow, Rect);
    InvalidateRect(HWindow, nil, False);
    DC := GetDC(HWindow);
    SrcDC := CreateCompatibleDC(DC);
    DestDC := CreateCompatibleDC(DC);
    ReleaseDC(HWindow, DC);

    BM := LoadBitmap(HInstance, 'BMBackground1');
    OldSrc := SelectObject(SrcDC, BM);
    If BMBackground <> 0 Then DeleteObject(BMBackground);
    BMBackground := CreateCompatibleBitmap(DC, Rect.Right, 20);
    OldDest := SelectObject(DestDC, BMBackground);
    BitBlt(DestDC, 0, 0, 5, 20, SrcDC, 0, 0, SrcCopy);
    StretchBlt(DestDC, 5, 0, Rect.Right - 5, 20,
	       SrcDC, 6, 0, 20, 20, SrcCopy);
    BitBlt(DestDC, Rect.Right - 5, 0, 5, 20, SrcDC, 59, 0, SrcCopy);
    BMDivide:=LoadBitmap(hInstance, 'BMDivide1');
    SelectObject(SrcDC, BMDivide);
    BitBlt(DestDC, BorderPos, 0, 10, 20, SrcDC, 0, 0, SrcCopy);
    GetObject(BM, SizeOf(B), @B);
    DeleteObject(Font);
    Font:=CreateFont(
      B.bmHeight-4, 0, 0, 0,
      fw_Bold, 0, 0, 0,
      Ansi_CharSet, Out_Default_Precis, Clip_Default_Precis,
      Proof_Quality, Variable_Pitch or ff_Swiss, nil);
    SelectObject(SrcDC, OldSrc);
    SelectObject(DestDC, OldDest);
    DeleteDC(SrcDC);
    DeleteDC(DestDC);
    DeleteObject(BM);
    DeleteObject(BMDivide);
  End;

  Procedure TStatusWindow.BlastStatusLine(PaintDC: HDC);
  Var
    MemDC, BkDC: HDC;
    ClientRect, R: TRect;
    MemBM, OldBM, OldBkBM: HBitmap;
    OldFont: HFont;
    A: Array[0..10] Of Char;
  Begin
    GetClientRect(hWindow, ClientRect);
    MemDC := CreateCompatibleDC(PaintDC);
    With ClientRect Do
      MemBM := CreateCompatibleBitmap(PaintDC, Right-Left, 22);
    OldBM := SelectObject(MemDC, MemBM);

    BkDC := CreateCompatibleDC(PaintDC);
    OldBkBM := SelectObject(BkDC, BMBackground);
    With ClientRect Do
      BitBlt(MemDC, 0, 1, Right-Left, 20, BkDC, 0, 0, SrcCopy);
    SelectObject(BkDC, OldBkBM);
    DeleteDC(BkDC);

    SetBKMode(MemDC, Transparent);
    OldFont:=SelectObject(MemDC, Font);
    If MenuActive Then
      TextOut(MemDC, BorderPos+12, 3, MenuString, StrLen(MenuString))
    Else
      If TheHint <> #0 Then
	TextOut(MemDC, BorderPos+12, 3, TheHint, StrLen(TheHint));
    If LineNo <> 0 Then
    Begin
      WVSPrintf(A, '%ld/%ld', LineNo);
      SetRect(R, 3, 3, BorderPos-3, 17);
      DrawText(MemDC, A, StrLen(A), R, DT_CENTER);
    End;
    MoveTo(MemDC, 0, 0);
    LineTo(MemDC, ClientRect.Right, 0);

    With ClientRect Do
      BitBlt(PaintDC, 0, 0, Right-Left, 21, MemDC, 0, 0, SrcCopy);

    SelectObject(MemDC, OldFont);
    SelectObject(MemDC, OldBM);
    DeleteObject(MemBM);
    DeleteDC(MemDC);
  End;

  Procedure TStatusWindow.Paint(PaintDC: HDC; Var PaintInfo: TPaintStruct);
  Begin
    BlastStatusLine(PaintDC);
  End;

{== Extended MDI Fenster Objekt ==}

  { TExtMDIWindow }
  Constructor TExtMDIWindow.Init(ATitle: PChar; AMenu: HMenu);
  Begin
    inherited Init(ATitle, AMenu);
    ToolBar:=nil;
    StatusLine:=nil;
    ToolBarSpace:=0;
    StatusLineSpace:=22;
  End;

  Procedure TExtMDIWindow.InitToolBar;
  Begin
  End;

  Procedure TExtMDIWindow.InitStatusLine;
  Begin
    If StatusLineSpace<>0 Then
      StatusLine:=New(PStatusWindow, Init(@Self));
  End;

  Procedure TExtMDIWindow.SetupWindow;
  Begin
    inherited SetupWindow;
    InitToolBar;
    InitStatusLine;
    If Application^.MakeWindow(Toolbar)<>nil Then
      ToolBar^.Show(sw_Normal);
    If Application^.MakeWindow(StatusLine)<>nil Then
      StatusLine^.Show(sw_Normal);
  End;

  Procedure TExtMDIWindow.Paint(PaintDC: HDC; Var PaintInfo: TPaintStruct);
  Var
    R: TRect;
    Rgn: HRgn;
    B: HBrush;
  Begin
    If ToolBarSpace>0 Then
    Begin
      GetClientRect(hWindow, R);
      MoveTo(PaintDC, 0, ToolBarSpace-1);
      LineTo(PaintDC, R.Right, ToolBarSpace-1);
      Rgn:=CreateRectRgn(0, 0, R.Right, ToolBarSpace-1);
      B:=SelectObject(PaintDC, GetStockObject(LTGRAY_BRUSH));
      PaintRgn(PaintDC, Rgn);
      SelectObject(PaintDC, B);
      DeleteObject(Rgn);
    End;
  End;

  Procedure TExtMDIWindow.WMSize(Var Msg: TMessage);
  Begin
    If (ClientWnd<>nil) And (ClientWnd^.hWindow<>0) Then
      MoveWindow(ClientWnd^.hWindow, 0, ToolBarSpace, Msg.LParamLo,
	Msg.LParamHi-(ToolBarSpace+StatusLineSpace)+1, True)
    Else
      inherited WMSize(Msg);
    If (StatusLine<>nil) And (StatusLine^.hWindow<>0) Then
      MoveWindow(StatusLine^.hWindow, 0, Msg.LParamHi-StatusLineSpace+1,
	Msg.LParamLo, Msg.LParamHi, True);
  End;

  Procedure TExtMDIWindow.WMMenuSelect(Var Msg: TMessage);
  Begin
    If StatusLine<>nil Then
    Begin
      StatusLine^.MenuActive:=Not
        ((Msg.LParamLo = $FFFF) AND (Msg.LParamHi = 0));
      If (Msg.LParamHi = 0) Or (Msg.LParamLo And mf_Separator=mf_Separator) Then
        StatusLine^.MenuString[0]:=#0
      Else
        GetMenuHint(Msg, StatusLine^.MenuString);
      InvalidateRect(StatusLine^.hWindow, nil, False);
    End;
  End;

  Destructor TExtMDIWindow.Done;
  Begin
    If ToolBar<>nil Then Dispose(ToolBar, Done);
    If StatusLine<>nil Then Dispose(StatusLine, Done);
    inherited Done;
  End;

  Procedure TExtMDIWindow.DisplayHint(Hint: PChar);
  Begin
    If StatusLine=nil Then Exit;
    If Hint<>nil Then
      StrCopy(StatusLine^.TheHint, Hint)
    Else
      StatusLine^.TheHint[0]:=#0;
    If StatusLine^.MenuActive Then Exit;
    InvalidateRect(StatusLine^.HWindow, nil, False);
    UpdateWindow(StatusLine^.HWindow);
  End;

  procedure TExtMDIWindow.DisplayMenuHint(Hint: PChar);
  begin
    if Hint<>nil then
      StrCopy(StatusLine^.MenuString, Hint)
    else
      StatusLine^.MenuString[0]:=#0;
    StatusLine^.MenuActive:=Hint<>nil;
    InvalidateRect(StatusLine^.hWindow, nil, False);
    UpdateWindow(StatusLine^.hWindow);
  end;

  Procedure TExtMDIWindow.DisplayLine(Line, Max: LongInt);
  Begin
    If StatusLine=nil Then Exit;
    StatusLine^.LineNo:=Line;
    StatusLine^.MaxNo:=Max;
    InvalidateRect(StatusLine^.hWindow, nil, False);
    UpdateWindow(StatusLine^.hWindow);
  End;

  Procedure TExtMDIWindow.GetMenuHint(Var Msg: TMessage; Var Hint: THint);
  Begin
    StrCopy(Hint, 'Menü aktiv');
  End;

{== Prozeduren ==}

  Procedure DisplayHint(Hint: PChar);
  Begin
    PExtMDIWindow(Application^.MainWindow)^.DisplayHint(Hint);
  End;

  Procedure DisplayLine(Line, Max: LongInt);
  Begin
    PExtMDIWindow(Application^.MainWindow)^.DisplayLine(Line, Max);
  End;

  Function NewButton(RezName: PChar; aCommand: Word;
    aHint: PChar; aNext: PBitmapDesc): PBitmapDesc;
  Var P: PBitmapDesc;
  Begin
    New(P);
    With P^ Do
    Begin
      TypeOfControl:=Button;
      Handle[0]:=LoadBitmap(hInstance, RezName);
      Handle[1]:=0;
      Command:=aCommand;
      MultipleBM:=False;
      HintText:=aHint;
      Next:=aNext;
    End;
    NewButton:=P;
  End;

  Function NewMultiButton(RezNumber: Word; aCommand: Word;
    aHint: PChar; aNext: PBitmapDesc): PBitmapDesc;
  Var P: PBitmapDesc;
  Begin
    New(P);
    With P^ Do
    Begin
      TypeOfControl:=Button;
      Handle[0]:=LoadBitmap(hInstance, PChar(RezNumber));
      Handle[1]:=LoadBitmap(hInstance, PChar(RezNumber+1));
      Command:=aCommand;
      MultipleBM:=True;
      HintText:=aHint;
      Next:=aNext;       
    End;
    NewMultiButton:=P;
  End;

  Function NewSeparator(aNext: PBitmapDesc): PBitmapDesc;
  Var P: PBitmapDesc;
  Begin
    New(P);
    FillChar(P^, SizeOf(P^), 0);
    P^.TypeOfControl:=Separator;
    P^.Next:=aNext;
    NewSeparator:=P;
  End;

  Procedure DrawBitmap(DC: HDC; BitMap: HBitmap; X, Y: Integer);
  Var
    MemDC: HDC;
    B: TBitmap;
    Size, Origin: TPoint;
  Begin
    MemDC := CreateCompatibleDC(DC);
    SelectObject(MemDC, Bitmap);
    SetMapMode(MemDC, GetMapMode(DC));
    GetObject(Bitmap, SizeOf(TBitmap), @B);
    Size.X := B.bmWidth;
    Size.Y := B.bmHeight;
    DPtoLP(DC, Size, 1);
    Origin.X := 0;
    Origin.Y := 0;
    DPtoLP(MemDC, Origin, 1);
    BitBlt(DC, X, Y, Size.X, Size.Y, MemDC, Origin.X, Origin.Y, SrcCopy);
    DeleteDC(MemDC);
  End;

  Procedure PopupMenu(ParentWin: HWnd; P: TPoint; Flag: Word; Menu: PChar);
  Var
    hmMenu, hmPopupMenu: HMenu;
  Begin
    If Flag=lm_MenuHandle Then
      hmPopupMenu:=hMenu(Menu)
    Else
    Begin
      hmMenu:=LoadMenu(hInstance, Menu);
      hmPopupMenu:=GetSubMenu(hmMenu, 0);
    End;
    TrackPopupMenu(hmPopupMenu, 0, P.x, P.y, 0, ParentWin, nil);
    If Flag=lm_MenuName Then DestroyMenu(hmMenu)
    Else DestroyMenu(hmPopupMenu);
  End;

End.