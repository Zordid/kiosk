unit MainWin;
interface
  uses
    Objects, OWindows,
    WinTypes, WinProcs, Strings, MDITools, BtpWin, CommDlg, BWCC,
    Globals, Communication, DBServer, DBEditor, Dialogs,
    Artikel, Lieferanten, Betriebe, Einkauf, Ordersatz, Bestellungen;

  type
    PMainWindow= ^TMainWindow;
    TMainWindow= object(TExtMDIWindow)
      Zoomed: Boolean;
      constructor Init;
      procedure SetupWindow; virtual;
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(var AWndClass: TWndClass); virtual;
      procedure GetMenuHint(var Msg: TMessage; var Hint: THint); virtual;
      procedure InitToolBar; virtual;
      procedure WMDestroy(var Msg: TMessage); virtual wm_First+wm_Destroy;
      procedure WMInitMenu(var Msg: TMessage); virtual wm_First+wm_InitMenu;
      procedure WMLocalMenu(var Msg: TMessage); virtual wm_First+wm_LocalMenu;
      { System Menü }
      procedure IDMInfo(var Msg: TMessage); virtual cm_First+IDM_INFO;
      procedure IDMSystem(var Msg: TMessage); virtual cm_First+IDM_SYSTEM;
      procedure IDMUser(var Msg: TMessage); virtual cm_First+IDM_USER;
      procedure IDMReReadDB(var Msg: TMessage); virtual cm_First+IDM_REREADDB;
      procedure IDMPrint(var Msg: TMessage); virtual cm_First+IDM_PRINT;
      procedure IDMQuit(var Msg: TMessage); virtual cm_First+IDM_QUIT;
      { Stammdaten Menü }
      procedure IDMArtikelStamm(var Msg: TMessage); virtual cm_First+IDM_ARTIKELSTAMM;
      procedure IDMLieferantenStamm(var Msg: TMessage); virtual cm_First+IDM_LIEFERANTENSTAMM;
      procedure IDMBetriebeStamm(var Msg: TMessage); virtual cm_First+IDM_BETRIEBESTAMM;
      procedure IDMEKPreise(var Msg: TMessage); virtual cm_First+IDM_EKLISTE;
      procedure WMEKPreisliste(var Msg: TMessage); virtual wm_First+wm_EKListe;
      { Ordersatz Menü }
      procedure IDMNewOS(var Msg: TMessage); virtual cm_First+IDM_NEWOS;
      procedure IDMLoadOS(var Msg: TMessage); virtual cm_First+IDM_OSOPEN;
      procedure IDMDeleteOS(var Msg: TMessage); virtual cm_First+idm_OSDelete;
      procedure IDMActiveOS(var Msg: TMessage); virtual cm_First+idm_ActiveOS;
      procedure IDMExtras(var Msg: TMessage); virtual cm_First+idm_OSExtras;
      { Bestellungen Menü }
      procedure IDMBestellung(var Msg: TMessage); virtual cm_First+idm_Bestellung;
    end;

implementation
  
  constructor TMainWindow.Init;
  var
    X, Y, CX, CY: Integer;
    Maximized: Boolean;
  begin
    System.CmdShow:=sw_Hide;
    hMainMenu:=LoadMenu(hInstance, MakeIntResource(MainMenu));
    TExtMDIWindow.Init(MainWinTitle, hMainMenu);
    X:=0;
    Y:=0;
    CX:=GetSystemMetrics(SM_CXSCREEN);
    CY:=GetSystemMetrics(SM_CYSCREEN)-2*GetSystemMetrics(SM_CYCAPTION)-GetSystemMetrics(SM_CYICON);
    if not UserSettings.DefaultWindowSize then
    begin 
      Attr.X:=GetPrivateProfileInt(pf_Window, 'X', 0, ProfileFile);
      Attr.Y:=GetPrivateProfileInt(pf_Window, 'Y', 0, ProfileFile);
      Attr.W:=GetPrivateProfileInt(pf_Window, 'CX', CX, ProfileFile);
      Attr.H:=GetPrivateProfileInt(pf_Window, 'CY', CY, ProfileFile);
      Zoomed:=GetPrivateProfileInt(pf_Window, 'Zoom', 0, ProfileFile)=1;
    end else
    begin
      Attr.X:=0;  Attr.Y:=0;
      Attr.W:=CX; Attr.H:=CY;
      Zoomed:=False;
    end;
    ChildMenuPos:=5;
  end;

  procedure TMainWindow.SetupWindow;
  var acS: Array[0..100] of Char;
  begin
    TExtMDIWindow.SetupWindow;
    hMainWindow:=hWindow;
  end;

  function TMainWindow.GetClassName: PChar;
  begin
    GetClassName:='WAWIS:Main';
  end;

  procedure TMainWindow.GetWindowClass(var AWndClass: TWndClass);
  begin
    TExtMDIWindow.GetWindowClass(AWndClass);
    AWndClass.hIcon:=LoadIcon(hInstance, MakeIntResource(MainIcon));
  end;

  procedure TMainWindow.GetMenuHint(var Msg: TMessage; var Hint: THint);
  begin
    case Msg.lParamLo and (mf_SysMenu or mf_Popup) of
      0:          LoadString(hInstance, str_Menu+Msg.wParam, Hint, SizeOf(Hint));
      mf_SysMenu: LoadString(hInstance, str_Menu+1, Hint, SizeOf(Hint));
      else Hint[0]:=#0;
    end;
    if Hint[0]=#0 then
      LoadString(hInstance, str_Menu, Hint, SizeOf(Hint));
  end;

  procedure TMainWindow.InitToolBar;
  begin
    ToolBarSpace:=25;
    New(ToolBar, Init(@Self, nil, 0, 0,
      NewButton('TB1', idm_Quit, MakeIntResource(str_Menu+idm_Quit),
      NewSeparator(
      NewButton('TB2', idm_Artikelstamm, MakeIntResource(str_Menu+idm_Artikelstamm),
      NewButton('TB3', idm_Lieferantenstamm, MakeIntResource(str_Menu+idm_Lieferantenstamm),
      NewButton('TB4', idm_Betriebestamm, MakeIntResource(str_Menu+idm_Betriebestamm),
      NewButton('TB5', idm_EKListe, MakeIntResource(str_Menu+idm_EKListe),
      NewSeparator(
      NewButton('TB7', idm_NewOS, MakeIntResource(str_Menu+idm_NewOS),
      NewButton('TB8', idm_OSOpen, MakeIntResource(str_Menu+idm_OSOpen),
      NewButton('TB9', idm_ActiveOS, MakeIntResource(str_Menu+idm_ActiveOS),
      NewSeparator(
      NewButton('TB6', idm_Bestellung, MakeIntResource(str_Menu+idm_Bestellung),
      nil)))))))))))),
      25, 1));
  end;

  procedure TMainWindow.WMInitMenu(var Msg: TMessage);
  begin
    EnableMenuItem(hMainMenu, IDM_SELECTALL, mf_Grayed);
    EnableMenuItem(hMainMenu, IDM_COPY, mf_Grayed);
    {EnableMenuItem(hMainMenu, IDM_CUT, MF_GRAYED);}
    EnableMenuItem(hMainMenu, IDM_PASTE, mf_Grayed);
    EnableMenuItem(hMainMenu, idm_Export, mf_Grayed);
    EnableMenuItem(hMainMenu, idm_OSSave, mf_Grayed);
    EnableMenuItem(hMainMenu, idm_OSSaveAs, mf_Grayed);
    SendMessage(GetTopWindow(ClientWnd^.hWindow), wm_InitMenu, Msg.wParam, 0);
    Msg.Result:=0;
  end;

  procedure TMainWindow.WMLocalMenu;
  var
    P: TPoint;
    Wnd: HWnd;
  begin
    P:=TPoint(Msg.lParam);
    ScreenToClient(ClientWnd^.hWindow, P);
    Wnd:=ChildWindowFromPoint(ClientWnd^.hWindow, P);
    if IsWindowEnabled(hWindow) then
      SendMessage(Wnd, wm_LocalMenu, 0, Msg.lParam);
  end;

  procedure TMainWindow.WMDestroy(var Msg: TMessage);
  var
    A: array[0..80] of Char;
    R: TRect;
  begin
    GetWindowRect(hWindow, R);
    wvsprintf(A, '%d', R.Left);
    WritePrivateProfileString(pf_Window, 'X', A, ProfileFile);
    wvsprintf(A, '%d', R.Top);
    WritePrivateProfileString(pf_Window, 'Y', A, ProfileFile);
    Dec(R.Right, R.Left);
    wvsprintf(A, '%d', R.Right);
    WritePrivateProfileString(pf_Window, 'CX', A, ProfileFile);
    Dec(R.Bottom, R.Top);
    wvsprintf(A, '%d', R.Bottom);
    WritePrivateProfileString(pf_Window, 'CY', A, ProfileFile);
    R.Bottom:=Integer(IsZoomed(hWindow));
    wvsprintf(A, '%d', R.Bottom);
    WritePrivateProfileString(pf_Window, 'Zoom', A, ProfileFile);
    TWindow.WMDestroy(Msg);
  end;

  procedure TMainWindow.IDMInfo;
  begin
    Application^.ExecDialog(New(PInfoDlg, Init));
  end;

  procedure TMainWindow.IDMSystem;
  var D: PSystemDlg;
  begin
    if LockGlobalSettings then
    begin
      New(D, Init);
      Application^.ExecDialog(D);
      SaveGlobalSettings;
    end else
      MessageBox(0, GetResString(str_SysParamsLocked), Title, MB_ICONHAND Or MB_OK);
  end;

  procedure TMainWindow.IDMUser;
  var D: PUserDlg;
  begin
    New(D, Init);
    if Application^.ExecDialog(D)=ID_OK then SaveUserSettings;
  end;

  procedure TMainWindow.IDMRereadDB;
  begin
    (*
    RereadDBBuffers;
    *)
  end;

  procedure TMainWindow.IDMPrint;
  var E: TExportColl;
  begin
    E.SendToPrinter;
  end;

  procedure TMainWindow.IDMQuit;
  begin
    CloseWindow;
  end;

  procedure TMainWindow.IDMArtikelStamm;
  var P: PArtikelWin;
  begin
    New(P, Init);
    Application^.MakeWindow(P);
  end;

  procedure TMainWindow.IDMLieferantenStamm;
  var P: PLieferWin;
  begin
    New(P, Init);
    Application^.MakeWindow(P);
  end;

  procedure TMainWindow.IDMBetriebeStamm;
  var P: PBetriebeWin;
  begin
    New(P, Init);
    Application^.MakeWindow(P);
  end;

  procedure TMainWindow.IDMEKPreise;
  var
    P: PEKWindow;
    L: LongInt;
  begin
    L:=SelectLieferant(False);
    if L<>-1 then
    begin
      if LockLieferant(True, L) then
      begin
        New(P, Init(L));
        Application^.MakeWindow(P);
      end else
      begin
        if Debug then
        begin
          if MessageBox(hMainWindow, 'Sperrung aufheben ?', Title, MB_YESNO)=id_Yes then
            LockLieferant(False, L);
        end else
          MessageBox(hMainWindow, GetResString(str_EKListeLocked), Title, MB_ICONHAND Or MB_OK);
      end;
    end;
  end;

  procedure TMainWindow.WMEKPreisliste;
  var P: PEKWindow;
  begin
    if LockLieferant(True, Msg.lParam) then
    begin
      New(P, Init(Msg.lParam));
      Application^.MakeWindow(P);
    end else
      MessageBox(hWindow, GetResString(str_EKListeLocked), Title, MB_ICONHAND Or MB_OK);
  end;

  procedure TMainWindow.IDMNewOS;
  var P: POrdersatzWin;
  begin
    New(P, Init(nil, nil, of_ReadWrite));
    Application^.MakeWindow(P);
  end;

  procedure TMainWindow.IDMLoadOS;
  var
    OpenFN: TOpenFileName;
    FullFilename: array[0..100] of Char;
    P: POrdersatzWin; 
  begin
    Ordersatz.InitOpenFNBuffer(OpenFN, GetResString(str_OSOpen));
    OpenFN.lpstrFile:=FullFilename;
    OpenFN.nMaxFile:=SizeOf(FullFileName);
    FullFilename[0]:=#0;
    if GetOpenFileName(OpenFN) then
    begin
      New(P, Init(FullFilename, nil, of_ReadWrite));
      if P<>nil then Application^.MakeWindow(P);
    end;
  end;

  procedure TMainWindow.IDMDeleteOS;
  var
    DeleteFN: TOpenFileName;
    FullFileName: array[0..100] of Char;
    acS: array[0..200] of Char;
    P: PChar;
    F: TOfStruct;
  begin
    Ordersatz.InitOpenFNBuffer(DeleteFN, GetResString(str_OSDelete));
    DeleteFN.lpstrFile:=FullFileName;
    DeleteFN.nMaxFile:=SizeOf(FullFileName);
    FullFileName[0]:=#0;
    if GetOpenFileName(DeleteFN) then
    begin
      P:=FullFileName;
      wvsprintf(acS, GetResString(str_OSDeleteQuestion), P);
      if MessageBox(hWindow, acS, Title, MB_ICONQUESTION or MB_YESNO or MB_DEFBUTTON2)=id_Yes then
      begin
        if OpenFile(FullFileName, F, of_Delete or of_Share_Exclusive)<0 then
        begin
          wvsprintf(acS, GetResString(str_OSDeleteError), P);
          MessageBeep(0);
          MessageBox(hWindow, acS, Title, MB_ICONEXCLAMATION or MB_OK);
        end;
      end;
    end;
  end;

  procedure TMainWindow.IDMActiveOS;
  begin
    ActiveOSList;
  end;

  procedure TMainWindow.IDMExtras;
  var
    BetriebNr: LongInt;
    acS: array[0..100] of Char;
    P: POrdersatzWin;
    B: PBetriebRec;  
  begin
    BetriebNr:=SelectBetrieb;
    if BetriebNr>=0 then
    begin
      B:=PBetriebRec(BetriebeDB^.GetRecNr(BetriebNr));
      StrCopy(StrECopy(acS, 'Extras für '), B^.Name);
      New(P, Init(OSPathFile(OSXFile, BetriebNr), acS, of_ReadWrite));
      Application^.MakeWindow(P);
    end;
  end;

  procedure TMainWindow.IDMBestellung;
  begin
    Bestellung;
  end;

end.