{=====================================================}
{ WAITDLG.PAS - Unit zum Darstellen von Prozentbalken }
{                                                     }
{           Copyright (c) 1994 by Gottschalk Software }
{=====================================================}

{$A+,B-,D+,F-,G+,I+,L+,N+,R-,S+,V+,W+,X+}
{$R WAITDLG.RES}

unit WaitDlg;
interface
  uses
    Objects, OWindows, ODialogs, WinTypes, WinProcs, Strings;

  const
    wm_PICancel = wm_User+300;
    ID_PIText   = 100;
    ID_PIBar    = 101;
    ID_PIBorder = 102;

  type
    PWaitDlg= ^TWaitDlg;
    TWaitDlg= Object(TDialog)
      constructor InitStandard(AParent: PWindowsObject; ATitle: PChar; AbortBtn: Boolean);
      constructor Init(AParent: PWindowsObject; X, Y: Integer; AName: PChar);
      procedure SetupWindow; virtual;
      destructor Done; virtual;
      procedure DoYield;
      procedure SetPos(ACurrent, AMax: Word);
      procedure SetPosText(AText: PChar; ACurrent, AMax: Word);
      procedure SetText(AText: PChar);
      procedure Paint(PaintDC: HDC; var PaintInfo: TPaintStruct); virtual;
      procedure Abort(var Msg: TMessage); virtual id_First+id_Abort;
     private
      Max: Word;
      Percent: Integer; 
      dx, dy: Integer;
      bl, bt, br, bb: Integer;
      Lines: Integer;
      LineInc: Real;
      Title, Text: PChar;
      ShowButton: Boolean;
      procedure DrawBar(DC: HDC);
    end;

implementation

  constructor TWaitDlg.InitStandard(AParent: PWindowsObject; ATitle: PChar; AbortBtn: Boolean);
  begin
    TDialog.Init(AParent, 'WaitDlg');
    Title:=ATitle;
    dx:=-1;
    dy:=-1;
    ShowButton:=AbortBtn;
    Text:=nil;
  end;

  constructor TWaitDlg.Init(AParent: PWindowsObject; X, Y: Integer; AName: PChar);
  begin
    TDialog.Init(AParent, AName);
    dx:=X;
    dy:=Y;
    ShowButton:=True;
    Text:=nil;
  end;

  procedure TWaitDlg.SetupWindow;
  var
    R, R2: TRect;
    tp, P1, P2: TPoint;
  begin
    TDialog.SetupWindow;
    Percent:=0;
    GetWindowRect(hWindow, R);
    if Parent=nil then
    begin
      R2.Right:=GetSystemMetrics(SM_CXSCREEN);
      R2.Bottom:=GetSystemMetrics(SM_CYSCREEN);
    end else
      GetClientRect(Parent^.hWindow, R2);
    if dx<0 then
      tp.x:=(R2.Right-(R.Right-R.Left)) div 2
    else
      tp.x:=dx;
    if dy<0 then
      tp.y:=(R2.Bottom-(R.Bottom-R.Top)) div 2
    else
      tp.y:=dy;
    if Parent<>nil then ClientToScreen(Parent^.hWindow, tp);
    SetWindowPos(hWindow, 0, tp.x, tp.y, 0, 0, swp_NoSize);
    GetWindowRect(GetItemHandle(ID_PIBar), R);
    P1.X:=R.Left+4; P1.Y:=R.Top+4; P2.X:=R.Right-4; P2.Y:=R.Bottom-4;
    ScreenToClient(hWindow, P1); ScreenToClient(hWindow, P2);
    bl:=P1.X; bt:=P1.Y; br:=P2.X; bb:=P2.Y;
    LineInc:=(br-bl) / 100;
    Lines:=Round(Percent*LineInc);
    if Title<>nil then SetWindowText(hWindow, Title);
    if not ShowButton then
    begin
      ShowWindow(GetItemHandle(idAbort), sw_Hide);
      EnableMenuItem(GetSystemMenu(hWindow, False), sc_Close, mf_ByCommand Or mf_Grayed);
      GetWindowRect(hWindow, R);
      GetWindowRect(GetItemHandle(ID_PIBorder), R2);
      tp.X:=0; tp.Y:=R2.Top;
      ScreenToClient(hWindow, tp);
      Inc(tp.Y, 2*GetSystemMetrics(SM_CYDLGFRAME));
      SetWindowPos(hWindow, 0, 0, 0, R.Right-R.Left, tp.Y, swp_NoMove);
    end;
    if Parent<>nil then EnableWindow(Parent^.hWindow, False);
  end;

  destructor TWaitDlg.Done;
  begin
    if Parent<>nil then EnableWindow(Parent^.hWindow, True);
    EndDlg(1);
    TDialog.Done;
  end;

  procedure TWaitDlg.SetPos(ACurrent, AMax: Word);
  begin
    SetPosText(nil, ACurrent, AMax);
  end;

  procedure TWaitDlg.SetPosText(AText: PChar; ACurrent, AMax: Word);
  var
    DC: HDC;
    S: array[0..5] of Char;
  begin
    Percent:=Round(ACurrent/AMax*100);
    if (Percent>=0) and (Percent<=100) then
    begin
      StrDispose(Text);
      if AText=nil then
      begin
        wvsprintf(s, '%i%%', Percent);
        Text:=StrNew(S);
      end else
        Text:=StrNew(AText);
      Lines:=Round(Percent*LineInc)+1;
      DC:=GetDC(hWindow);
      DrawBar(DC);
      ReleaseDC(hWindow, DC);
    end else
      Percent:=0;
  end;

  procedure TWaitDlg.SetText(AText: PChar);
  begin
    SetDlgItemText(hWindow, id_PIText, AText);
  end;   

  procedure TWaitDlg.DoYield;
  var Msg: TMsg;
  begin
    while PeekMessage(Msg, 0, 0, 0, pm_Remove) do
      if not IsDialogMessage(hWindow, Msg) then
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
  end;

  procedure TWaitDlg.Paint(PaintDC: HDC; var PaintInfo: TPaintStruct);
  begin
    Rectangle(PaintDC, bl, bt, br, bb);
    DrawBar(PaintDC);
  end;

  procedure TWaitDlg.Abort(Var Msg: TMessage);
  begin
    if Parent<>nil Then
    begin
      SendMessage(Parent^.hWindow, wm_PICancel, 0, 0);
      EnableWindow(Parent^.hWindow, True);
    end;
  end;

  procedure TWaitDlg.DrawBar(DC: HDC);
  var R: TRect;
  begin
    SelectObject(DC, GetStockObject(Black_Pen));
    Rectangle(DC, bl+Lines-1, bt, br, bb);
    SelectObject(DC, GetStockObject(Gray_Brush));
    Rectangle(DC, bl, bt, bl+Lines-1, bb);
    SetBkMode(DC, Transparent);
    SetTextColor(DC, RGB(0, 0, 128));
    SetRect(R, bl, bt, br, bb);
    DrawText(DC, Text, StrLen(Text), R, dt_Center or dt_SingleLine or dt_VCenter);
  end;

end.