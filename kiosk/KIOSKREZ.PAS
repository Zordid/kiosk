{$I KIOSKCO.PAS}
Unit KioskRez;
Interface
  Uses Objects, Memory, Views, Dialogs, Fields, Menus, MsgBox;
  Var
    Rez: PResourceFile;

  Procedure InitRez;
  Procedure DoneRez;
  Function GetRez(Key: String): PObject;

Implementation
  Uses Artikel, Kunden, Lieferanten;

  Function GetRez(Key: String): PObject;
  Var P: PObject;
  Begin
    If Not LowMemory Then
    Begin
      P:=Rez^.Get(Key);
      If P=nil Then
        MessageBox('Resource '+Key+' nicht gefunden.', nil, mfError+mfOKButton);
    End Else
    Begin
      MessageBox('Nicht genügend Speicher verfügbar.', nil, mfError+mfOkButton);
      P:=nil;
    End;
    GetRez:=P;
  End;

  Procedure InitRez;
  Var Strm: PBufStream;
  Begin
    RegisterObjects;
    RegisterViews;
    RegisterFields;
    RegisterDialogs;
    RegisterMenus;
    Strm:=New(PBufStream, Init('KIOSK.REZ', stOpenRead, 1024));
    If Strm^.Status<>stOK Then
    Begin
      Writeln('Stream nicht gefunden. Programm beendet.');
      Halt;
    End;
    Rez:=New(PResourceFile, Init(Strm));
  End;

  Procedure DoneRez;
  Begin
    Dispose(Rez, Done);
  End;

End.