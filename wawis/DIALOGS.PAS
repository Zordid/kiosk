unit Dialogs;
interface
  uses
    Objects, OWindows, ODialogs,
    WinTypes, WinProcs, WinDos, BWCC, BtpWin, Strings, Win31,
    DlgObj, Globals;

  type
    TExportOptions= record
      AllData, SelectedData: Word;
      ToClipboard, ToFile: Word;
      AFileName: array[0..79] of Char;
      ToAnsi, ToOem: Word;
      UseTab, UseSpace, UseKomma, UseSonst: Word;
      AChar: array[0..1] of Char;
    end;

  type
    PSortDlg= ^TSortDlg;
    TSortDlg= object(TDialog)
      Keypath: ^Integer;
      Text: PChar;
      constructor Init(AParent: PWindowsObject; AText, AName: PChar); 
      procedure SetupWindow; virtual;
      procedure Ok(Var Msg: TMessage); virtual id_First+id_Ok;
    end;

    PExportDlg= ^TExportDlg;
    TExportDlg= object(TDialog)
      constructor Init;
    end;

    PSystemDlg= ^TSystemDlg;
    TSystemDlg= object(TDialog)
      constructor Init;
      procedure SetupWindow; virtual;
      procedure Ok(var Msg: TMessage); virtual id_First+id_Ok;
    End;

    PUserDlg= ^TUserDlg;
    TUserDlg= object(TDialog)
      U: TUserSettings;
      constructor Init;
      procedure SetupWindow; virtual;
      procedure ArtikelSort(var Msg: TMessage); virtual id_First+id_ArtikelSort;
      procedure ArtikelEKSort(var Msg: TMessage); virtual id_First+id_ArtikelEKSort; 
      procedure Ok(var Msg: TMessage); virtual id_First+id_Ok;
    end;

    PInfoDlg= ^TInfoDlg;
    TInfoDlg= object(TDialog)
      InfoShown: Boolean;
      constructor Init;
      procedure SetupWindow; virtual;
      procedure Info(var Msg: TMessage); virtual id_First+id_Info;
      procedure AboutGS(var Msg: TMessage); virtual id_First+id_AboutGS;
    end;

    PDeleteDlg= ^TDeleteDlg;
    TDeleteDlg= object(TDialog)
      Text: PChar;
      All: Boolean;
      constructor Init(AText: PChar; AnAll: Boolean);
      procedure SetupWindow; virtual;
      procedure IDYes(var Msg: TMessage); virtual id_First+id_Yes;
      procedure IDNo(var Msg: TMessage); virtual id_First+id_No;
      procedure IDAll(var Msg: TMessage); virtual id_First+id_All;
    end;

    PErrorDlg= ^TErrorDlg;
    TErrorDlg= object(TDialog)
      Text: PChar;
      constructor Init(AText: PChar);
      procedure SetupWindow; virtual;
      procedure Abort(var Msg: TMessage); virtual id_First+id_Abort;
      procedure Ignore(var Msg: TMessage); virtual id_First+id_Ignore;
      procedure WasNun(var Msg: TMessage); virtual id_First+id_WasNun;
    end;

  PPrintFaxDlg= ^TPrintFaxDlg;
  TPrintFaxDlg= object(TDialog)
    Lieferant: PChar;
    constructor Init(ALieferant: PChar);
    procedure SetupWindow; virtual;
    procedure Fax(var Msg: TMessage); virtual id_First+id_Fax;
    procedure Print(var Msg: TMessage); virtual id_First+id_Print;
  end;    

  procedure CenterStaticBmp(Dialog: HWnd; Bmp, Center: Integer);

implementation

  procedure CenterStaticBmp(Dialog: HWnd; Bmp, Center: Integer);
  var
    R, CR: TRect;
    P: TPoint;
  begin
    GetClientRect(GetDlgItem(Dialog, Bmp), R);
    GetWindowRect(GetDlgItem(Dialog, Center), CR);
    P.X:=CR.Left; P.Y:=CR.Top;
    ScreenToClient(Dialog, P);
    Inc(P.X, (CR.Right-CR.Left-R.Right) Div 2);
    Inc(P.Y, (CR.Bottom-CR.Top-R.Bottom) Div 2);
    MoveWindow(GetDlgItem(Dialog, Bmp), P.X, P.Y, R.Right, R.Bottom, True);
  end;

{
** == TSortDlg (Object) ==
**
** sortkey dialog box
**
}
  constructor TSortDlg.Init(AParent: PWindowsObject; AText, AName: PChar);
  begin
    TDialog.Init(AParent, AName);
    Text:=AText;
  end;

  Procedure TSortDlg.SetupWindow;
  Begin
    TDialog.SetupWindow;
    SendDlgItemMsg(id_Sort+Keypath^-1, BM_SETCHECK, 1, 0);
    if Text<>nil then SetWindowText(hWindow, Text);
  End;

  Procedure TSortDlg.Ok(Var Msg: TMessage);
  Begin
    Keypath^:=1;
    While SendDlgItemMsg(ID_SORT+Keypath^-1, BM_GETCHECK, 0, 0)<>1 Do Inc(Keypath^);
    TDialog.Ok(Msg);
  End;

{
** == TExportDlg (Object) ==
**
** export dialog box
**
}
  type
    PSpecRadio= ^TSpecRadio;
    TSpecRadio= object(TRadioButton)
      LinkedID: Word;
      procedure BNClicked(var Msg: TMessage); virtual nf_First+bn_Clicked;
      procedure BMSetCheck(var Msg: TMessage); virtual wm_First+bm_SetCheck;
    end;

  procedure TSpecRadio.BNClicked;
  begin
    TRadioButton.BNClicked(Msg);
    EnableWindow(GetDlgItem(Parent^.hWindow, LinkedID), GetCheck=bf_Checked);
    SetFocus(GetDlgItem(Parent^.hWindow, LinkedID));
  end;

  procedure TSpecRadio.BMSetCheck;
  begin
    EnableWindow(GetDlgItem(Parent^.hWindow, LinkedID), Msg.wParam=bf_Checked);
    DefWndProc(Msg);
  end;

  Constructor TExportDlg.Init;
  Var
    S: PSpecRadio;
    R: PRadioButton;
    E: PEdit;
  Begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(ExportDlg));
    New(R, InitResource(@Self, id_Everything));
    New(R, InitResource(@Self, id_Focused));
    New(R, InitResource(@Self, id_Clipboard));
    New(S, InitResource(@Self, id_File));
    S^.LinkedID:=id_FileName;
    New(E, InitResource(@Self, id_FileName, 80));
    New(R, InitResource(@Self, id_Ansi));
    New(R, InitResource(@Self, id_OEM));
    New(R, InitResource(@Self, id_Tab));
    New(R, InitResource(@Self, id_Space));
    New(R, InitResource(@Self, id_Komma));
    New(S, InitResource(@Self, id_Sonst));
    S^.LinkedID:=id_SonstChar;
    New(E, InitResource(@Self, id_SonstChar, 2));
  End;

{
** == TSystemDlg (Object) ==
**
** system settings dialog box
**
}
  Constructor TSystemDlg.Init;
  Var
    E: PEdit;
    I: Integer;
  Begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(SystemDlg));
    For I:=1 To 10 Do
      New(E, InitResource(@Self, id_Warengruppe+I-1, 20));
    For I:=0 To 2 Do
      New(E, InitResource(@Self, id_MwStSatz+I, 5));
  End;

  Procedure TSystemDlg.SetupWindow;
  Var
    I, C: Integer;
    S: Array[0..7] Of Char;
  Begin
    TDialog.SetupWindow;
    SetDlgItemText(hWindow, id_ProgramPath, ProgramPath);
    SetDlgItemText(hWindow, id_DataPath, DataPath);
    SetDlgItemText(hWindow, id_OSPath, OSPath);
    SetDlgItemText(hWindow, id_BestellPath, BestellPath);
    With GlobalSettings Do
    Begin
      For I:=1 To 10 Do
        SetDlgItemText(hWindow, id_Warengruppe+I-1, Warengruppe[I]);
      For I:=0 To 2 Do
      Begin
        Str(MwSt[I]:0:1, S);
        C:=0;
        While S[C]<>#0 Do
        Begin
          If S[C]='.' Then S[C]:=',';
          Inc(C);
        End;
        SetDlgItemText(hWindow, id_MwStSatz+I, S);
      End;
    End;
  End;

  Procedure TSystemDlg.Ok(Var Msg: TMessage);
  Var
    I, C: Integer;
    V: Real;
    G: TGlobalSettings;
    S: Array[0..7] Of Char;
  Begin
    With G Do
    Begin
      For I:=1 To 10 Do
        GetDlgItemText(hWindow, id_Warengruppe+I-1, Warengruppe[I], 20);
      For I:=0 To 2 Do
      Begin
        GetDlgItemText(hWindow, id_MwStSatz+I, S, 5);
        C:=0;
        While S[C]<>#0 Do
        Begin
          If S[C]=',' Then S[C]:='.';
          Inc(C);
        End;
        Val(S, V, C);
        If C<>0 Then
        Begin
          MessageBox(0, 'Falscher Wert', Title, MB_ICONHAND Or MB_OK);
          Exit;
        End;
        MwSt[I]:=V;
        GetDlgItemText(hWindow, id_MwStSatz+I, MwStString[I], 5);
        lstrcat(MwStString[I], ' %');
      End;     
    End;
    GlobalSettings:=G;
    TDialog.Ok(Msg);
  End;

{
** == TUserDlg (Object) ==
**
** user settings dialog box
**
}
  Constructor TUserDlg.Init;
  Var E: PEdit;
  Begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(UserDlg));
    New(E, InitResource(@Self, id_UserName, 20));
    U:=UserSettings;
  End;

  Procedure TUserDlg.SetupWindow;
  Begin
    TDialog.SetupWindow;
    SetDlgItemText(hWindow, id_UserName, U.Name);
    SendDlgItemMsg(id_DefaultWinSize, BM_SETCHECK, Word(U.DefaultWindowSize), 0);
    SendDlgItemMsg(id_AutoDB, BM_SETCHECK, Word(U.AutoDB), 0);
  End;

  Procedure TUserDlg.ArtikelSort(Var Msg: TMessage);
  Var D: PSortDlg;
  Begin
    New(D, Init(@Self, 'Sortierung im Artikelfenster', MakeIntResource(ArtikelSortDlg)));
    D^.Keypath:=@U.DefaultArtikelSort;
    Application^.ExecDialog(D);
  End;

  procedure TUserDlg.ArtikelEKSort;
  var D: PSortDlg;
  begin
    New(D, Init(@Self, 'Sortierung in der Einkaufsliste', MakeIntResource(ArtikelSortDlg)));
    D^.Keypath:=@U.DefaultArtikelEKSort;
    Application^.ExecDialog(D);
  end;

  Procedure TUserDlg.Ok(Var Msg: TMessage);
  Begin
    GetDlgItemText(hWindow, id_UserName, U.Name, 20);
    U.DefaultWindowSize:=Boolean(SendDlgItemMsg(id_DefaultWinSize, BM_GETCHECK, 0, 0));
    U.AutoDB:=Boolean(SendDlgItemMsg(id_AutoDB, BM_GETCHECK, 0, 0));
    UserSettings:=U;
    TDialog.Ok(Msg);
  End;   

{
** == TInfoDlg (Object) ==
**
** information dialog box
**
}
  Constructor TInfoDlg.Init;
  Begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(InfoDlg));
    InfoShown:=False;
  End;

  Procedure TInfoDlg.SetupWindow;
  Type
    TVerInfo= record
      WinVerMajor,
      WinVerMinor,
      DosVerMinor,
      DosVerMajor: Byte;
    end;
    TBWCCVer= record
      VerMinor,
      VerMajor: Byte;
      Locale: Word;
    end;
  Var
    acS: Array[0..40] Of Char;
    acS2: Array[0..5] Of Char;
    bfR: TRecMgr;
    V: TVerInfo;
    B: TBWCCVer;
  Begin
    TDialog.SetupWindow;
    SetWindowText(GetItemHandle(id_CopyrightInfo), Copyright);
    SetWindowText(GetItemHandle(id_VersionInfo), Version);
    LongInt(V):=GetVersion;
    Str(V.WinVerMajor, acS);
    Str(V.WinVerMinor:2, acS2);
    if acS2[0]=' ' then acS2[0]:='0';
    StrCat(StrCat(acS, '.'), acS2);
    SetWindowText(GetItemHandle(id_WinVersion), acS);
    Str(V.DosVerMajor, acS);
    Str(V.DosVerMinor:2, acS2);
    if acS2[0]=' ' then acS2[0]:='0';
    StrCat(StrCat(acS, '.'), acS2);
    SetWindowText(GetItemHandle(id_DosVersion), acS);
    LongInt(B):=BWCCGetVersion;
    Str(B.VerMajor, acS);
    Str(B.VerMinor:2, acS2);
    if acS2[0]=' ' then acS2[0]:='0';
    StrCat(StrCat(acS, '.'), acS2);
    SetWindowText(GetItemHandle(id_BWCCVersion), acS);
    Str(MemAvail Div 1024, acS);
    StrCat(acS, ' KBytes');
    SetWindowText(GetItemHandle(id_Memory), acS);
    acS2[0]:=Upcase(Datapath[0]); acS2[1]:=#0;
    Str(DiskFree(Byte(acS2[0])-Byte('A')+1) Div (1024), acS);
    StrCat(StrCat(StrCat(acS, ' KBytes (Laufwerk '), acS2), ':)');
    SetWindowText(GetItemHandle(id_DiskFree), acS);
    bfR.Init;
    SetWindowText(GetItemHandle(id_BtrieveVersion), bfr.VersionString);
    bfR.Done;
    CenterStaticBmp(hWindow, id_WawisLogo, id_WawisLogoCenter);
    CenterStaticBmp(hWindow, id_QuickboxLogo, id_QuickboxLogoCenter);
    ShowWindow(hWindow, sw_Show);
  End;

  procedure TInfoDlg.Info;
  var
    w, s1, s2: Word;
  begin
    InfoShown:=Not InfoShown;
    if InfoShown then
    begin
      s1:=sw_Hide;
      s2:=sw_Show;
    end else
    begin
      s1:=sw_Show;
      s2:=sw_Hide;
    end;
    ShowWindow(GetItemHandle(11), s1);
    for w:=id_WinVersion to id_DiskFree+1 do
      ShowWindow(GetItemHandle(w), s2);
    if InfoShown and Debug then
      ShowWindow(GetItemHandle(id_Debug), sw_Show)
    else
      ShowWindow(GetItemHandle(id_Debug), sw_Hide);
  end;

  procedure TInfoDlg.AboutGS;
  var
    Addr: TFarProc;
    ShowAboutGS: function(WndParent: HWnd): Boolean;
    Lib: THandle;
  begin
    Lib:=LoadLibrary('GSINFO.DLL');
    if Lib>=32 then
    begin
      Addr:=GetProcAddress(Lib, 'AboutGS');
      Move(Addr, ShowAboutGS, SizeOf(Addr));
      ShowAboutGS(hWindow);
      FreeLibrary(Lib);
    end;
  end;

{== TDeleteDlg ==}
  constructor TDeleteDlg.Init(AText: PChar; AnAll: Boolean);
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(DeleteDlg));
    Text:=AText;
    All:=AnAll;
  end;

  procedure TDeleteDlg.SetupWindow;
  begin
    TDialog.SetupWindow;
    SetDlgItemText(hWindow, id_Text, Text);
    EnableWindow(GetItemHandle(id_All), All);
  end;

  procedure TDeleteDlg.IDYes;
  begin
    EndDlg(id_Yes);
  end;

  procedure TDeleteDlg.IDNo;
  begin
    EndDlg(id_No);
  end;

  procedure TDeleteDlg.IDAll;
  begin
    EndDlg(id_All);
  end;

{== TErrorDlg ==}
  constructor TErrorDlg.Init(AText: PChar);
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(ErrorDlg));
    Text:=AText;
  end;

  procedure TErrorDlg.SetupWindow;
  var
    R, R2: TRect;
    tp: TPoint;
  begin
    TDialog.SetupWindow;
    GetWindowRect(hWindow, R);
    R2.Right:=GetSystemMetrics(SM_CXSCREEN);
    R2.Bottom:=GetSystemMetrics(SM_CYSCREEN);
    tp.x:=(R2.Right-(R.Right-R.Left)) div 2;
    tp.y:=(R2.Bottom-(R.Bottom-R.Top)) div 2;
    SetWindowPos(hWindow, 0, tp.x, tp.y, 0, 0, swp_NoSize);
    if Debug then ShowWindow(GetItemHandle(id_Ignore), sw_Show);
    SetWindowText(GetItemHandle(100), Text);
  end;

  procedure TErrorDlg.Abort;
  begin
    EndDlg(1);
  end;

  procedure TErrorDlg.Ignore;
  begin
    EndDlg(2);
  end;

  procedure TErrorDlg.WasNun;
  var D: PDialog;
  begin
    New(D, Init(@Self, MakeIntResource(ProblemDlg)));
    Application^.ExecDialog(D);
  end;

  constructor TPrintFaxDlg.Init(ALieferant: PChar);
  begin
    TDialog.Init(Application^.MainWindow, MakeIntResource(PrintFaxDlg));
    Lieferant:=ALieferant; 
  end;

  procedure TPrintFaxDlg.SetupWindow;
  begin
    TDialog.SetupWindow;
    SetWindowText(GetItemHandle(id_Lieferant), Lieferant);
  end;

  procedure TPrintFaxDlg.Fax;
  begin
    EndDlg(id_Fax);
  end;

  procedure TPrintFaxDlg.Print;
  begin
    EndDlg(id_Print);
  end;

End.