{================================================}
{ Warenwirtschaftsprogramm für Windows 3.1       }
{                                                }
{ Version:     1.1                               }
{ Last change: 29.7.1995                         }
{                                                }
{ created for Quickbox Kiosk & Imbiss            }
{                                                }
{ (c) Copyright 1991-1995 by Gottschalk Software }
{================================================}

{$A+,B-,D+,F-,G+,I+,K-,L+,N+,P-,Q-,R-,S+,T-,V+,W-,X+,Y+}
{$M 8192,8192}

{$R WAWIS.RES}

program WAWIS;
uses
  Objects, OWindows,
  WinTypes, WinProcs, WinDos, BWCC, Strings, BtpWin, MDITools, WaitDlg,
  Globals, Dialogs, DBServer, MainWin, Artikel, Lieferanten, Betriebe, Einkauf,
  Ordersatz, Sounds, Ctl3D;

type
  TApp= object(T3DApplication)
    constructor Init;
    destructor Done; virtual;
    procedure InitMainWindow; virtual;
  end;

procedure InitDatabases;
begin
  InitDB(ArtikelDB,  str_ArtikelDB,  ArtikelFile);
  InitDB(LieferDB,   str_LieferDB,   LieferFile);
  InitDB(BetriebeDB, str_BetriebDB, BetriebeFile);
  InitDB(EKDB, str_EKListeDB, EKListeFile);
end;

procedure DoneDatabases;
begin
  if EKDB<>nil       then Dispose(EKDB, Done);
  if ArtikelDB<>nil  then Dispose(ArtikelDB, Done);
  if LieferDB<>nil   then Dispose(LieferDB, Done);
  if BetriebeDB<>nil then Dispose(BetriebeDB, Done);
end;

procedure SafeExit; far;
begin
  ExitProc:=OldExitProc;
  DoneLocalMenus;
  DoneDatabases;
  BtpWinDone;
end;

{ TApp Object }
constructor TApp.Init;
var
  Date: array[0..50] of Char;
  Today: TTime;
  r: TRect;
  p: TPoint;
  M: TMessage;
  B: TBitmap;
begin
  CmdShow:=sw_Hide;
  ReadUserSettings;
  if (hPrevInst<>0) and (not Debug) then
  begin
    MessageBeep(0);
    MessageBox(0, GetResString(str_SecondInstance), Title, MB_ICONEXCLAMATION or MB_OK);
    Halt;
  end;
  inherited Init(Title);
  RegisterOrdersatz;
  BtpWinInit(Title);
  OldExitProc:=ExitProc;
  ExitProc:=@SafeExit;
  CheckDatapath;
  { Begrüßungsdialog erstellen }
  New(GlbWaitDlg, Init(Application^.MainWindow, -1, -1, MakeIntResource(StartDlg)));
  GlbWaitDlg^.Create;
  SetWindowText(GlbWaitDlg^.GetItemHandle(id_VersionInfo), Version);
  SetWindowText(GlbWaitDlg^.GetItemHandle(id_CopyrightInfo), Copyright);
  CenterStaticBmp(GlbWaitDlg^.hWindow, id_WawisLogo, id_WawisLogoCenter);
  CenterStaticBmp(GlbWaitDlg^.hWindow, id_QuickboxLogo, id_QuickboxLogoCenter);
  ShowWindow(GlbWaitDlg^.hWindow, sw_Show);
  UpdateWindow(GlbWaitDlg^.hWindow);
  PlaySnd('Start');
  GetWindowRect(GlbWaitDlg^.hWindow, r);
  GetCursorPos(p);
  if ((p.X>=r.Left) and (p.X<=r.Right)) and ((p.Y>=r.Top) and (p.Y<=r.Bottom)) then
    SetCursorPos(r.Right, r.Bottom);
  SetCursor(LoadCursor(0, IDC_WAIT));
  { Ressourcen laden }
  HAccTable:=LoadAccelerators(hInstance, MakeIntResource(1));
  bmBWCC:=LoadBitmap(hInstance, MakeIntResource(BWCCGrayBmp));
  bmListWin:=LoadBitmap(hInstance, MakeIntResource(ListWindowBmp));
  bmSelected:=LoadBitmap(hInstance, MakeIntResource(SelectedBmp));
  InitLocalMenus;
  { Listenfenster Font erstellen }
  GetObject(bmListWin, SizeOf(B), @B);
  lfntListWin.lfHeight:=B.bmHeight-3;
  fntListWin:=CreateFontIndirect(lfntListWin);
  cf_Artikel:=RegisterClipboardFormat(cb_Artikel);
  { globale Einstellungen und Daten }
  ReadGlobalSettings;
  InitDatabases;
  Today.Init;
  Today.GetString(Date, False);
  if Debug then StrCat(Date, ' (debug mode)');
  DisplayHint(Date);
  if not GlbBestellung then
  begin
    { Hauptfenster anzeigen }
    ShowWindow(hMainWindow, sw_Show);
    if PMainWindow(MainWindow)^.Zoomed then ShowWindow(hMainWindow, sw_Maximize);
    UpdateWindow(hMainWindow);
    { Datenbankfenster öffnen }
    if UserSettings.AutoDB then
    with PMainWindow(MainWindow)^ do
    begin
      DisplayHint('Öffne Datenbankfenster...');
      IDMBetriebeStamm(M);
      IDMLieferantenStamm(M);
      IDMArtikelStamm(M);
      DisplayHint(Date);    
    end;
  end;
  SetCursor(LoadCursor(0, IDC_ARROW));
  if UserSettings.WaitforKey then
  begin
    GlbWaitDlg^.SetText(nil);
    GlbWaitDlg^.SetPosText(GetResString(str_WaitforKey), 0, 1);
    WaitforKey;
  end;
  Dispose(GlbWaitDlg, Done);
  GlbWaitDlg:=nil;
  if GlbBestellung then PMainWindow(MainWindow)^.IDMBestellung(M);
end;

destructor TApp.Done;
begin
  ExitProc:=OldExitProc;
  DoneLocalMenus;
  DoneDatabases;
  BtpWinDone;
  DeleteObject(fntListWin);
  DeleteObject(bmBWCC);
  DeleteObject(bmListWin);
  DeleteObject(bmSelected);
  inherited Done;
  PlaySnd('Stop');
end;

procedure TApp.InitMainWindow;
begin
  MainWindow:=New(PMainWindow, Init);
end;

var
  A: TApp;

begin
  A.Init;
  A.Run;
  A.Done;
end.