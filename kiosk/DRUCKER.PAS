{$I KIOSKCO.PAS}
Unit Drucker;
Interface
  Uses
    Objects, Views, Dialogs, MsgBox, App,
    Printer,
    KioskRez;

  Const
    ThickOn= #27'G'#27'E';
    ThickOff= #27'H'#27'F';
    WideOn= #27'W'#1;
    WideOff= #27'W'#0;

  Type
    TDruckOptionen= Record
      Pitch, Draft, LineFeed: Word;
      Upper, LPP, Left: Longint;
    End;

  Var
    DruckOptionen: Array[0..1] Of TDruckOptionen;
    LPP, CPL: Word;
    Deskjet: Boolean;

  Procedure LoadDruckOpt;
  Procedure SaveDruckOpt;
  Procedure EditDruckOpt(N: Integer);
  Function InitPrinter(N: Integer): Boolean;
  Procedure SetSingleLineFeed;
  Procedure ResetLineFeed(N: Integer);

Implementation

  Procedure LoadDruckOpt;
  Var S: TBufStream;
  Begin
    S.Init('PRINTER.DAT', stOpen, 1024);
    If S.Status=stOK Then
    Begin
      S.Read(DruckOptionen, SizeOf(DruckOptionen));
      S.Done;
    End Else
    Begin
      MessageBox('Druckeroptionen können nicht gefunden werden.'#13'Setze Standardwerte.',
        nil, mfInformation+mfOkButton);
      FillChar(DruckOptionen, SizeOf(DruckOptionen), 0);
      SaveDruckOpt;
    End;
  End;

  Procedure SaveDruckOpt;
  Var S: TBufStream;
  Begin
    S.Init('PRINTER.DAT', stCreate, 1024);
    If S.Status=stOK Then
    Begin
      S.Write(DruckOptionen, SizeOf(DruckOptionen));
      S.Done;
    End Else
      MessageBox('Druckeroptionen können nicht gesichert werden.', nil,
        mfError+mfOkButton);
  End;

  Procedure EditDruckOpt(N: Integer);
  Var Dlg: PDialog;
  Begin
    Dlg:=PDialog(GetRez('DruckerDlg'));
    If Dlg<>nil Then
    Begin
      If N=0 Then
        Dlg^.Title:=NewStr('Druckeroptionen: Ordersatz')
      Else
        Dlg^.Title:=NewStr('Druckeroptionen: Bestellungen');
      Dlg^.SetData(DruckOptionen[N]);
      If Desktop^.ExecView(Dlg)=cmOk Then
      Begin
        Dlg^.GetData(DruckOptionen[N]);
        SaveDruckOpt;
      End;
      Dispose(Dlg, Done);
    End;
  End;

  Function InitPrinter(N: Integer): Boolean;
  Var I: Integer;
  Begin
    If DruckOptionen[N].LPP<>0 Then
    Begin
      If MessageBox('Bitte Drucker bereit machen...'#13'ESC bricht den Druckvorgang ab!',
        nil, mfInformation+mfOkButton+mfCancelButton)=cmOk Then
      With DruckOptionen[N] Do
      Begin
        If Not DeskJet Then
        Begin
          Write(Lst, #27'@');
          For I:=1 To Upper Do Writeln(Lst);
          Write(Lst, #27'c'+Chr(Upper));
          Write(Lst, #27'l'+Chr(Left));
          If Pitch=0 Then
          Begin
            If ParamStr(1)='epson' Then
              Write(Lst, #27'P')
            Else
              Write(Lst, #27'x'#1);
            CPL:=80-Left;
          End Else
          Begin
            If ParamStr(1)='epson' Then
              Write(Lst, #27'M')
            Else
              Write(Lst, #27'x'#0);
            CPL:=96-Left;
          End;
          If Draft=1 Then Write(Lst, #27'x'#0) Else Write(Lst, #27'x'#1);
          ResetLineFeed(N);
        End;
        InitPrinter:=True;
      End Else InitPrinter:=False;
      LPP:=DruckOptionen[N].LPP;
    End Else
    Begin
      InitPrinter:=False;
      MessageBox('Druckoptionen sind nicht korrekt eingestellt.', nil, mfWarning+mfOkButton);
    End;
  End;

  Procedure SetSingleLineFeed;
  Begin
    If Not DeskJet Then Write(Lst, #27'A'#12);
  End;

  Procedure ResetLineFeed(N: Integer);
  Begin
    If Not DeskJet Then
    Case DruckOptionen[N].LineFeed Of
      0: Write(Lst, #27'A'#12);
      1: Write(Lst, #27'A'#18);
      2: Write(Lst, #27'A'#24);
    End;
  End;

End.