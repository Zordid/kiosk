Program MakeRez;
Uses
  Objects, Drivers, Views, Dialogs, Fields, Menus,
  KioskCmds, KioskRez, Stamm, Artikel, Kunden, Lieferanten,
  Ordersatz, OSActive, Orders, CurrOrd;
  
Var
  Strm: PBufStream;
  Rez: TResourceFile;
  R: TRect;
  Control: PView;
  Labl: PLabel;

Procedure CreateMenuBar;
Var
  MenuBar: PMenuBar;
Begin
  R.Assign(0, 0, 80, 1);
  MenuBar:=New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('S~y~stem', hcNoContext, NewMenu(
      NewItem('Programm~i~nfo...', '', kbNoKey, cmAbout, hcNoContext,
      NewSubMenu('~D~rucker Einstellungen', hcNoContext, NewMenu(
        NewItem('Optionen für ~O~rdersätze...', '', kbNoKey, cmDruckOptOS, hcNoContext,
        NewItem('Optionen für ~B~estellungen...', '', kbNoKey, cmDruckOptOrder, hcNoContext,
        nil))),
      NewItem('~T~aschenrechner', '', kbNoKey, cmCalculator, hcNoContext,
      NewLine(
      NewItem('~E~nde', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      nil)))))),
    NewSubMenu('~B~estellungen', hcNoContext, NewMenu(
      NewItem('Aktuelle ~B~estellungen...', 'F8', kbF8, cmCurrentOrderList, hcNoContext,
      NewLine(
      NewItem('~A~nnehmen (Neu)...', 'F4', kbF4, cmBestellung, hcNoContext,
      NewItem('~S~ichern', 'F2', kbF2, cmSaveOrder, hcNoContext,
      NewLine(
      NewSubMenu('~K~undenspez. Belegung', hcNoContext, NewMenu(
        NewItem('~S~etzen...', '', kbNoKey, cmInsSpez, hcNoContext,
        NewItem('~L~öschen...', '', kbNoKey, cmDelSpez, hcNoContext,
        NewItem('~A~lle löschen...', '', kbNoKey, cmDelAllSpez, hcNoContext,
        nil)))),
      nil))))))),
    NewSubMenu('~O~rdersätze', hcNoContext, NewMenu(
      NewItem('~L~aden...', '', kbNoKey, cmLoadOS, hcNoContext,
      NewItem('~N~eu', '', kbNoKey, cmNewOS, hcNoContext,
      NewItem('~S~ichern...', 'F2', kbF2, cmStoreOS, hcNoContext,
      NewItem('~D~rucken', '', kbNoKey, cmPrintOS, hcNoContext,
      NewLine(
      NewItem('~W~arengruppen', '', kbNoKey, cmWGruppen, hcNoContext,
      NewItem('~A~ktivliste bearbeiten...', '', kbNoKey, cmActiveList, hcNoContext,
      nil)))))))),
    NewSubMenu('~S~tammdaten', hcNoContext, NewMenu(
      NewItem('~A~rtikelstamm...', '', kbNoKey, cmArtikelstamm, hcNoContext,
      NewItem('~K~undenstamm...', '', kbNoKey, cmKundenstamm, hcNoContext,
      NewItem('~L~ieferanten...', '', kbNoKey, cmLieferantenstamm, hcNoContext,
      nil)))),
    NewSubMenu('~F~enster', hcNoContext, NewMenu(
      NewItem('~G~röße/Bewegen', 'Strg-F5', kbCtrlF5, cmResize, hcNoContext,
      NewItem('~Z~oom', 'F5', kbF5, cmZoom, hcNoContext,
      NewItem('~N~ächstes', 'F6', kbF6, cmNext, hcNoContext,
      NewItem('~V~orheriges', 'Shift-F6', kbShiftF6, cmPrev, hcNoContext,
      NewItem('~S~chließen', 'Alt-F3', kbAltF3, cmClose, hcNoContext,
      nil)))))),
    nil)))))
  )));
  Rez.Put(MenuBar, 'MenuBar');
  Dispose(MenuBar, Done);
End;

Procedure CreateStatusLine;
Var
  StatusLine: PStatusLine;
Begin
  R.Assign(0, 24, 80, 25);
  StatusLine:=New(PStatusLine, Init(R,
    NewStatusDef(0, 999,
      NewStatusKey('~F4~ Bestellung annehmen', kbF4, cmBestellung,
      NewStatusKey('~F8~ Aktuelle Bestellungen', kbF8, cmCurrentOrderList,
      NewStatusKey('~F10~ Menü', kbF10, cmMenu,
      NewStatusKey('~Alt-X~ Ende', kbAltX, cmQuit,
      nil)))),
    NewStatusDef(hcListEdit, hcListEdit,
      NewStatusKey('~Enter~ Ändern', kbNoKey, cmEdit,
      NewStatusKey('~Eingf~ Einfügen', kbIns, cmInsert,
      NewStatusKey('~Entf~ Entfernen', kbDel, cmDelete,
      NewStatusKey('~F7~ Suchen', kbF7, cmSearch,
      NewStatusKey('~Esc~ Schließen', kbEsc, cmClose,
      nil))))),
    NewStatusDef(hcItem, hcItem,
      NewStatusKey('~Tab~ Nächstes Feld', kbNoKey, 0,
      NewStatusKey('~Enter~ Änderungen übernehmen', kbEnter, cmOK,
      NewStatusKey('~Esc~ Abbruch', kbEsc, cmCancel,
      nil))),
    NewStatusDef(hcOSEditor, hcOSEditor,
      NewStatusKey('~F2~ Sichern', kbF2, cmStoreOS,
      NewStatusKey('~F3~ Gruppen', kbF3, cmWGruppen,
      NewStatusKey('~Enter~ Artikelstamm', kbNoKey, 0,
      NewStatusKey('~Einfg~ Einfüge-/Überschreibmodus', kbNoKey, 0,
      nil)))),
    NewStatusDef(hcBestellung, hcBestellung,
      NewStatusKey('~F2~ Sichern (Ende der Bestellung)', kbF2, cmSaveOrder,
      NewStatusKey('~Enter~ Bestellen', kbNoKey, 0,
      nil)),
    NewStatusDef(hcCurrListDlg, hcCurrListDlg,
      NewStatusKey('~F4~ Annehmen', kbF4, cmBestellung,
      NewStatusKey('~Enter~ Ansehen', kbNoKey, cmCurrView,
      NewStatusKey('~Leer~ Markieren', kbNoKey, 0,
      NewStatusKey('~Entf~ Löschen', kbDel, cmDelete,
      NewStatusKey('~Esc~ Schließen', kbEsc, cmClose,
      nil))))),
    NewStatusDef(hcOrderViewer, hcOrderViewer,
      NewStatusKey('~Alt-D~ Drucken', kbAltD, cmPrintOrder,
      NewStatusKey('~Alt-E~ Ändern', kbAltE, cmEditOrder,
      NewStatusKey('~Esc~ Schließen', kbEsc, cmClose,
      nil))),
    NewStatusDef(hcListUse, hcListUse,
      NewStatusKey('~Enter~ Wählen', kbNoKey, cmOk,
      NewStatusKey('~F7~ Suchen', kbF7, cmSearch,
      nil)),
    nil))))))))
  ));
  Rez.Put(StatusLine, 'StatusLine');
  Dispose(StatusLine, Done);
End;

Procedure CreateArtikelDialog;
Var
  D: PArtikelDialog;
Begin
  R.Assign(8, 2, 71, 17);
  D:=New(PArtikelDialog, Init(R, 'Artikelsatz'));
  With D^ Do
  Begin
    HelpCtx:=hcItem;
    R.Assign(2,3,34,4);
    Control := New(PKeyInputLine, Init(R, 30));
    Insert(Control);
    R.Assign(2,2,14,3);
    Labl := New(PLabel, Init(R, '~B~ezeichnung', Control));
    Insert(Labl);
    R.Assign(36,3,48,4);
    Control := New(PInputLine, Init(R, 10));
    Insert(Control);
    R.Assign(36,2,42,3);
    Labl := New(PLabel, Init(R, '~M~enge', Control));
    Insert(Labl);
    R.Assign(2,6,14,7);
    Control := New(PLfrInputLine, Init(R, 10));
    Insert(Control);
    R.Assign(2,5,12,6);
    Labl := New(PLabel, Init(R, '~L~ieferant', Control));
    Insert(Labl);
    R.Assign(16,6,28,7);
    Control := New(PInputLine, Init(R, 10));
    Insert(Control);
    R.Assign(16,5,26,6);
    Labl := New(PLabel, Init(R, '~A~rtikelnr', Control));
    Insert(Labl);
    R.Assign(7,9,19,10);
    Control := New(PRealInputLine, Init(R, 10, 2, 0.0, 0.0));
    Insert(Control);
    R.Assign(20,9,30,10);
    Control := New(PInputLine, Init(R, 8));
    Insert(Control);
    R.Assign(31,9,43,10);
    Control := New(PRealInputLine, Init(R, 10, 2, 0.0, 0.0));
    Insert(Control);
    R.Assign(46,9,58,10);
    Control := New(PRealInputLine, Init(R, 10, 2, 0.0, 0.0));
    Insert(Control);
    R.Assign(7,10,19,11);
    Control := New(PRealInputLine, Init(R, 10, 2, 0.0, 0.0));
    Insert(Control);
    R.Assign(20,10,30,11);
    Control := New(PInputLine, Init(R, 8));
    Insert(Control);
    R.Assign(31,10,43,11);
    Control := New(PRealInputLine, Init(R, 10, 2, 0.0, 0.0));
    Insert(Control);
    R.Assign(46,10,58,11);
    Control := New(PRealInputLine, Init(R, 10, 2, 0.0, 0.0));
    Insert(Control);
    R.Assign(44,9,45,10);
    Control := New(PStaticText, Init(R, '-'));
    Insert(Control);
    R.Assign(44,10,45,11);
    Control := New(PStaticText, Init(R, '-'));
    Insert(Control);
    R.Assign(2,9,6,10);
    Control := New(PStaticText, Init(R, 'Ost:'));
    Insert(Control);
    R.Assign(2,10,7,11);
    Control := New(PStaticText, Init(R, 'West:'));
    Insert(Control);
    R.Assign(8,8,10,9);
    Control := New(PStaticText, Init(R, 'EK'));
    Insert(Control);
    R.Assign(21,8,25,9);
    Control := New(PStaticText, Init(R, 'Akt.'));
    Insert(Control);
    R.Assign(32,8,34,9);
    Control := New(PStaticText, Init(R, 'VK'));
    Insert(Control);
    R.Assign(36,12,47,14);
    Control := New(PButton, Init(R, '~O~K', cmOK, bfDefault));
    Insert(Control);
    R.Assign(48,12,59,14);
    Control := New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal));
    Insert(Control);
    SelectNext(False);
  End;
  Rez.Put(D, 'ArtikelDlg');
  Dispose(D, Done);
End;

Procedure CreateKundenDialog;
Var
  D: PKundenDialog;
  I: Byte;
Begin
  R.Assign(5,2,73,21);
  D:=New(PKundenDialog, Init(R, 'Kundensatz'));
  With D^ Do
  Begin
    HelpCtx:=hcItem;
    R.Assign(3,3,40,4);
    Control := New(PKeyInputLine, Init(R, 35));
    Insert(Control);
    R.Assign(3,2,8,3);
    Labl := New(PLabel, Init(R, '~N~ame', Control));
    Insert(Labl);
    R.Assign(43,3,65,4);
    Control := New(PInputLine, Init(R, 20));
    Insert(Control);
    R.Assign(43,2,51,3);
    Labl := New(PLabel, Init(R, '~V~orname', Control));
    Insert(Labl);
    R.Assign(3,6,65,7);
    Control := New(PInputLine, Init(R, 60));
    Insert(Control);
    R.Assign(3,5,11,6);
    Labl := New(PLabel, Init(R, '~A~dresse', Control));
    Insert(Labl);
    R.Assign(3,7,65,8);
    Control := New(PInputLine, Init(R, 60));
    Insert(Control);
    R.Assign(3,9,35,10);
    Control := New(PInputLine, Init(R, 30));
    Insert(Control);
    R.Assign(3,8,11,9);
    Labl := New(PLabel, Init(R, '~T~elefon', Control));
    Insert(Labl);
    R.Assign(3, 12, 15, 13);
    For I:=1 To 5 Do
    Begin
      Insert(New(PLfrInputLine, Init(R, 10)));
      R.Move(15, 0);
      Insert(New(PIntInputLine, Init(R, 10, 0, 99999999)));
      R.Move(-15, 1);
    End;
    R.Assign(3,11,12,12);
    Control := New(PStaticText, Init(R, 'Lieferant'));
    Insert(Control);
    R.Assign(18,11,27,12);
    Control := New(PStaticText, Init(R, 'Kundennr.'));
    Insert(Control);
    R.Assign(34,15,48,17);
    Control := New(PButton, Init(R, 'OK', cmOK, bfDefault));
    Insert(Control);
    R.Assign(50,15,64,17);
    Control := New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal));
    Insert(Control);
    SelectNext(False);
  End;
  Rez.Put(D, 'KundenDlg');
  Dispose(D, Done);
End;

Procedure CreateLieferDialog;
Var
  D: PLieferantenDialog;
Begin
  R.Assign(10,3,71,18);
  D:=New(PLieferantenDialog, Init(R, 'Lieferant'));
  With D^ Do
  Begin
    HelpCtx:=hcItem;
    R.Assign(3,3,9,4);
    Control := New(PIntInputLine, Init(R, 4, 1, 1000));
    Insert(Control);
    R.Assign(3,2,6,3);
    Labl := New(PLabel, Init(R, '~N~r', Control));
    Insert(Labl);
    R.Assign(11,3,48,4);
    Control := New(PKeyInputLine, Init(R, 35));
    Insert(Control);
    R.Assign(11,2,17,3);
    Labl := New(PLabel, Init(R, '~F~irma', Control));
    Insert(Labl);
    R.Assign(50,3,58,4);
    Control := New(PInputLine, Init(R, 5));
    Insert(Control);
    R.Assign(50,2,57,3);
    Labl := New(PLabel, Init(R, '~K~ürzel', Control));
    Insert(Labl);
    R.Assign(3,6,58,7);
    Control := New(PInputLine, Init(R, 60));
    Insert(Control);
    R.Assign(3,5,11,6);
    Labl := New(PLabel, Init(R, '~A~dresse', Control));
    Insert(Labl);
    R.Assign(3,7,58,8);
    Control := New(PInputLine, Init(R, 60));
    Insert(Control);
    R.Assign(3,10,35,11);
    Control := New(PInputLine, Init(R, 30));
    Insert(Control);
    R.Assign(3,9,11,10);
    Labl := New(PLabel, Init(R, '~T~elefon', Control));
    Insert(Labl);
    R.Assign(3,12,35,13);
    Control := New(PInputLine, Init(R, 30));
    Insert(Control);
    R.Assign(3,11,11,12);
    Labl := New(PLabel, Init(R, 'Telefa~x~', Control));
    Insert(Labl);
    R.Assign(36,11,46,13);
    Control := New(PButton, Init(R, 'OK', cmOK, bfDefault));
    Insert(Control);
    R.Assign(47,11,58,13);
    Control := New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal));
    Insert(Control);
    SelectNext(False);
  End;
  Rez.Put(D, 'LieferantenDlg');
  Dispose(D, Done);
End;

Procedure CreateWGruppeDialog;
Var Dlg: PDialog;
Begin
  R.Assign(17,6,66,14);
  New(Dlg, Init(R, 'Warengruppe'));
  Dlg^.HelpCtx:=hcItem;
  R.Assign(3,3,35,4);
  Control := New(PInputLine, Init(R, 30));
  Dlg^.Insert(Control);
  R.Assign(3,2,10,3);
  Dlg^.Insert(New(PLabel, Init(R, '~G~ruppe', Control)));
  R.Assign(37,3,46,4);
  Control := New(PIntInputLine, Init(R, 5, 1, 999));
  Dlg^.Insert(Control);
  R.Assign(37,2,45,3);
  Dlg^.Insert(New(PLabel, Init(R, '~A~rtikel', Control)));
  R.Assign(17,5,31,7);
  Dlg^.Insert(New(PButton, Init(R, 'OK', cmOK, bfDefault)));
  R.Assign(33,5,47,7);
  Dlg^.Insert(New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal)));
  Dlg^.SelectNext(False);
  Rez.Put(Dlg, 'GruppeDlg');
  Dispose(Dlg, Done);
End;

Procedure CreateGruppenDialog;
Var Dlg: PGruppenDialog;
Begin
  R.Assign(14,3,68,20);
  New(Dlg, Init(R, 'Warengruppen'));
  Dlg^.HelpCtx:=hcListEdit;
  R.Assign(35,2,36,15);
  Control := New(PScrollbar, Init(R));
  Dlg^.Insert(Control);
  R.Assign(3,2,35,15);
  Control := New(PGruppenViewer, Init(R, 1, nil, PScrollbar(Control)));
  Dlg^.Insert(Control);
  R.Assign(37,2,51,4);
  Control := New(PButton, Init(R, 'Ändern', cmEdit, bfDefault));
  Dlg^.Insert(Control);
  R.Assign(37,5,51,7);
  Control := New(PButton, Init(R, 'Einfügen', cmInsert, bfNormal));
  Dlg^.Insert(Control);
  R.Assign(37,8,51,10);
  Control := New(PButton, Init(R, 'Entfernen', cmDelete, bfNormal));
  Dlg^.Insert(Control);
  R.Assign(37,11,51,13);
  Control := New(PButton, Init(R, 'Drucken', cmPrintGruppen, bfNormal));
  Dlg^.Insert(Control);
  R.Assign(37, 14, 51, 16);
  Control := New(PButton, Init(R, 'OK', cmOK, bfNormal));
  Dlg^.Insert(Control);
  Dlg^.SelectNext(False);
  Rez.Put(Dlg, 'GruppenDlg');
  Dispose(Dlg, Done);
End;

Procedure CreateOSDialog;
Var Dlg: PDialog;
Begin
  R.Assign(20,4,60,14);
  New(Dlg, Init(R, 'Ordersatz'));
  Dlg^.HelpCtx:=hcItem;
  R.Assign(3,2,25,3);
  Control := New(PKeyInputLine, Init(R, 20));
  Dlg^.Insert(Control);
  R.Assign(3,1,8,2);
  Dlg^.Insert(New(PLabel, Init(R, '~N~ame', Control)));
  R.Assign(27,2,37,3);
  Control := New(PDateInputLine, Init(R, True));
  Dlg^.Insert(Control);
  R.Assign(27,1,37,2);
  Dlg^.Insert(New(PLabel, Init(R, '~G~ültig ab', Control)));
  R.Assign(7,5,18,7);
  Control := New(PButton, Init(R, 'OK', cmOK, bfDefault));
  Dlg^.Insert(Control);
  R.Assign(20,5,31,7);
  Control := New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal));
  Dlg^.Insert(Control);
  Dlg^.SelectNext(False);
  Rez.Put(Dlg, 'OSDlg');
  Dispose(Dlg, Done);
End;

Procedure CreateOSListDlg;
Var Dlg: PActiveOSEditor;
Begin
  R.Assign(13, 3, 66, 20);
  New(Dlg, Init(R, 'Ordersatzliste'));
  Dlg^.HelpCtx:=hcListEdit;
  R.Assign(34,3,35,15);
  Control := New(PScrollbar, Init(R));
  Dlg^.Insert(Control);
  R.Assign(2,3,34,15);
  Control := New(PActiveOSViewer, Init(R, 1, nil, PScrollbar(Control)));
  Dlg^.Insert(Control);
  R.Assign(2,2,20,3);
  Labl := New(PLabel, Init(R, 'Aktive ~O~rdersätze', Control));
  Dlg^.Insert(Labl);
  R.Assign(36,3,51,5);
  Control := New(PButton, Init(R, 'Ändern', cmEdit, bfDefault));
  Dlg^.Insert(Control);
  R.Assign(36,6,51,8);
  Control := New(PButton, Init(R, 'Einfügen', cmInsert, bfNormal));
  Dlg^.Insert(Control);
  R.Assign(36,9,51,11);
  Control := New(PButton, Init(R, 'Entfernen', cmDelete, bfNormal));
  Dlg^.Insert(Control);
  R.Assign(36,13,51,15);
  Control := New(PButton, Init(R, 'OK', cmCancel, bfNormal));
  Dlg^.Insert(Control);
  Dlg^.SelectNext(False);
  Rez.Put(Dlg, 'ActiveOSEditor');
  Dispose(Dlg, Done);
End;

Procedure CreateOSListDlg2;
Var Dlg : PDialog;
Begin
  R.Assign(13, 3, 66, 20);
  New(Dlg, Init(R, 'Ordersatz wählen...'));
  R.Assign(34,3,35,15);
  Control := New(PScrollbar, Init(R));
  Dlg^.Insert(Control);
  R.Assign(2,3,34,15);
  Control := New(PActiveOSViewer, Init(R, 1, nil, PScrollbar(Control)));
  Dlg^.Insert(Control);
  R.Assign(2,2,20,3);
  Labl := New(PLabel, Init(R, 'Aktive ~O~rdersätze', Control));
  Dlg^.Insert(Labl);
  R.Assign(36,3,51,5);
  Control := New(PButton, Init(R, 'OK', cmOk, bfDefault));
  Dlg^.Insert(Control);
  R.Assign(36,6,51,8);
  Control := New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal));
  Dlg^.Insert(Control);
  Dlg^.SelectNext(False);
  Rez.Put(Dlg, 'ActiveOSSelect');
  Dispose(Dlg, Done);
End;

Procedure CreateCurrentDlg;
Var Dlg : PCurrentOrderDialog;
Begin
  R.Assign(4,2,75,21);
  New(Dlg, Init(R, 'Aktuelle Bestellungen'));
  Dlg^.HelpCtx:=hcCurrListDlg;
  R.Assign(54,3,55,15);
  Control := New(PScrollbar, Init(R));
  Dlg^.Insert(Control);
  R.Assign(2,3,54,15);
  Control := New(PCurrentOrderViewer, Init(R, 1, nil, PScrollbar(Control)));
  Dlg^.Insert(Control);
  R.Assign(5, 2, 55, 3);
  Dlg^.Insert(New(PStaticText, Init(R, 'Bestellung von (Name, Vorname)    Datum, Uhrzeit')));
  R.Assign(3,16,28,18);
  Dlg^.Insert(New(PButton, Init(R, '~B~estellung annehmen', cmBestellung, bfNormal)));
  R.Assign(30, 16, 50, 18);
  Dlg^.Insert(New(PButton, Init(R, '~Z~usammenfassen', cmCurrSumUp, bfNormal)));
  R.Assign(55,2,68,4);
  Dlg^.Insert(New(PButton, Init(R, 'Ä~n~dern', cmCurrEdit, bfNormal)));
  R.Assign(55,5,68,7);
  Dlg^.Insert(New(PButton, Init(R, '~A~nsehen', cmCurrView, bfDefault)));
  R.Assign(55,8,68,10);
  Dlg^.Insert(New(PButton, Init(R, '~D~rucken', cmCurrPrint, bfNormal)));
  R.Assign(55,11,68,13);
  Dlg^.Insert(New(PButton, Init(R, '~L~öschen', cmDelete, bfNormal)));
  Dlg^.SelectNext(False);
  Rez.Put(Dlg, 'CurrentDialog');
  Dispose(Dlg, Done);
End;

Procedure CreateDruckerDlg;
Var Dlg : PDialog;
Begin
  R.Assign(20,3,66,19);
  New(Dlg, Init(R, ''));
  R.Assign(4,3,22,5);
  Control := New(PRadioButtons, Init(R,
    NewSItem('Pica (80)',
    NewSItem('Elite (96)',Nil))));
  PCluster(Control)^.Value := 0;
  Dlg^.Insert(Control);
  R.Assign(4,2,18,3);
  Labl := New(PLabel, Init(R, '~S~chriftbreite', Control));
  Dlg^.Insert(Labl);
  R.Assign(4,6,22,7);
  Control := New(PCheckboxes, Init(R,
    NewSItem('Schnelldruck',Nil)));
  PCluster(Control)^.Value := 0;
  Dlg^.Insert(Control);
  R.Assign(24,3,42,6);
  Control := New(PRadioButtons, Init(R,
    NewSItem('1,0',
    NewSItem('1,5',
    NewSItem('2,0',Nil)))));
  PCluster(Control)^.Value := 0;
  Dlg^.Insert(Control);
  R.Assign(24,2,38,3);
  Labl := New(PLabel, Init(R, '~Z~eilenabstand', Control));
  Dlg^.Insert(Labl);
  R.Assign(4,9,22,10);
  Control := New(PIntInputLine, Init(R, 3, 1, 5));
  Dlg^.Insert(Control);
  R.Assign(4,8,16,9);
  Labl := New(PLabel, Init(R, '~O~berer Rand', Control));
  Dlg^.Insert(Labl);
  R.Assign(4,11,22,12);
  Control := New(PIntInputLine, Init(R, 3, 10, 100));
  Dlg^.Insert(Control);
  R.Assign(4,10,17,11);
  Labl := New(PLabel, Init(R, 'Zei~l~en/Seite', Control));
  Dlg^.Insert(Labl);
  R.Assign(24,9,42,10);
  Control := New(PIntInputLine, Init(R, 3, 0, 10));
  Dlg^.Insert(Control);
  R.Assign(24,8,36,9);
  Labl := New(PLabel, Init(R, '~L~inker Rand', Control));
  Dlg^.Insert(Labl);
  R.Assign(5,13,20,15);
  Control := New(PButton, Init(R, 'OK', cmOK, bfDefault));
  Dlg^.Insert(Control);
  R.Assign(25,13,40,15);
  Control := New(PButton, Init(R, 'Abbruch', cmCancel, bfNormal));
  Dlg^.Insert(Control);
  Dlg^.SelectNext(False);
  Rez.Put(Dlg, 'DruckerDlg');
  Dispose(Dlg, Done);
End;

Begin
  RegisterObjects;
  RegisterViews;
  RegisterMenus;
  RegisterDialogs;
  RegisterFields;
  Strm:=New(PBufStream, Init('KIOSK.REZ', stCreate, 1024));
  Rez.Init(Strm);
  CreateMenuBar;
  Write(#251);
  CreateStatusLine;
  Write(#251);
  CreateArtikelDialog;
  Write(#251);
  CreateKundenDialog;
  Write(#251);
  CreateLieferDialog;
  Write(#251);
  CreateWGruppeDialog;
  Write(#251);
  CreateGruppenDialog;
  Write(#251);
  CreateOSDialog;
  Write(#251);
  CreateOSListDlg;
  Write(#251);
  CreateOSListDlg2;
  Write(#251);
  CreateCurrentDlg;
  Write(#251);
  CreateDruckerDlg;
  Write(#251);
  Write('*');
  Rez.Done;
End.