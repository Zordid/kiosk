{$I KIOSKCO.PAS}
{$M 16384,65536,655360}
Program Kiosk;
Uses
  Crt, Objects, Drivers, Views, Menus, App, MsgBox, Calc, 
  KioskCmds, KioskRez, Drucker, Stamm, Artikel, Kunden, Lieferanten,
  Ordersatz, OSViews, OSActive, Orders, CurrOrd, StackDmp;

Const
  Copyright= '(C) 1991-93 by Olaf Gottschalk';
  Version= '1.2C';
  LastChange= '25.11.93';

Type
  TKioskApp= Object(TApplication)
    Constructor Init;
    Procedure InitMenuBar; virtual;
    Procedure InitStatusLine; virtual;
    Procedure HandleEvent(Var Event: TEvent); virtual;
    Procedure OutOfMemory; virtual;
    Procedure About(TestMem: Boolean);
    Procedure Idle; virtual;
    Destructor Done; virtual;
  End;

Constructor TKioskApp.Init;
Var R: TRect;
Begin
  DeskJet:=(ParamStr(1)='deskjet');
  InitRez;
  TApplication.Init;
  { Dateien öffnen }
  OpenLieferanten;
  OpenKunden;
  OpenArtikel;
  OpenActiveList;
  OpenCurrentOrders;
  LoadDruckOpt;
  DisableCommands(OSCmds+OrderCmds+[cmCurrSumUp]);
  { Copyright meldung }
  About(True);
  EditCurrentOrders;
End;

Procedure TKioskApp.InitMenuBar;
Begin
  MenuBar:=PMenuBar(Rez^.Get('MenuBar'));
End;

Procedure TKioskApp.InitStatusLine;
Begin
  StatusLine:=PStatusLine(Rez^.Get('StatusLine'));
End;

Procedure TKioskApp.About(TestMem: Boolean);
Var
  D: LongInt;
  E: TEvent;
Begin
  MessageBox(
     ^C'Kioskverwaltung für Norkus & Blaaß'#13+
     ^C'Version '+Version+' ('+LastChange+')'#13+
     ^C+Copyright, nil, mfInformation+mfOKButton);
  If TestMem And (MemAvail<30*1024) Then
  Begin
    D:=MemAvail Div 1024;
    If MessageBox('Achtung: Nur %d KB Speicher frei !'#13+
      'Soll Programm abgebrochen werden ?', @D, mfWarning+mfYesNoCancel)=cmYes Then
    Begin
      E.What:=evCommand;
      E.Command:=cmQuit;
      PutEvent(E);
    End;
  End;
End;

Procedure TKioskApp.HandleEvent(Var Event: TEvent);
Begin
  TApplication.HandleEvent(Event);
  If Event.What=evCommand Then
  Begin
    Case Event.Command Of
      { System }
      cmAbout: About(False);
      cmDruckOptOS, cmDruckOptOrder: EditDruckOpt(Event.Command-cmDruckOptOS);
      cmCalculator: DeskTop^.Insert(New(PCalculator, Init));
      { Bestellungen }
      cmCurrentOrderList: EditCurrentOrders;
      cmBestellung: Bestellung_Annehmen;
      { Ordersätze }
      cmLoadOS: LoadOS;
      cmNewOS: DeskTop^.Insert(New(POSEditor, Init(New(POrdersatz, Init))));
      cmActiveList: EditActiveList;
      { Stamm }
      cmArtikelstamm: Artikelstamm^.Edit;
      cmKundenstamm: Kundenstamm^.Edit;
      cmLieferantenstamm: Lieferantenstamm^.Edit;
      Else Exit;
    End;
    ClearEvent(Event);
  End;
End;

Destructor TKioskApp.Done;
Begin
  CloseCurrentOrders;
  CloseActiveList;
  CloseArtikel;
  CloseKunden;
  CloseLieferanten;
  TApplication.Done;
  DoneRez;
End;

Procedure TKioskApp.Idle;
Begin
  TApplication.Idle;
 End;

Procedure TKioskApp.OutOfMemory;
Begin
  MessageBox(
    ^C'Achtung - Zu wenig freier Speicher!'#13+
    'Es wird empfohlen, die Arbeit JETZT zu beenden, um Datenverlust '+
    'zu verhindern!', nil, mfWarning+mfOkButton);
End;

Var
  KioskApp: TKioskApp;

Begin
  KioskApp.Init;
  KioskApp.Run;
  KioskApp.Done;
End.