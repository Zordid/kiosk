unit ListWin;
interface
  uses
    Objects, OWindows,
    WinTypes, WinProcs, Strings, BTPWin, MDITools,
    Globals, Communication, Dialogs;

  const
    XOffset= 30;

  type
    TSelectionList= object(TSortedCollection)
      constructor Init;
      destructor Done; virtual;
      function Compare(Key1, Key2: Pointer): Integer; virtual;
      procedure SetSelection(Line: Integer; S: Boolean);
      function GetSelection(Line: Integer): Boolean;
      procedure InsertLine(Line: Integer);
      procedure DeleteLine(Line: Integer);
    end;

    PListItem= ^TListItem;
    TListItem= object(TObject)
      FieldNr: Byte;
      Width: Word;
      Title: PChar;
      RightAlign: Boolean;
      destructor Done; virtual;
    end;

    PListViewer= ^TListViewer;
    TListViewer= object(TWindow)
      LocalMenu: Word;
      Range, Pos, CArea: TPoint;
      Visible: Integer;
      ListDesc: TCollection;
      Selected: TSelectionList;
      { OWL Methoden }
      constructor Init(AParent: PWindowsObject);
      destructor Done; virtual;
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(Var AWndClass: TWndClass); virtual;
      procedure Paint(PaintDC: HDC; Var PaintInfo: TPaintStruct); virtual;
      { eigene Methoden }
      procedure AddListCol(AFieldNr: Byte; AWidth: Word; ATitle: PChar; ARight: Boolean);
      function ViewFocused: Boolean;
      procedure RefreshLines;
      procedure RefreshTotal;
      procedure SetScrollBars;
      procedure SetFocused(F: Integer); virtual;
      function GetFocused: Integer;
      procedure TrackMouse(Var Msg: TMessage);
      procedure MakeExportColl(var Buf: TExportColl; All, Oem: Boolean; Ch: Char);
      { abstrakte Methoden }
      function GetData(Line: Integer): Pointer; virtual;
      function GetString(Rec: Pointer; Field: Byte): PChar; virtual;
      { Windows Messages }
      procedure WMSetFocus(Var Msg: TMessage); virtual wm_First+wm_SetFocus;
      procedure WMSize(Var Msg: TMessage); virtual wm_First+wm_Size;
      procedure WMHScroll(Var Msg: TMessage); virtual wm_First+wm_HScroll;
      procedure WMVScroll(Var Msg: TMessage); virtual wm_First+wm_VScroll;
      procedure WMLButtonDown(Var Msg: TMessage); virtual wm_First+wm_LButtonDown;
      procedure WMLButtonUp(Var Msg: TMessage); virtual wm_First+wm_LButtonUp;
      procedure WMLButtonDblClk(Var Msg: TMessage); virtual wm_First+wm_LButtonDblClk;
      procedure WMMouseMove(Var Msg: TMessage); virtual wm_First+wm_MouseMove;
      procedure WMKeyDown(Var Msg: TMessage); virtual wm_First+wm_KeyDown;
      procedure WMLocalMenu(var Msg: TMessage); virtual wm_First+wm_LocalMenu;
      procedure WMChar(var Msg: TMessage); virtual wm_First+wm_Char;
      { eigene Messages }
      {
      procedure IDMLocalMenu(Var Msg: TMessage); virtual cm_First+IDM_LOCALMENU;
      }
      procedure IDMSelectAll(Var Msg: TMessage); virtual cm_First+IDM_SELECTALL;
      procedure IDMSelectNone(Var Msg: TMessage); virtual cm_First+IDM_SELECTNONE;
      procedure IDMInvertSelection(Var Msg: TMessage); virtual cm_First+IDM_INVERTSELECTION;
      procedure IDMExport(var Msg: TMessage); virtual cm_First+idm_Export;
     private
      Font: HFont;
      MouseDown: Boolean;
      Focused: Integer;
      bmHeader, bmLine: HBitmap;
      BkColor: TColorRef;
      BitmapDC: HDC;
      HScrollBar: Boolean;
      Inverted: Byte;
      procedure InitBitmaps;
      procedure PaintLine(DC: HDC; L: Byte);
      procedure InvertLine(DC: HDC; L: Byte);
    end;

    PListWindow= ^TListWindow;
    TListWindow= Object(TWindow)
      Viewer: PListViewer;
      Destructor Done; virtual;
      Function GetClassName: PChar; virtual;
      Procedure GetWindowClass(Var AWndClass: TWndClass); virtual;
      Procedure WMSize(Var Msg: TMessage); virtual wm_First+wm_Size;
      Procedure WMSetFocus(Var Msg: TMessage); virtual wm_First+wm_SetFocus;
      procedure WMInitMenu(var Msg: TMessage); virtual wm_First+wm_InitMenu;
      procedure WMLocalMenu(var Msg: TMessage); virtual wm_First+wm_LocalMenu;
    End;
      
Implementation

  Destructor TListItem.Done;
  Begin
    StrDispose(Title);
  End;

{
** == TSelectionList (Object) ==
**
** stores the selected records' numbers
**
}
  Constructor TSelectionList.Init;
  Begin
    TCollection.Init(100, 100);
  End;

  Destructor TSelectionList.Done;
  Begin
    DeleteAll;
    TSortedCollection.Done;
  End;

  Function TSelectionList.Compare(Key1, Key2: Pointer): Integer;
  Begin
    If LongInt(Key1)<LongInt(Key2) Then Compare:=-1 Else
      If LongInt(Key1)>LongInt(Key2) Then Compare:=+1 Else
        Compare:=0;
  End;

  Procedure TSelectionList.SetSelection(Line: Integer; S: Boolean);
  Var I: Integer;
  Begin
    If Search(Pointer(Line), I) Then
    Begin
      If Not S Then AtDelete(I);
    End Else
    Begin
      If S Then AtInsert(I, Pointer(Line));
    End;
  End;

  Function TSelectionList.GetSelection(Line: Integer): Boolean;
  Var I: Integer;
  Begin
    GetSelection:=Search(Pointer(Line), I);
  End;

  procedure TSelectionList.InsertLine(Line: Integer);
  var i: Integer;
  begin
    Search(Pointer(Line), i);
    while i<=Count do
    begin
      Inc(Integer(Items^[i]));
      inc(i);
    end;   
  end;

  procedure TSelectionList.DeleteLine(Line: Integer);
  var i: Integer;
  begin
    if Search(Pointer(Line), i) then AtDelete(i);
    while i<=Count do
    begin
      Dec(Integer(Items^[i]));
      inc(i);
    end;    
  end;

{
** == TListViewer (Object) ==
**
** implements a complete listing object
**
}
  Constructor TListViewer.Init(AParent: PWindowsObject);
  Begin
    TWindow.Init(AParent, nil);
    Attr.Style:=ws_Child Or ws_Visible Or ws_VScroll Or ws_HScroll;
    bmLine:=0;
    bmHeader:=0;
    HScrollBar:=True;
    LongInt(Range):=0;
    LongInt(Pos):=0;
    LocalMenu:=0;
    Inverted:=0;
    Focused:=-1;
    ListDesc.Init(5, 5);
    MouseDown:=False;
    Selected.Init;
  End;

  Destructor TListViewer.Done;
  Var I: Byte;
  Begin
    Selected.Done;
    ListDesc.Done;
    DeleteObject(bmHeader);
    DeleteObject(bmLine);
    TWindow.Done;
  End;

  Function TListViewer.GetClassName: PChar;
  Begin
    GetClassName:='WAWIS:ListViewer';
  End;

  Procedure TListViewer.GetWindowClass(Var AWndClass: TWndClass);
  Begin
    TWindow.GetWindowClass(AWndClass);
    With AWndClass Do
    Begin
      Style:=CS_DBLCLKS;
      hbrBackground:=GetStockObject(LTGRAY_BRUSH);
      hCursor:=0;
    End;
  End;

  Function TListViewer.ViewFocused: Boolean;
  Begin
    ViewFocused:=True;
    If Focused=-1 Then Exit;
    If (Focused<Pos.Y) Or (Focused>Pos.Y+Visible-2) Then
    Begin
      Pos.Y:=Focused-Visible Div 2;
      If Pos.Y<0 Then Pos.Y:=0;
      SetScrollBars;
    End Else
      ViewFocused:=False;
  End;

  Procedure TListViewer.SetFocused(F: Integer);
  Var
    DC: HDC;
    Old: Integer;
  Begin
    Old:=Focused;
    Focused:=F;
    If Old<>Focused Then
    Begin
      DC:=GetDC(hWindow);
      If Inverted<>0 Then InvertLine(DC, Inverted);
      If (Focused>=Pos.Y) And (Focused<Pos.Y+Visible) Then InvertLine(DC, Focused-Pos.Y+1);
      ReleaseDC(hWindow, DC);
    End;
    DisplayLine(F+1, Range.Y);
  End;

  Function TListViewer.GetFocused: Integer;
  Begin
    GetFocused:=Focused;
  End;

  Procedure TListViewer.AddListCol(AFieldNr: Byte; AWidth: Word; ATitle: PChar; ARight: Boolean);
  Var L: PListItem;
  Begin
    New(L, Init);
    With L^ Do
    Begin
      FieldNr:=AFieldNr;
      Width:=AWidth;
      Title:=StrNew(ATitle);
      RightAlign:=ARight;
    End;
    ListDesc.Insert(L);
  End;

  Procedure TListViewer.InitBitmaps;
  Var
    Col: Byte;
    XPos: Word;
    ClientDC, HeaderDC, LineDC: HDC;
    BoldFont, OldFont: HFont;
    R: TRect;
    L: PListItem;
  Begin
    { alte Bitmaps löschen... }
    DeleteObject(bmHeader);
    DeleteObject(bmLine);
    { kompatible DCs erstellen }
    ClientDC:=GetDC(hWindow);
    BitmapDC:=CreateCompatibleDC(ClientDC);
    HeaderDC:=CreateCompatibleDC(ClientDC);
    LineDC:=CreateCompatibleDC(ClientDC);
    { Bitmap selektieren }
    SelectObject(BitmapDC, bmListWin);
    { Header- und Zeilenbitmap erstellen }
    bmHeader:=CreateCompatibleBitmap(ClientDC, CArea.X, 20);
    bmLine:=CreateCompatibleBitmap(ClientDC, CArea.X, 20);
    SelectObject(HeaderDC, bmHeader);
    SelectObject(LineDC, bmLine);
    SetBkMode(HeaderDC, Transparent);
    { Hintergrund malen }
    StretchBlt(HeaderDC, 0, 0, CArea.X, 20, BitmapDC, 3, 0, 3, 20, SrcCopy);
    SelectObject(LineDC, GetStockObject(LTGRAY_BRUSH));
    PatBlt(LineDC, 0, 0, CArea.X, 20, PatCopy);
    BkColor:=GetPixel(LineDC, 0, 0);
    SelectObject(LineDC, GetStockObject(NULL_BRUSH));
    Col:=Pos.X;
    XPos:=XOffset;
    lfntListWin.lfWeight:=fw_Bold;
    BoldFont:=CreateFontIndirect(lfntListWin);
    OldFont:=SelectObject(HeaderDC, BoldFont);
    Repeat
      { Titel ausgeben }
      L:=PListItem(ListDesc.At(Col));
      If L^.Title<>nil Then
      Begin
        SetRect(R, XPos, 0, XPos+L^.Width+3, 20);
        ExtTextOut(HeaderDC, XPos, 1, ETO_CLIPPED, @R, L^.Title, StrLen(L^.Title), nil);
      End;
      Inc(XPos, L^.Width+5);
      { Begrenzung zeichnen }
      BitBlt(HeaderDC, XPos, 0, 3, 20, BitmapDC, 6, 0, SrcCopy);
      BitBlt(LineDC, XPos, 0, 3, 20, BitmapDC, 0, 0, SrcCopy);
      Inc(XPos, 5);
      Inc(Col);
    Until (Col=Range.X) Or (XPos>=CArea.X);
    DeleteObject(SelectObject(HeaderDC, OldFont));
    HScrollBar:=XPos>CArea.X; 
    { Aufräumen }
    DeleteDC(BitmapDC);
    DeleteDC(HeaderDC);
    DeleteDC(LineDC);
    ReleaseDC(HWindow, ClientDC);
  End;

  Procedure TListViewer.PaintLine(DC: HDC; L: Byte);
  Var
    Col: Byte;
    XPos: Word;
    R: TRect;
    P: PChar;
    Rec: Pointer;
    LI: PListItem;
    OldFont: HFont;
  Begin
    If Inverted=L Then InvertLine(DC, L);
    If L+Pos.Y>Range.Y Then Rec:=nil Else Rec:=GetData(L+Pos.Y-1);
    Col:=Pos.X;
    If Selected.GetSelection(L+Pos.Y-1) Then
    Begin
      BitmapDC:=CreateCompatibleDC(DC);
      SelectObject(BitmapDC, bmSelected);
      BitBlt(DC, 5, L*20, 20, 20, BitmapDC, 0, 0, SrcCopy);
      DeleteDC(BitmapDC);
    End Else
    Begin
      SelectObject(DC, GetStockObject(LTGRAY_BRUSH));
      PatBlt(DC, 5, L*20, 20, 20, PatCopy);
    End;
    XPos:=XOffset;
    OldFont:=SelectObject(DC, fntListWin);
    Repeat
      LI:=PListItem(ListDesc.At(Col));
      P:=GetString(Rec, LI^.FieldNr);
      SetRect(R, XPos, L*20, XPos+LI^.Width+3, (L+1)*20);
      If P<>nil Then
      Begin
        If LI^.RightAlign Then
        Begin
          SetTextAlign(DC, TA_RIGHT);
          ExtTextOut(DC, XPos+LI^.Width, L*20+2, ETO_CLIPPED Or ETO_OPAQUE, @R, P, StrLen(P), nil);
          SetTextAlign(DC, TA_LEFT);
        End Else
          ExtTextOut(DC, XPos, L*20+2, ETO_CLIPPED Or ETO_OPAQUE, @R, P, StrLen(P), nil);
      End Else
        FillRect(DC, R, GetStockObject(LTGRAY_BRUSH));
      Inc(XPos, LI^.Width+10);
      Inc(Col);
    Until (Col=Range.X) Or (XPos>=CArea.X);
    If L+Pos.Y-1=Focused Then InvertLine(DC, L);
    SelectObject(DC, OldFont);
  End;

  Procedure TListViewer.InvertLine(DC: HDC; L: Byte);
  Var R: TRect;
  Begin
    SetRect(R, XOffset, (L*20)+1, CArea.X, (L*20)+19);
    InvertRect(DC, R);
    If Inverted<>L Then Inverted:=L Else Inverted:=0;
  End;

  Procedure TListViewer.Paint(PaintDC: HDC; Var PaintInfo: TPaintStruct);
  Var
    L: Byte;
    TempDC: HDC;
  Begin
    Inverted:=0;
    TempDC:=CreateCompatibleDC(PaintDC);
    SelectObject(TempDC, bmHeader);
    BitBlt(PaintDC, 0, 0, CArea.X, 20, TempDC, 0, 0, SrcCopy);
    SelectObject(TempDC, bmLine);
    SetBkColor(PaintDC, BkColor);
    For L:=1 To Visible Do
    Begin
      BitBlt(PaintDC, 0, L*20, CArea.X, 20, TempDC, 0, 0, SrcCopy);
      PaintLine(PaintDC, L);
    End;
    DeleteDC(TempDC);
  End;

  Procedure TListViewer.RefreshLines;
  Var
    DC: HDC;
    L: Byte;
  Begin
    DC:=GetDC(HWindow);
    SetBkColor(DC, BkColor);
    If Inverted<>0 Then InvertLine(DC, Inverted);
    For L:=1 To Visible Do PaintLine(DC, L);
    ReleaseDC(HWindow, DC);
    DisplayLine(GetFocused+1, Range.Y);
  End;

  Procedure TListViewer.RefreshTotal;
  Begin
    InitBitmaps;
    SetScrollBars;
    InvalidateRect(hWindow, nil, False);
  End;

  Procedure TListViewer.SetScrollBars;
  Begin
    If HScrollBar Or (Pos.X<>0) Then
      SetScrollRange(hWindow, SB_HORZ, 0, Range.X-1, False)
    Else
      SetScrollRange(hwindow, SB_HORZ, 0, 0, False);
    If Range.Y>1 Then
      SetScrollRange(hWindow, SB_VERT, 0, Range.Y-1, False)
    Else
      SetScrollRange(hWindow, SB_VERT, 0, 1, False);
    SetScrollPos(hWindow, SB_VERT, Pos.Y, True);
    SetScrollPos(hWindow, SB_HORZ, Pos.X, True);
  End;

  Procedure TListViewer.WMSetFocus(Var Msg: TMessage);
  Begin
    DefWndProc(Msg);
    DisplayLine(GetFocused+1, Range.Y);
  End;

  Procedure TListViewer.WMSize(Var Msg: TMessage);
  Var R: TRect;
  Begin
    TWindow.WMSize(Msg);
    CArea:=MakePoint(Msg.lParam);
    Visible:=CArea.Y Div 20;
    RefreshTotal;
  End;

  Procedure TListViewer.WMHScroll(Var Msg: TMessage);
  Var OldP: Integer;
  Begin
    OldP:=Pos.X;
    Case Msg.wParam Of
      sb_LineUp, sb_PageUp: Dec(Pos.X);
      sb_LineDown, sb_PageDown: Inc(Pos.X);
      sb_ThumbPosition,
      sb_ThumbTrack: Pos.X:=Msg.lParamLo;
      else Exit;
    End;
    SetScrollPos(hWindow, sb_Horz, Pos.X, True);
    Pos.X:=GetScrollPos(hWindow, sb_Horz);
    If OldP<>Pos.X Then RefreshTotal;
  End;

  Procedure TListViewer.WMVScroll(Var Msg: TMessage);
  Var OldP: Integer;
  Begin
    OldP:=Pos.Y;
    Case Msg.wParam Of
      sb_LineUp: Dec(Pos.Y);
      sb_PageUp: Dec(Pos.Y, Visible-2);
      sb_LineDown: Inc(Pos.Y);
      sb_PageDown: Inc(Pos.Y, Visible-2);
      sb_ThumbPosition,
      sb_ThumbTrack: Pos.Y:=Msg.lParamLo;
    End;
    SetScrollPos(hWindow, sb_Vert, Pos.Y, True);
    Pos.Y:=GetScrollPos(hWindow, sb_Vert);
    If OldP<>Pos.Y Then RefreshLines;
  End;

  Procedure TListViewer.TrackMouse(Var Msg: TMessage);
  Var F, OldF, I: Integer;
  Begin
    F:=GetFocused;
    If (Msg.lParamHi>20) Or MouseDown Then
    Begin
      OldF:=F;
      F:=(Integer(Msg.lParamHi) Div 20)+Pos.Y-1;
      If (F>=Range.Y) Or (F<0) Then Exit;
      SetFocused(F);
      If Focused<Pos.Y Then
      Begin
        Pos.Y:=Focused;
        SetScrollBars;
        RefreshLines;
      End Else
      If Focused>Pos.Y+Visible-2 Then
      Begin
        Pos.Y:=Focused-Visible+2;
        SetScrollBars;
        RefreshLines;
      End;
      If (Msg.wParam-1=MK_SHIFT) And (Focused<>-1) And (OldF<>-1) Then
      Begin
        SetCursor(LoadCursor(0, IDC_WAIT));
        If OldF>Focused Then
          For I:=Focused To OldF Do
            Selected.SetSelection(I, True)
        Else
          For I:=OldF To Focused Do
            Selected.SetSelection(I, True);
        RefreshLines;
        SetCursor(LoadCursor(0, IDC_ARROW));
      End;
      If Msg.wParam-1=MK_CONTROL Then
      Begin
        with Selected do
          SetSelection(Focused, Not GetSelection(Focused));
        RefreshLines;
      End;
    End;
  End;

  Procedure TListViewer.WMLButtonDown(Var Msg: TMessage);
  Begin
    TrackMouse(Msg);
    SetCapture(hWindow);
    MouseDown:=True;
  End;

  Procedure TListViewer.WMLButtonUp(Var Msg: TMessage);
  Begin
    If MouseDown Then ReleaseCapture;
    MouseDown:=False;
  End;

  Procedure TListViewer.WMLButtonDblClk(Var Msg: TMessage);
  Begin
    If Msg.lParamLo<XOffset Then
    Begin
      with Selected do
        SetSelection(Focused, Not GetSelection(Focused));
      RefreshLines;
    End;
  End;

  Procedure TListViewer.WMMouseMove(Var Msg: TMessage);
  Begin
    If Msg.lParamLo>XOffset Then
      SetCursor(LoadCursor(0, IDC_ARROW))
    Else
      SetCursor(LoadCursor(hInstance, MakeIntResource(SelectionCursor)));
    If MouseDown Then
    begin
      Msg.wParam:=0;
      TrackMouse(Msg);
    end;
  End;

  Procedure TListViewer.WMKeyDown(Var Msg: TMessage);
    Procedure Down;
    Begin
      If ViewFocused Then RefreshLines;
      If Focused+1<Range.Y Then
      Begin
        If Focused+1>Pos.Y+Visible-2 Then
        Begin
          Inc(Pos.Y);
          SetScrollBars;
          RefreshLines;
        End;
        SetFocused(Focused+1);
      End;
    End;
    Procedure Up;
    Begin
      If ViewFocused Then RefreshLines;
      If Focused-1>=0 Then SetFocused(Focused-1);
      If Focused<Pos.Y Then
      Begin
        Dec(Pos.Y);
        SetScrollBars;
        RefreshLines;
      End;
    End;
    Procedure PgDown;
    Var F: Integer;
    Begin
      If ViewFocused Then RefreshLines;
      F:=Focused;
      Inc(F, Visible-1);
      If F>=Range.Y Then F:=Range.Y-1;
      SetFocused(F);
      If F>Pos.Y+Visible-2 Then
      Begin
        Inc(Pos.Y, Visible-1);
        SetScrollBars;
        RefreshLines;
      End;
    End;
    Procedure PgUp;
    Var F: Integer;
    Begin
      If ViewFocused Then RefreshLines;
      F:=Focused;
      Dec(F, Visible-1);
      If F<0 Then F:=0;
      SetFocused(F);
      If F<Pos.Y Then
      Begin
        Dec(Pos.Y, Visible-1);
        If Pos.Y<0 Then Pos.Y:=0;
        SetScrollBars;
        RefreshLines;
      End;
    End;
    Procedure GotoHome;
    Begin
      SetFocused(0);
      If ViewFocused Then RefreshLines;
    End;
    Procedure GotoEnd;
    Begin
      SetFocused(Range.Y-1);
      If ViewFocused Then RefreshLines;
    End;
  Begin
    If (Range.Y>0) And (Not IsIconic(Parent^.hWindow)) Then
    Case Msg.wParam Of
      VK_DOWN:  Down;
      VK_UP:    Up;
      VK_NEXT:  PgDown;
      VK_PRIOR: PgUp;
      VK_HOME:  GotoHome;
      VK_END:   GotoEnd;
      VK_SPACE: If Focused<>-1 Then
                Begin
                  with Selected do
                    SetSelection(Focused, Not GetSelection(Focused));
                  ViewFocused;
                  RefreshLines;
                End;
      Else DefWndProc(Msg);
    End Else
      DefWndProc(Msg);
  End;

  procedure TListViewer.WMChar;
  var
    i: Integer;
    S: PChar;
    C: Char;
  begin
    C:=UpCase(Char(Msg.wParam));
    i:=Focused+1;
    while i<>Focused do
    begin
      S:=GetString(GetData(i), 1);
      if (S<>nil) and (S^=C) then
      begin
        SetFocused(i);
        if ViewFocused then RefreshLines;
        Exit;
      end;
      Inc(i);
      if i>=Range.Y then i:=0;
    end;   
  end;

  procedure TListViewer.WMLocalMenu;
  begin
    ScreenToClient(hWindow, TPoint(Msg.lParam));
    if Msg.lParamLo<XOffset then
      GlbLocalMenu:=MakeIntResource(SelectionMenu)
    else
      GlbLocalMenu:=MakeIntResource(LocalMenu);
    GlbLocalMenuWin:=hWindow;
    Msg.Result:=LongInt(True);
  end;

  Procedure TListViewer.IDMSelectAll(Var Msg: TMessage);
  Var I: Integer;
  Begin
    If Range.Y>0 Then
    Begin
      SetCursor(LoadCursor(0, IDC_WAIT));
      For I:=0 To Range.Y-1 Do Selected.SetSelection(I, True);
      RefreshLines;
      SetCursor(LoadCursor(0, IDC_ARROW));
    End;
  End;

  Procedure TListViewer.IDMSelectNone(Var Msg: TMessage);
  Begin
    Selected.DeleteAll;
    RefreshLines;
  End;

  Procedure TListViewer.IDMInvertSelection(Var Msg: TMessage);
  Var I: Integer;
  Begin
    If Range.Y>0 Then
    Begin
      SetCursor(LoadCursor(0, IDC_WAIT));
      For I:=0 To Range.Y-1 Do
        with Selected do
          SetSelection(I, Not GetSelection(I));
      RefreshLines;             
      SetCursor(LoadCursor(0, IDC_ARROW));
    End;
  End;

  procedure TListViewer.IDMExport;
  const
    Options: TExportOptions= (
      AllData: 0; SelectedData: 0;
      ToClipboard: 1; ToFile: 0; AFileName: #0;
      ToAnsi: 1; ToOem: 0;
      UseTab: 1; UseSpace: 0; UseKomma: 0; UseSonst: 0; AChar: #0); 
  var
    Buf: TExportColl;    
    Dlg: PExportDlg;
    Ch: Char;
  begin
    New(Dlg, Init);
    if Selected.Count=0 then
    begin
      Options.AllData:=1;
      Options.SelectedData:=0;
    end else
    begin
      Options.AllData:=0;
      Options.SelectedData:=1;
    end;
    Dlg^.TransferBuffer:=@Options;
    if Application^.ExecDialog(Dlg)=ID_OK then
    with Options do
    begin
      if (SelectedData<>0) and (Selected.Count=0) then Exit;
      SetCursor(LoadCursor(0, IDC_WAIT));
      UpdateWindow(hMainWindow);
      if UseTab<>0 then Ch:=#9 else
        if UseSpace<>0 then Ch:=#32 else
          if UseKomma<>0 then Ch:=',' else
            Ch:=AChar[0];
      MakeExportColl(Buf, AllData=1, ToOem<>0, Ch);
      if ToFile<>0 then
        Buf.SendToFile(AFileName)
      else
      if OpenClipboard(hMainWindow) then
      begin
        EmptyClipboard;
        Buf.SendToClipboard(ToOem<>0);
        CloseClipboard;
      end;
      Buf.Done;
      SetCursor(LoadCursor(0, IDC_ARROW));
    end;
  end;

  Function TListViewer.GetData;
  Begin
    GetData:=nil;
  End;

  Function TListViewer.GetString;
  Begin
    GetString:=nil;
  End;

  procedure TListViewer.MakeExportColl(var Buf: TExportColl; All, Oem: Boolean; Ch: Char);
  const
    CrLf= #13#10;
  var
    TabChar: array[0..1] of Char;
    acS: array[0..512] of Char;
    i: Integer;

    procedure DoCopy(pL: Pointer); far;
    var
      Line: Integer absolute pL;
      Rec: Pointer;
      J: Integer;
      L: PListItem;
      P: PChar;
    begin
      Rec:=GetData(Line);
      if Rec<>nil then
      begin
        acS[0]:=#0;
        for J:=0 To Range.X-1 Do
        begin
          L:=PListItem(ListDesc.At(J));
          P:=GetString(Rec, L^.FieldNr);
          if P<>nil then StrCat(acS, P);
          StrCat(acS, TabChar);
        end;
        acS[StrLen(acS)-1]:=#0;
        StrCat(acS, CrLf);
        if Oem then AnsiToOem(acS, acS);
        Buf.InsertStr(acS);
      end;
    end;

  begin
    TabChar[0]:=Ch;
    TabChar[1]:=#0;
    Buf.Init(100);
    GetWindowText(Parent^.hWindow, acS, 100);
    StrCat(acS, CrLf);
    Buf.InsertStr(acS);
    if All then
      for i:=0 To Range.Y-1 do DoCopy(Pointer(i))
    else
      Selected.ForEach(@DoCopy);
  end;

{
** == TListWindow (Object) ==
**
** this is a window that owns a TListViewer object
**
}
  Destructor TListWindow.Done;
  Begin
    If Viewer<>nil Then Dispose(Viewer, Done);
    DisplayLine(0, 0);
    TWindow.Done;
  End;

  Function TListWindow.GetClassName: PChar;
  Begin
    GetClassName:='WAWIS:ListWindow';
  End;

  Procedure TListWindow.GetWindowClass(Var AWndClass: TWndClass);
  Begin
    TWindow.GetWindowClass(AWndClass);
    With AWndClass Do
    Begin
      hbrBackground:=GetStockObject(LTGRAY_BRUSH);
      Style:=Style And (Not (CS_HREDRAW+CS_VREDRAW));
    End;
  End;

  Procedure TListWindow.WMSize(Var Msg: TMessage);
  Begin
    TWindow.WMSize(Msg);
    MoveWindow(Viewer^.HWindow, 0, 0, LoWord(Msg.lParam), HiWord(Msg.lParam), True);
  End;

  Procedure TListWindow.WMSetFocus(Var Msg: TMessage);
  Begin
    DefWndProc(Msg);
    If Viewer<>nil Then SetFocus(Viewer^.hWindow);
  End;

  procedure TListWindow.WMInitMenu;
  begin
    if Viewer<>nil then
      SendMessage(Viewer^.hWindow, wm_InitMenu, Msg.wParam, 0);
  end;

  procedure TListWindow.WMLocalMenu;
  begin
    if Viewer<>nil then
      SendMessage(Viewer^.hWindow, wm_LocalMenu, 0, Msg.lParam);
  end;

End.