{$I KIOSKCO.PAS}
{$M 16384,65536,655360}
Program Kiosk;
Uses
  Crt,
  Objects, Drivers, Views, Menus, App, MsgBox, HeapView, Calc, ClkView,
  KioskCmds, KioskRez, Drucker, Stamm, Artikel, Kunden, Lieferanten,
  Ordersatz, OSViews, OSActive, Orders, CurrOrd, StackDmp;

Type
  TKioskApp= Object(TApplication)
    ClockView: PClockView;
{$IFDEF DEBUG}
    HeapView: PHeapView;
{$ENDIF}
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
  InitRez;
  TApplication.Init;
  { Clockviewer }
  R.Assign(70, 0, 80, 1);
  ClockView:=New(PClockView, Init(R));
  Insert(ClockView);
{$IFDEF DEBUG}
  { Heapviewer }
  R.Assign(70, 24, 80, 25);
  HeapView:=New(PHeapView, Init(R));
  Insert(HeapView);
{$ENDIF}
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
  MessageBox('Kioskverwaltung für Norkus & Blaaß'#13#13+
     '    (C) 1991 by Olaf Gottschalk', nil, mfInformation+mfOKButton);
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
  If (Event.What=evBroadcast) And (Event.Command=cmDeskTopInsert) Then
  Begin
    DeskTop^.Insert(PView(Event.InfoPtr));
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
  ClockView^.UpDate;
{$IFDEF DEBUG}
  HeapView^.UpDate;
{$ENDIF}
End;

Procedure TKioskApp.OutOfMemory;
Begin
  MessageBox('Achtung - Zu wenig freier Speicher !', nil, mfWarning+mfOkButton);
End;

Var
  KioskApp: TKioskApp;

Begin
  KioskApp.Init;
  KioskApp.Run;
  KioskApp.Done;
End.