(********************************************************************)
(*                                                                  *)
(*               Hilfsunit CTL3D für Windows 3.1                    *)
(*          zur Verwaltung der CTL3D-DLL von Microsoft              *)
(*                                                                  *)
(*         Copyright 1994  c't 11/94, Heiko Stuckenberg             *)
(*                                                                  *)
(********************************************************************)

{$A+,B-,D+,F-,G+,I-,K+,L+,N+,P+,Q-,R-,S-,T-,V+,W-,X+,Y+}

unit Ctl3D;
interface
uses WinTypes,
     WinProcs,
     OWindows,
     ODialogs;

const
  {----------neue Nachrichten für Dialogboxfunktion------------------}

  WM_DLGBORDER   = WM_USER+3567;     {wParam=0; lParam=PInteger}
  WM_DLGSUBCLASS = WM_USER+3568;     {wParam=0; lParam=PInteger}

  {----------zugehörige Antwortkonstanten----------------------------}

  CTL3D_NOBORDER     = 0;            {Fensterrahmen nicht in 3D      }
  CTL3D_BORDER	     = 1;            {Fensterrahmen in 3D (Default)  }

  CTL3D_NOSUBCLASS   = 0;            {diesen Dialog nicht in 3D      }
  CTL3D_SUBCLASS     = 1;            {diesen Dialog in 3D (Default)  }

  {----------additive Flags für SubclassDlgEx------------------------}

  CTL3D_BUTTONS	     = $00000001;    {Kontrollflags für Elemente,    }
  CTL3D_LISTBOXES    = $00000002;    {die 3D erscheinen sollen.      }
  CTL3D_EDITS	     = $00000004;
  CTL3D_COMBOS	     = $00000008;
  CTL3D_STATICTEXTS  = $00000010;
  CTL3D_STATICFRAMES = $00000020;
  CTL3D_ALL	     = $0000FFFF;

  CTL3D_NODLGWINDOW  = $00010000;    {diesen Dialograhmen nicht in 3D}

type                                 
  DWord = longint;                   {Ersatz für Datentyp DWord      }

{------------DLL-Funktionen------------------------------------------}

function CTL3DRegister(     Instance : THandle ) : Bool;
         { False, wenn DLL fehlt oder Windows 95 läuft               }
function CTL3DUnregister(   Instance : THandle ) : Bool;
         { False, wenn noch ein Control die DLL benutzt, die DLL     }
         { fehlt, oder Windows 95 läuft                              }
function CTL3DAutoSubclass( Instance : THandle ) : Bool;
         { False, wenn DLL fehlt, Windows 3.0 läuft, zuviele         }
         { (max. 32) Applikationen die DLL benutzen, der CBT-Hook    }
         { nicht installierbar ist oder Windows 95 läuft             }
function CTL3DColorChange : Bool;
         { bei Fehler: Rückgabewert False                            }

function CTL3dSubclassDlgEx( WndDlg : HWnd; grbit : DWord ) : Bool;
         { False, wenn Dialog nicht subclassed werden konnte bzw.    }
         { DLL fehlt                                                 }
function CTL3DSubclassCtl(   WndCtl : HWnd ) : Bool;
         { False, wenn Control nicht gesubclassed werden konnte bzw. }
         { DLL fehlt                                                 }

function CTL3DCtlColorEx( Message : word;
                          wParam  : word; lParam : longint ) : HBrush;
         { Erzeugt abhängig vom Control für das sie aufgerufen wird  }
         { das passende Standard-Farb-Handle, welches nicht mehr     }
         { freigegeben werden muß. Bei Fehlern, z.B. fehlender DLL,  }
         { wird HBrush( 0 ) zurückgegeben                            }

function CTL3DAvailable : Bool;
{ False, wenn DLL fehlt }
function CTL3DEnabled   : Bool;
{ False, wenn DLL fehlt oder Windows 95 läuft }
function CTL3DGetVer    : word;
{ MSB : Hauptversionsnummer, z.B. 2; Null, wenn DLL fehlt }
{ LSB : Unterversionsnummer, z.B. 5; Null, wenn DLL fehlt }

{------------Standardobjekte-----------------------------------------}

type
  { Rahmenobjekt für Applikation, mit Automatik                      }
  P3DApplication = ^T3DApplication;
  T3DApplication = object( TApplication )
                     constructor Init( AName : PChar );
                     destructor  Done; virtual;
                   end;

  { Top-Level-Fenster für Anwendung (normales Fenster)               }
  P3DWindow = ^T3DWindow;
  T3DWindow = object( TWindow )
                procedure WMSysColorChange( var Msg : TMessage );
                  virtual wm_First + wm_SysColorChange;
              end;

  { Fenster für 3D-Controls                                          }
  P3DControlsWindow = ^T3DControlsWindow;
  T3DControlsWindow = object( T3DWindow )
                        procedure WMCTLColor( var Msg : TMessage );
                          virtual wm_First + wm_CTLColor;
                        procedure GetWindowClass(
                          var AWndClass : TWndClass ); virtual;
                      end;

  { Top-Level-Fenster für Anwendung (Dialogfenster)                  }
  P3DDlgWindow = ^T3DDlgWindow;
  T3DDlgWindow = object( TDlgWindow )
                   procedure WMInitDialog( var Msg : TMessage );
                     virtual wm_First + wm_InitDialog;
                   procedure WMSysColorChange( var Msg : TMessage );
                     virtual wm_First + wm_SysColorChange;
                 end;
  { Top-Level-Fenster für Anwendung (Dialog)                         }
  P3DDialog = ^T3DDialog;
  T3DDialog = object( TDialog )
                procedure WMInitDialog( var Msg : TMessage );
                  virtual wm_First + wm_InitDialog;
              end;

  { Dialogfenster, das bei "Automatik" 3D-Effekte ausschaltet        }
  P3DNoSubclassDialog = ^T3DNoSubclassDialog;
  T3DNoSubclassDialog = object( TDialog )
                          procedure WMDLGSubclass(var Msg : TMessage);
                            virtual wm_DLGSubclass;
                        end;

  { Dialogfenster, das trozt "Automatik" den Rahmen nicht verändert  }
  P3DNoBorderDialog = ^T3DNoBorderDialog;
  T3DNoBorderDialog = object( TDialog )
                        procedure WMDLGBorder( var Msg : TMessage );
                          virtual wm_DLGBorder;
                      end;

  { Controls, die 3D-Effekte in normalen Fenstern ermöglichen        }

  P3DButton = ^T3DButton;
  T3DButton = object( TButton )
                procedure SetupWindow; virtual;
              end;

  P3DCheckBox = ^T3DCheckBox;
  T3DCheckBox = object( TCheckBox )
                  procedure SetupWindow; virtual;
                end;

  P3DRadioButton = ^T3DRadioButton;
  T3DRadioButton = object( TRadioButton )
                     procedure SetupWindow; virtual;
                   end;

  P3DGroupBox = ^T3DGroupBox;
  T3DGroupBox = object( TGroupBox )
                  procedure SetupWindow; virtual;
                end;

  P3DListBox = ^T3DListBox;
  T3DListBox = object( TListBox )
                 procedure SetupWindow; virtual;
               end;

  P3DComboBox = ^T3DComboBox;
  T3DComboBox = object( TComboBox )
                  procedure SetupWindow; virtual;
                end;

  P3DStatic = ^T3DStatic;
  T3DStatic = object( TStatic )
                procedure SetupWindow; virtual;
              end;

  P3DEdit = ^T3DEdit;
  T3DEdit = object( TEdit )
              procedure SetupWindow; virtual;
            end;

{------------Arbeitsweise--------------------------------------------}
{ Abgebildet wird ein Teil der CTL3D-DLL von Microsoft zur Erzeugung }
{ von 3D-Effekten in Dialogboxen, etc. Die Unit kümmert sich um An-  }
{ und Abmeldung der DLL und stellt eine Defaultbehandlung zur Ver-   }
{ fügung, falls die DLL nicht vorhanden ist. In diesem Falle simu-   }
{ liert die Unit eine nicht korrekt arbeitende DLL, wobei sich       }
{ natürlich auch kein 3D-Effekt einstellt. Ist die DLL vorhanden, so }
{ liefern die Prozeduren auch Fehlermeldungen zurück, etwa wenn die  }
{ DLL von zuvielen Programmen gleichzeitig benutzt wird oder         }
{ Windows 95 läuft, welches von sich aus 3D-Effekte unterstützt.     }
{ Die zusätzliche Funktion CTL3DAvailable kann in diesem Fall heran- }
{ gezogen werden, um zwischen Windows 95 und fehlender DLL zu        }
{ unterscheiden.                                                     }
{--------------------------------------------------------------------}

implementation

type                                           {Pascal ist nicht C...}
  TInstanceFunc      = function( Instance : THandle ) : Bool;
  TSubclassDlgExFunc = function( WndDlg : HWnd;
                                 grbit  : DWord ) : Bool;
  TSubclassCtlFunc   = function( WndCtl : HWnd ) : Bool;
  TCtlColorExFunc    = function( Message : word;
                                 wParam  : word;
                                 lParam  : longint ) : HBrush;
  TGetVerFunc        = function : word;
  TBoolFunc          = function : Bool;

const
  HInstance_Error        = 32;              {Hilfskonstanten         }
  SEM_NoOpenFileErrorBox = 32768;           

  Register      : TInstanceFunc = nil;      {Die Aufrufadressen aus  }
  Unregister    : TInstanceFunc = nil;      {der DLL werden zwischen-}
  AutoSubclass  : TInstanceFunc = nil;      {gespeichert, um bei     }
  ColorChange   : TBoolFunc = nil;          {Fehlern eine Default-   }
  SubclassDlgEx : TSubclassDlgExFunc = nil; {routine ausführen zu    }
  SubclassCtl   : TSubclassCtlFunc = nil;   {können.                 }
  CtlColorEx    : TCtlColorExFunc = nil;
  GetVer        : TGetVerFunc = nil;
  Enabled       : TBoolFunc = nil;

  Available     : Bool = true;           {false, wenn DLL fehlt oder }
                                         {eine Funktion in DLL fehlt }
var
  DLL_Handle     : THandle;  {Ergebnis des LoadLibrary-Aufrufs       }
  Old_ErrorMode  : word;     {zwecks Unterdrückung von DLL-Ladefehler}
  Saved_ExitProc : pointer;  {In einer Exit-Procedure wird die DLL   }
                             {wieder freigegeben.                    }

{------------Hilfsfunktion-------------------------------------------}

procedure Free_DLL; far;                  {Exit-Procedure des Moduls,}
begin                                     {gibt ggf. die DLL wieder  }
  if DLL_Handle >= HInstance_Error then   {frei und ruft den nächsten}
    FreeLibrary( DLL_Handle );            {Exit-Handler in der Kette }
  ExitProc := Saved_ExitProc;             {auf.                      }
end;

{------------exportierte DLL-Funktionen------------------------------}

function CTL3DRegister( Instance : THandle ) : Bool;
begin
  CTL3DRegister := Available and Register( Instance )
end;

function CTL3DUnregister( Instance : THandle ) : Bool;
begin
  CTL3DUnregister := Available and Unregister( Instance );
end;

function CTL3DAutoSubclass( Instance : THandle ) : Bool;
begin
  CTL3DAutoSubclass := Available and AutoSubclass( Instance );
end;

function CTL3DColorChange : Bool;
begin
  CTL3DColorChange := Available and ColorChange;
end;

function CTL3dSubclassDlgEx( WndDlg : HWnd; grbit : DWord ) : Bool;
begin
  CTL3DSubclassDlgEx := Available and SubclassDlgEx( WndDlg, grbit );
end;

function CTL3DSubclassCtl( WndCtl : HWnd ) : Bool;
begin
  CTL3DSubclassCtl := Available and SubclassCtl( WndCtl );
end;

function CTL3DCtlColorEx( Message : word;
                          wParam  : word; lParam : longint ) : HBrush;
begin
  if Available then
    CTL3DCtlColorEx := CtlColorEx( Message, wParam, lParam )
  else
    CTL3DCtlColorEx := HBrush( 0 );
end;

function CTL3DAvailable : Bool;
begin
  CTL3DAvailable := Available;
end;

function CTL3DEnabled : Bool;
begin
  CTL3DEnabled := Available and Enabled;
end;

function CTL3DGetVer  : word;
begin
  if Available then
    CTL3DGetVer := GetVer
  else
    CTL3DGetVer := $0000;
end;

{------------exportierte Klassen-Methoden----------------------------}

constructor T3DApplication.Init( AName : PChar );
begin
  if CTL3DRegister( HInstance ) then CTL3DAutoSubclass( HInstance );
  inherited Init( AName );
end;

destructor  T3DApplication.Done;
begin
  inherited Done;
  CTL3DUnregister( HInstance );
end;

procedure T3DWindow.WMSysColorChange( var Msg : TMessage );
begin
  CTL3DColorChange;
end;

procedure T3DControlsWindow.WMCTLColor( var Msg : TMessage );
begin
  Msg.Result := CTL3DCtlColorEx( Msg.Message,
                                 Msg.wParam, Msg.lParam );
  if Msg.Result = 0 then begin
    DefWndProc( Msg );
  end;
end;

procedure T3DControlsWindow.GetWindowClass( var AWndClass:TWndClass );
begin
  inherited GetWindowClass( AWndClass );
  if CTL3DEnabled then begin
    AWndClass.hbrBackground := HBrush( COLOR_BTNFace+1 );
  end;
end;

procedure T3DDialog.WMInitDialog( var Msg : TMessage );
begin
  CTL3DSubclassDlgEx( HWindow, CTL3D_All );
  inherited WMInitDialog( Msg );
end;

procedure T3DDlgWindow.WMInitDialog( var Msg : TMessage );
begin
  CTL3DSubclassDlgEx( HWindow, CTL3D_All );
  inherited WMInitDialog( Msg );
end;

procedure T3DDlgWindow.WMSysColorChange( var Msg : TMessage );
begin
  CTL3DColorChange;
end;

procedure T3DNoSubclassDialog.WMDLGSubclass( var Msg : TMessage );
begin
  PInteger( Msg.lParam )^ := CTL3D_NoSubclass;
end;

procedure T3DNoBorderDialog.WMDLGBorder( var Msg : TMessage );
begin
  PInteger( Msg.lParam )^ := CTL3D_NoBorder;
end;

procedure T3DButton.SetupWindow;
begin
  CTL3DSubclassCtl( HWindow );
  inherited SetupWindow;
end;

procedure T3DCheckBox.SetupWindow;
begin
  CTL3DSubclassCtl( HWindow );
  inherited SetupWindow;
end;

procedure T3DRadioButton.SetupWindow;
begin
  CTL3DSubclassCtl( HWindow );
  inherited SetupWindow;
end;

procedure T3DGroupBox.SetupWindow;
begin
  CTL3DSubclassCtl( HWindow );
  inherited SetupWindow;
end;

procedure T3DListBox.SetupWindow;
begin
  CTL3DSubclassCtl( HWindow );
  inherited SetupWindow;
end;

procedure T3DComboBox.SetupWindow;
begin
  CTL3DSubclassCtl( HWindow );
  inherited SetupWindow;
end;

procedure T3DStatic.SetupWindow;
begin
  CTL3DSubclassCtl( HWindow );
  inherited SetupWindow;
end;

procedure T3DEdit.SetupWindow;
begin
  CTL3DSubclassCtl( HWindow );
  inherited SetupWindow;
end;

{------------Unit-Initialisierung------------------------------------}
{ Versucht die CTL3D-DLL zu laden, wobei eine Fehlermeldung mittels  }
{ 'SetErrorMode' unterdrückt wird. Anschließend werden die Adressen  }
{ der benötigten Prozeduren ermittelt und in den zugehörigen         }
{ Variablen gespeichert. Sollte irgendeine Prozedur nicht zur Verfü- }
{ gung stehen ('nil' wegen CONST-Initialisierung wenn DLL nicht ge-  }
{ funden, bzw. 'GetProcAddress' lieferte 'nil'), dann werden alle    }
{ Prozeduren mit Hilfe des Flags 'Available' für ungültig erklärt,   }
{ als wäre die DLL nicht vorhanden. Installiert wird ferner zu Be-   }
{ ginn ein Exithandler, der auch bei ungewolltem Programmabbruch die }
{ DLL ggf. wieder freigibt.                                          }
{--------------------------------------------------------------------}

begin
  Saved_ExitProc := ExitProc;
  ExitProc       := @Free_DLL;

  Old_ErrorMode := SetErrorMode( SEM_NoOpenFileErrorBox );
  DLL_Handle    := LoadLibrary( 'CTL3D.DLL' );
  SetErrorMode( Old_ErrorMode );

  if DLL_Handle >= HInstance_Error then begin
    @Register      := GetProcAddress( DLL_Handle, 'CTL3DRegister' );
    @Unregister    := GetProcAddress( DLL_Handle, 'CTL3DUnregister' );
    @AutoSubclass  := GetProcAddress( DLL_Handle,
                                                'CTL3DAutoSubclass' );
    @ColorChange   := GetProcAddress( DLL_Handle,
                                                 'CTL3DColorChange' );
    @SubclassDlgEx := GetProcAddress( DLL_Handle,
                                               'CTL3DSubclassDlgEx' );
    @SubclassCtl   := GetProcAddress( DLL_Handle,
                                                 'CTL3DSubclassCtl' );
    @CtlColorEx    := GetProcAddress( DLL_Handle, 'CTL3DCtlColorEx' );
    @GetVer        := GetProcAddress( DLL_Handle, 'CTL3DGetVer' );
    @Enabled       := GetProcAddress( DLL_Handle, 'CTL3DEnabled' );
  end;
  Available :=     (@Register <> nil)      and (@Unregister <> nil)
               and (@AutoSubClass <> nil)  and (@ColorChange <> nil)
               and (@SubclassDlgEx <> nil) and (@SubclassCtl <> nil)
               and (@CtlColorEx <> nil)    and (@GetVer <> nil)
               and (@Enabled <> nil);
end.
