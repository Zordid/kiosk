{$I KIOSKCO.PAS}
Unit Kunden;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, Fields, MsgBox, App,
    StrObj, StrUtl, DataFile,
    KioskCmds, KioskRez, Stamm, Lieferanten;

  Type
    TKundenNr= Record
      Lfr, Nr: LongInt;
    End;

    PKundenRec= ^TKundenRec;
    TKundenRec= Record
      Status: LongInt;
      Name: String[35];
      Vorname: String[20];
      Strasse, Ort: String[60];
      Telefon: String[30];
      Nr: Array[1..5] Of TKundenNr;
    End;

    PKunde= ^TKunde;
    TKunde= Object(TStammItem)
      Procedure GetRec(Var Rec); virtual;
      Procedure GetListText(Var S: String; MaxLen: Integer); virtual;
      Function Edit: Word; virtual;
      Procedure Delete; virtual;
    End;

    PKundenstamm= ^TKundenstamm;
    TKundenstamm= Object(TStamm)
      Procedure InitStamm; virtual;
      Function GetNewItem: PStammItem; virtual;
    End;

    PKundenDialog= ^TKundenDialog;
    TKundenDialog= Object(TItemDialog)
      Function DupKeyMessage: Word; virtual;
      Function GetKeyOfData: String; virtual;
    End;

  Const
    RKunde: TStreamRec= (
      ObjType: 2000;
      VmtLink: Ofs(TypeOf(TKunde)^);
      Load: @TKunde.Load;
      Store: @TKunde.Store
    );
    RKundenstamm: TStreamRec= (
      ObjType: 2001;
      VmtLink: Ofs(TypeOf(TKundenstamm)^);
      Load: @TKundenstamm.Load;
      Store: @TKundenstamm.Store
    );
    RKundenDialog: TStreamRec= (
      ObjType: 3001;
      VmtLink: Ofs(TypeOf(TKundenDialog)^);
      Load: @TKundenDialog.Load;
      Store: @TKundenDialog.Store
    );

  Var
    Kundenstamm: PKundenstamm;

  Procedure OpenKunden;
  Procedure CloseKunden;
  Procedure GetKundenRec(D: LongInt; Var Rec);

Implementation
  Var
    KundenF: TDataFile;

{== Prozeduren/Funktionen =================================================}

  Procedure GetKundenRec(D: LongInt; Var Rec);
  Begin
    GetRec(KundenF, D, Rec);
  End;

  Function CreateKey(K: TKundenRec): String;
  Var Key: String[55];
  Begin
    FillChar(Key[1], SizeOf(Key)-1, 0);
    StrMove(Key, K.Name);
    Key[0]:=#35;
    StrCat(Key, K.Vorname, 55);
    StrUprG(Key);
    CreateKey:=Key;
  End;

{== TKundenDialog =========================================================}

  Function TKundenDialog.GetKeyOfData: String;
  Var DataRec: TKundenRec;
  Begin
    GetData(DataRec.Name);
    GetKeyOfData:=CreateKey(DataRec);
  End;

  Function TKundenDialog.DupKeyMessage: Word;
  Begin
    DupKeyMessage:=MessageBox('Kunde gleichen Namens bereits vorhanden. Bitte nochmals editieren!',
      nil, mfInformation+mfOKCancel);
  End;

{== TKunde ================================================================}

  Procedure TKunde.GetRec(Var Rec);
  Begin
    If DataRef<>-1 Then
      DataFile.GetRec(KundenF, DataRef, Rec)
    Else
      FillChar(Rec, SizeOf(TKundenRec), 0);
  End;

  Procedure TKunde.GetListText(Var S: String; MaxLen: Integer);
  Var
    Rec: TKundenRec;
    Name: String[30];
    Params: Array[0..2] Of PString;
  Begin
    GetRec(Rec);
    Params[0]:=@Name;
    Params[1]:=@Rec.Ort;
    Params[2]:=@Rec.Telefon;
    StrMove(Name, Rec.Name);
    If (Rec.Vorname<>'') And (Length(Name)<25) Then
    Begin
      StrCat(Name, ', ', 30);
      StrCat(Name, Rec.Vorname, 30);
    End;
    FormatStr(S, '%-30s │ %-20s │ %-20s', Params);
    If Length(S)>MaxLen Then S[0]:=Chr(MaxLen);
  End;

  Function TKunde.Edit: Word;
  Var
    DataRec: TKundenRec;
    Dlg: PKundenDialog;
    Cmd: Word;
  Begin
    Dlg:=PKundenDialog(GetRez('KundenDlg'));
    Dlg^.Stamm:=Kundenstamm;
    GetRec(DataRec);
    Dlg^.SetData(DataRec.Name);
    Cmd:=DeskTop^.ExecView(Dlg);
    If Cmd<>cmCancel Then
    Begin
      Dlg^.GetData(DataRec.Name);
      Key.SetStr(CreateKey(DataRec));
      If DataRef=-1 Then
        AddRec(KundenF, DataRef, DataRec)
      Else
        PutRec(KundenF, DataRef, DataRec);
    End;
    Dispose(Dlg, Done);
    Edit:=Cmd;
  End;

  Procedure TKunde.Delete;
  Begin
    If DataRef<>-1 Then DeleteRec(KundenF, DataRef);
  End;

{== TKundenStamm ==========================================================}

  Procedure TKundenStamm.InitStamm;
  Begin
    Title:=NewStr('Kundenstamm');
    Lbl:=NewStr('Name                             Ort                    Telefon');
    CmdBase:=cmKundenBase;
  End;

  Function TKundenstamm.GetNewItem: PStammItem;
  Begin
    GetNewItem:=New(PKunde, Init);
  End;

{== Prozeduren/Funktionen =================================================}

  Procedure OpenKunden;
  Var
    Strm: TBufStream;
    K: TKundenRec;
    NK: PKunde;
    I: LongInt;
  Begin
    OpenFile(KundenF, 'KUNDEN.DAT', SizeOf(TKundenRec));
    If Not OK Then
    Begin
      MessageBox('Kundenstamm existiert nicht. Dateien werden neu angelegt!',
        nil, mfInformation+mfOKButton);
      CreateFile(KundenF, 'KUNDEN.DAT', SizeOf(TKundenRec));
      New(Kundenstamm, Init);
    End Else
    Begin
      Strm.Init('KUNDEN.IDX', stOpen, 1024);
      Kundenstamm:=PKundenstamm(Strm.Get);
      If (Kundenstamm=nil) Or (Strm.Status<>stOK) Then
      Begin
        MessageBox('Kundenindex muß neu angelegt werden !', nil, mfError+mfOKButton);
        New(Kundenstamm, Init);
        For I:=1 To FileLen(KundenF) Do
        Begin
          GetRec(KundenF, I, K);
          If K.Status=0 Then
          Begin
            NK:=New(PKunde, Init);
            NK^.Key.SetStr(CreateKey(K));
            NK^.DataRef:=I;
            Kundenstamm^.Insert(NK);
          End;
        End;
      End;
      Strm.Done;
    End;
  End;

  Procedure CloseKunden;
  Var Strm: TBufStream;
  Begin
    CloseFile(KundenF);
    If Kundenstamm^.Changed Then
    Begin
      Strm.Init('KUNDEN.IDX', stCreate, 1024);
      Strm.Put(Kundenstamm);
      If Strm.Status<>0 Then
        MessageBox('Kundenindex konnte nicht gesichert werden !', nil, mfError+mfOKButton);
      Strm.Done;
    End;
    Dispose(Kundenstamm, Done);
  End;

Begin
  RegisterType(RKunde);
  RegisterType(RKundenStamm);
  RegisterType(RKundenDialog);
End.