{$I-}
unit Globals;
interface
  uses
    Objects, OWindows,
    WinTypes, WinProcs, BtpWin, WinDos, Win31, Strings, MDITools,
    WaitDlg;

  {$I GLOBALS.INC}

  const
    Title        = 'WAWIS 1.1';
    Version      = '1.1 (Rev.: 29.7.95)';
    Copyright    = 'Copyright © 1991-95 by Gottschalk Software.  All rights reserved.';
    MainWinTitle = 'WAWIS - Das Warenwirtschaftssystem';
    cb_Artikel   = 'WAWIS Artikel';

    { Dateinamen }
    GlobalsFile  = 'globals.wd';
    ArtikelFile  = 'artikel.wd';
    LieferFile   = 'liefer.wd';
    BetriebeFile = 'betriebe.wd';
    EKListeFile  = 'ekliste.wd';
    ProfileFile  = 'wawis.ini';
    OSAListFile  = 'active.osl';
    OSAFile      = '%06li.osa';
    OSXFile      = '%06li.osx';

    { INI-Abschnitte }
    pf_Paths     = 'Paths';
    pf_User      = 'User';
    pf_Window    = 'Window';
    pf_Sounds    = 'Sounds';

    { Messages }
    wm_DBMessage = wm_User+9;
    wm_EKListe   = wm_User+10;
    wm_LocalMenu = wm_User+20;

  type
    PTime= ^TTime;
    TTime= object(TObject)
      Year, Month, Day: Word;
      Hour, Minute: Word;
      DayOfWeek: Byte;
      constructor Init;
      constructor InitCopy(ATime: TTime);
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
      function CompareTo(ATime: TTime): Integer;
      function GetString(P: PChar; Time: Boolean): PChar;
    end;

    PShareStream= ^TShareStream;
    TShareStream= object(TBufStream)
      constructor Init(FileName: PChar; Mode, MaxTries: Word);
    end;

    TGlobalSettings= record
      MwSt: array[0..2] of Real;
      MwStString: array[0..2,0..7] of Char;
      Warengruppe: array[1..10, 0..20] of Char;
    End;

    TUserSettings= record
      Name: array[0..20] of Char;
      DefaultWindowSize: Boolean;
      AutoDB: Boolean;
      DefaultArtikelSort: Integer;
      DefaultArtikelEKSort: Integer;
      WaitforKey: Boolean;
    end;

  const
    bmBWCC:     HBitmap= 0;
    bmListWin:  HBitmap= 0;
    bmSelected: HBitmap= 0;
    fntListWin: HFont= 0;
    lfntListWin:TLogFont= (
      lfHeight: 0; lfWidth: 0; lfEscapement: 0; lfOrientation: 0;
      lfWeight: fw_Normal; lfItalic: 0; lfUnderline: 0; lfStrikeOut: 0;
      lfCharSet: Ansi_CharSet; lfOutPrecision: Out_Default_Precis;
      lfClipPrecision: Clip_Default_Precis; lfQuality: Proof_Quality;
      lfPitchAndFamily: Variable_Pitch or ff_Swiss;
      lfFaceName: #0);

  var
    ProgramPath,
    DataPath,
    OSPath,
    BestellPath: array[0..fsDirectory] of Char;
    Debug: Boolean;
    GlobalSettings: TGlobalSettings;
    UserSettings: TUserSettings;
    GlbBestellung: Boolean;
    hMainWindow: THandle;
    hMainMenu: HMenu;
    cf_Artikel: THandle;
    GlbWaitDlg: PWaitDlg;
    OldExitProc: Pointer;
    GlbLocalMenu: PChar;
    GlbLocalMenuWin: HWnd;

  { general functions }
  procedure Delay(MS: Word);
  procedure WaitforKey;
  function FileExist(Name: PChar): Boolean;
  function CompareData(var D1, D2; Size: Word): Boolean;
  function StrTok(Source: PChar; Token: Char): PChar;
  function GetResString(ID: Word): PChar;
  procedure GlbError(ErrorCode: Integer; Info: Pointer);

  { user setting functions }
  procedure CheckDatapath;
  procedure ReadUserSettings;
  procedure SaveUserSettings;

  { global settings functions }
  function ReadGlobalSettings: Boolean;
  function LockGlobalSettings: Boolean;
  function SaveGlobalSettings: Boolean;

  { local menu functions }
  procedure InitLocalMenus;
  procedure DoneLocalMenus;

  { path functions }
  function DatapathFile(FName: PChar): PChar;
  function OSPathFile(FName: PChar; Data: LongInt): PChar;
  function BestellPathFile(FName: PChar): PChar;
  function ProgramPathFile(FName: PChar): PChar;

implementation
  uses Dialogs;

{== TTime object ==}
  constructor TTime.Init;
  var i: Word;
  begin
    GetDate(Year, Month, Day, i);
    DayOfWeek:=i;
    GetTime(Hour, Minute, i, i);    
  end;

  constructor TTime.InitCopy(ATime: TTime);
  begin
    Year:=ATime.Year; Month:=ATime.Month; Day:=ATime.Day;
    DayOfWeek:=ATime.DayOfWeek; Hour:=ATime.Hour; Minute:=ATime.Minute;
  end;

  constructor TTime.Load(var S: TStream);
  begin
    S.Read(Year, 5*SizeOf(Word));
    S.Read(DayOfWeek, SizeOf(DayOfWeek));
  end;

  procedure TTime.Store(var S: TStream);
  begin
    S.Write(Year, 5*SizeOf(Word));
    S.Write(DayOfWeek, SizeOf(DayOfWeek));
  end;

  function TTime.CompareTo(ATime: TTime): Integer;
  begin
    if Year<ATime.Year then CompareTo:=-1 else
      if Year>ATime.Year then CompareTo:=+1 else
        if Month<ATime.Month then CompareTo:=-1 else
          if Month>ATime.Month then CompareTo:=+1 else
            if Day<ATime.Day then CompareTo:=-1 else
              if Day>ATime.Day then CompareTo:=+1 else
                if Hour<ATime.Hour then CompareTo:=-1 else
                  if Hour>ATime.Hour then CompareTo:=+1 else
                    if Minute<ATime.Minute then CompareTo:=-1 else
                      if Minute>ATime.Minute then CompareTo:=+1 else
                        CompareTo:=0;
  end;

  function TTime.GetString(P: PChar; Time: Boolean): PChar;
  var
    DayBuf, MonthBuf: array[0..16] of Char;
    Data: record
      DoW: PChar;
      D: Word;
      Mon: PChar;
      Y, H, M: Word;
    end;
  begin
    LoadString(hInstance, str_WochenTag+DayOfWeek, DayBuf, 15);
    LoadString(hInstance, str_Monat+Month, MonthBuf, 15);
    Data.DoW:=DayBuf;
    Data.D:=Day;
    Data.Mon:=MonthBuf;
    Data.Y:=Year;
    Data.H:=Hour;
    Data.M:=Minute;
    if Time then
      wvsprintf(P, '%s, %u. %s %u, %02u:%02u Uhr', Data)
    else
      wvsprintf(P, '%s, %u. %s %u', Data);
    GetString:=P;
  end;

{== TShareStream object ==}
  constructor TShareStream.Init(FileName: PChar; Mode, MaxTries: Word);
  var
    Try: Word;
    O: TOFStruct;
  begin
    if ((Mode and of_Create)=0) and (not FileExist(FileName)) then
      GlbError(em_StrmFileNotFound, @FileName);
    TStream.Init;
    Try:=0;
    repeat
      if Try>0 then
      begin
        SetCursor(LoadCursor(0, idc_Wait));
        Delay(1000);
      end;
      Handle:=OpenFile(FileName, O, Mode);
      Inc(Try);
    until (Integer(Handle)>0) or (Try>=MaxTries);
    if Integer(Handle)>0 then Status:=stOk else Status:=stInitError;
    if (Status<>stOk) and ((Mode and of_Create)<>0) then
      GlbError(em_StrmCannotCreate, @FileName);
    BufSize := 1024;
    GetMem(Buffer, BufSize);
    BufPtr := 0;
    BufEnd := 0;
  end;

{== general functions ==}
  procedure Delay(MS: Word);
  var Ticks: LongInt;
  begin
    Ticks:=GetTickCount;
    while GetTickCount-Ticks<MS do;
  end;

  procedure WaitforKey;
  var M: TMsg;
  begin
    SetCapture(GetActiveWindow);
    repeat
      while PeekMessage(M, 0, 0, 0, pm_Remove) do
      begin
        TranslateMessage(M);
        DispatchMessage(M);
      end;
    until (M.Message=wm_Char) or (M.Message=wm_LButtonUp) or (M.Message=wm_RButtonUp);
    ReleaseCapture;
  end;

  function FileExist(Name: PChar): Boolean;
  var F: TSearchRec;
  begin
    FindFirst(Name, faAnyFile, F);
    FileExist:=DosError=0; {OpenFile(Name, F, of_Exist or of_Share_Deny_None)>0};
  end;

  function CompareData(var D1, D2; Size: Word): Boolean;
  var
    Data1: TByteArray absolute D1;
    Data2: TByteArray absolute D2;
    I: Integer;
  begin
    CompareData:=False;
    for I:=0 to Size-1 do
      if Data1[I]<>Data2[I] then Exit;
    CompareData:=True;
  end;

  function StrTok(Source: PChar; Token: Char): PChar;
  const
    _TokenSource: PChar= nil;
  var
    P: PChar;
  begin
    if Source<>nil then _TokenSource:=Source;
    P:=StrScan(_TokenSource, Token);
    StrTok:=_TokenSource;
    if P<>nil then
    begin
      P^:=#0;
      Inc(P);
    end;
    _TokenSource:=P;
  end;

  function GetResString(ID: Word): PChar;
  const
    acString: array[0..100] of Char= '';
  begin
    LoadString(hInstance, ID, acString, SizeOf(acString));
    GetResString:=acString;
  end;

  procedure GlbError(ErrorCode: Integer; Info: Pointer);
  var
    acS: array[0..200] of Char;
    D: PErrorDlg;
  begin
    wvsprintf(acS, GetResString(str_Error+ErrorCode), Info^);
    MessageBeep(0);
    New(D, Init(acS));
    if Application^.ExecDialog(D)<>2 then Halt;
  end;

{== user settings functions ==}
  procedure CheckDatapath;
  var
    P: PChar;
    E1, E2, E3, E4: Boolean;
  begin
    E1:=GetPrivateProfileString(pf_Paths, 'Daten', nil, Datapath, fsDirectory, ProfileFile)=0;
    E2:=GetPrivateProfileString(pf_Paths, 'Programm', nil, Programpath, fsDirectory, ProfileFile)=0;
    E3:=GetPrivateProfileString(pf_Paths, 'Ordersätze', nil, OSPath, fsDirectory, ProfileFile)=0;
    E4:=GetPrivateProfileString(pf_Paths, 'Bestellungen', nil, BestellPath, fsDirectory, ProfileFile)=0;
    if E1 or E2 or E3 or E4 then GlbError(em_WrongWawisIni, nil);
    if (not FileExist(DatapathFile(GlobalsFile))) or
       (not FileExist(DatapathFile(ArtikelFile))) or
       (not FileExist(DatapathFile(LieferFile))) or
       (not FileExist(DatapathFile(BetriebeFile))) or
       (not FileExist(DatapathFile(EKListeFile))) then
    begin
      P:=Datapath;
      GlbError(em_DBFilesNotFound, @P);
    end;
  end;

  procedure ReadUserSettings;
  begin
    Debug:=GetPrivateProfileInt(pf_User, 'Debug', 0, ProfileFile)=1;
    if ParamStr(1)='/D' then Debug:=True;
    with UserSettings do
    begin
      WaitforKey:=GetPrivateProfileInt(pf_User, 'WaitforKey', 1, ProfileFile)=1;
      GetPrivateProfileString(pf_User, 'Name', 'unbenannt', Name, SizeOf(Name), ProfileFile);
      DefaultWindowSize:=GetPrivateProfileInt(pf_User, 'DefaultSize', 1, ProfileFile)=1;
      AutoDB:=GetPrivateProfileInt(pf_User, 'AutoDB', 1, ProfileFile)=1;
      DefaultArtikelSort:=GetPrivateProfileInt(pf_User, 'ArtikelKey', 1, ProfileFile);
      DefaultArtikelEKSort:=GetPrivateProfileInt(pf_User, 'ArtikelEKKey', 1, ProfileFile);
    end;
  end;

  procedure SaveUserSettings;
  var
    acS: array[0..10] of Char;
    W: Word;
  begin
    with UserSettings do
    begin
      WritePrivateProfileString(pf_User, 'Name', Name, ProfileFile);
      W:=Word(DefaultWindowSize);
      wvsprintf(acS, '%d', W);
      WritePrivateProfileString(pf_User, 'DefaultSize', acS, ProfileFile);
      W:=Word(AutoDB);
      wvsprintf(acS, '%d', W);
      WritePrivateProfileString(pf_User, 'AutoDB', acS, ProfileFile);
      wvsprintf(acS, '%d', DefaultArtikelSort);
      WritePrivateProfileString(pf_User, 'ArtikelKey', acS, ProfileFile);
      wvsprintf(acS, '%d', DefaultArtikelEKSort);
      WritePrivateProfileString(pf_User, 'ArtikelEKKey', acS, ProfileFile);
    end;
  end;

{== global settings functions ==}
  var GlbSettingsDB: PBFixed; 

  function ReadGlobalSettings: Boolean;
  begin
    New(GlbSettingsDB, Init(DatapathFile(GlobalsFile), Accel));
    if BStatus=0 then BStatus:=GlbSettingsDB^.BT(BStepFirst, 0);
    if BStatus=0 then Move(GlbSettingsDB^.DBuffer, GlobalSettings, SizeOf(GlobalSettings));
    ReadGlobalSettings:=BStatus=0;
    GlbSettingsDB^.Close;
    Dispose(GlbSettingsDB, Done);
  End;

  function LockGlobalSettings: Boolean;
  begin
    New(GlbSettingsDB, Init(DatapathFile(GlobalsFile), Accel));
    if BStatus=0 then BStatus:=GlbSettingsDB^.BT(BStepFirst, 0);
    LockGlobalSettings:=BStatus=0;
    if BStatus<>0 then
    begin
      GlbSettingsDB^.Close;
      Dispose(GlbSettingsDB, Done);
    end else
      Move(GlbSettingsDB^.DBuffer, GlobalSettings, SizeOf(GlobalSettings));
  end;

  function SaveGlobalSettings: Boolean;
  begin
    BStatus:=GlbSettingsDB^.BT(BDelete, 0);
    if BStatus=0 then
    begin
      Move(GlobalSettings, GlbSettingsDB^.DBuffer, SizeOf(GlobalSettings));
      BStatus:=GlbSettingsDB^.BT(BInsert, 0);
    end;
    SaveGlobalSettings:=BStatus=0;
    GlbSettingsDB^.Close;
    Dispose(GlbSettingsDB, Done);
  end;

{== local menu functions ==}
  var
    LocalMenuProc: TFarProc;
    hLocalMenuHook: HHook;

  function LocalMenuHook(Code: Integer; wParam: Word; lParam: LongInt): LongInt; export;
  var P: PMouseHookStruct absolute lParam;
  begin
    if (Code=hc_Action) and (wParam=wm_RButtonUp) then
    begin
      GlbLocalMenu:=nil;
      SendMessage(hMainWindow, wm_LocalMenu, 0, LongInt(P^.pt));
      if (GlbLocalMenu<>nil) and (IsWindowEnabled(GlbLocalMenuWin)) then
        PopupMenu(GlbLocalMenuWin, P^.pt, lm_MenuName, GlbLocalMenu);
    end;
    LocalMenuHook:=CallNextHookEx(hLocalMenuHook, Code, wParam, lParam);
  end;

  procedure InitLocalMenus;
  begin
    LocalMenuProc:=MakeIntResource(@LocalMenuHook);
    hLocalMenuHook:=SetWindowsHookEx(wh_Mouse, THookProc(LocalMenuProc),
      hInstance, GetCurrentTask);
  end;

  procedure DoneLocalMenus;
  begin
    UnHookWindowsHookEx(hLocalMenuHook);
    FreeProcInstance(LocalMenuProc);
  end;  

{== path functions ==}
  var
    acFileName: array[0..fsPathName] of Char;

  function DatapathFile(FName: PChar): PChar;
  begin
    if StrECopy(acFileName, Datapath)^<>'\' then StrCat(acFileName, '\');
    StrCat(acFileName, FName);
    DatapathFile:=acFileName;
  end;

  function BestellPathFile(FName: PChar): PChar;
  begin
    if StrECopy(acFileName, BestellPath)^<>'\' then StrCat(acFileName, '\');
    StrCat(acFileName, FName);
    BestellPathFile:=acFileName;
  end;

  function OSPathFile(FName: PChar; Data: LongInt): PChar;
  var acS: array[0..fsPathName] of Char;
  begin
    if StrECopy(acS, OSPath)^<>'\' then StrCat(acS, '\');
    StrCat(acS, FName);
    wvsprintf(acFileName, acS, Data);
    OSPathFile:=acFileName;
  end;

  function ProgramPathFile(FName: PChar): PChar;
  begin
    if StrECopy(acFileName, ProgramPath)^<>'\' then StrCat(acFileName, '\');
    StrCat(acFileName, FName);
    ProgramPathFile:=acFileName;
  end;


begin
  GlbBestellung:=(ParamStr(1)='/B') or (ParamStr(1)='/b');
end.