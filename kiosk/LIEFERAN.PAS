{$I KIOSKCO.PAS}
Unit Lieferanten;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, Fields, MsgBox, App,
    StrObj, StrUtl, DataFile,
    KioskCmds, KioskRez, Stamm;

  Type
    PLieferantenRec= ^TLieferantenRec;
    TLieferantenRec= Record
      Status: LongInt;
      LieferNr: LongInt;
      Name: String[35];
      Short: String[5];
      Strasse, Ort: String[60];
      Telefon, Telefax: String[30];
    End;

    PLieferant= ^TLieferant;
    TLieferant= Object(TStammItem)
      LieferNr: LongInt;
      Short: TStr;
      Constructor Init;
      Procedure GetRec(Var Rec); virtual;
      Procedure GetListText(Var S: String; MaxLen: Integer); virtual;
      Function Edit: Word; virtual;
      Procedure Delete; virtual;
      Constructor Load(Var S: TStream);
      Destructor Done; virtual;
    End;

    PLieferantenstamm= ^TLieferantenstamm;
    TLieferantenstamm= Object(TStamm)
      Procedure InitStamm; virtual;
      Function GetNewItem: PStammItem; virtual;
      Function GetShortName(Nr: LongInt): String;
      Function GetLieferNr(Short: String): LongInt;
      Function LieferNrValid(Nr: LongInt): Boolean;
    End;

    PLfrInputLine= ^TLfrInputLine;
    TLfrInputLine= Object(TInputLine)
      Function DataSize: Word; virtual;
      Procedure GetData(Var Rec); virtual;
      Procedure SetData(Var Rec); virtual;
      Function Valid(Command: Word): Boolean; virtual;
    End;

    PLieferantenDialog= ^TLieferantenDialog;
    TLieferantenDialog= Object(TItemDialog)
      Function DupKeyMessage: Word; virtual;
      Function GetKeyOfData: String; virtual;
    End;

  Const
    RLieferant: TStreamRec= (
      ObjType: 2004;
      VmtLink: Ofs(TypeOf(TLieferant)^);
      Load: @TLieferant.Load;
      Store: @TLieferant.Store
    );
    RLieferantenstamm: TStreamRec= (
      ObjType: 2005;
      VmtLink: Ofs(TypeOf(TLieferantenstamm)^);
      Load: @TLieferantenstamm.Load;
      Store: @TLieferantenstamm.Store
    );
    RLieferantenDialog: TStreamRec= (
      ObjType: 3002;
      VmtLink: Ofs(TypeOf(TLieferantenDialog)^);
      Load: @TLieferantenDialog.Load;
      Store: @TLieferantenDialog.Store
    );
    RLfrInputLine: TStreamRec= (
      ObjType: 3003;
      VmtLink: Ofs(TypeOf(TLfrInputLine)^);
      Load: @TLfrInputLine.Load;
      Store: @TLfrInputLine.Store
    );

  Var
    Lieferantenstamm: PLieferantenstamm;

  Procedure OpenLieferanten;
  Procedure CloseLieferanten;
  Procedure GetLieferRec(D: LongInt; Var Rec);

Implementation
  Var
    LieferF: TDataFile;

  Procedure GetLieferRec(D: LongInt; Var Rec);
  Begin
    GetRec(LieferF, D, Rec);
  End;

{== TLieferantenDialog ====================================================}

  Function TLieferantenDialog.GetKeyOfData: String;
  Var DataRec: TLieferantenRec;
  Begin
    GetData(DataRec.LieferNr);
    StrUprG(DataRec.Name);
    GetKeyOfData:=DataRec.Name;
  End;

  Function TLieferantenDialog.DupKeyMessage: Word;
  Begin
    DupKeyMessage:=MessageBox('Lieferant gleichen Namens bereits vorhanden. Bitte nochmals editieren!',
      nil, mfInformation+mfOKCancel);
  End;

{== TLieferant ============================================================}

  Constructor TLieferant.Init;
  Begin
    TStammItem.Init;
    Short.Init('');
  End;

  Procedure TLieferant.GetRec(Var Rec);
  Begin
    If DataRef<>-1 Then
      DataFile.GetRec(LieferF, DataRef, Rec)
    Else
      FillChar(Rec, SizeOf(TLieferantenRec), 0);
  End;

  Procedure TLieferant.GetListText(Var S: String; MaxLen: Integer);
  Var
    Rec: TLieferantenRec;
    Params: Array[0..2] Of PString;
  Begin
    GetRec(Rec);
    Params[0]:=@Rec.Name;
    Params[1]:=@Rec.Telefon;
    Params[2]:=@Rec.Telefax;
    FormatStr(S, '%-30s │ %-20s │ %-20s', Params);
    If Length(S)>MaxLen Then S[0]:=Chr(MaxLen);
  End;

  Function TLieferant.Edit: Word;
  Var
    DataRec: TLieferantenRec;
    Dlg: PLieferantenDialog;
    Cmd: Word;
  Begin
    Dlg:=PLieferantenDialog(GetRez('LieferantenDlg'));
    Dlg^.Stamm:=LieferantenStamm;
    GetRec(DataRec);
    Dlg^.SetData(DataRec.LieferNr);
    Cmd:=DeskTop^.ExecView(Dlg);
    If Cmd<>cmCancel Then
    Begin
      Dlg^.GetData(DataRec.LieferNr);
      If DataRef=-1 Then
        AddRec(LieferF, DataRef, DataRec)
      Else
        PutRec(LieferF, DataRef, DataRec);
      StrUprG(DataRec.Name);
      Key.SetStr(DataRec.Name);
      Short.SetStr(DataRec.Short);
      LieferNr:=DataRec.LieferNr;
    End;
    Dispose(Dlg, Done);
    Edit:=Cmd;
  End;

  Procedure TLieferant.Delete;
  Begin
    If DataRef<>-1 Then DeleteRec(LieferF, DataRef);
  End;

  Constructor TLieferant.Load;
  Var DataRec: TLieferantenRec;
  Begin
    TStammItem.Load(S);
    GetRec(DataRec);
    LieferNr:=DataRec.LieferNr;
    Short.Init(DataRec.Short);
  End;

  Destructor TLieferant.Done;
  Begin
    Short.Done;
    TStammItem.Done;
  End;

{== TLieferantenStamm =====================================================}

  Procedure TLieferantenStamm.InitStamm;
  Begin
    Title:=NewStr('Lieferantenstamm');
    Lbl:=NewStr('Firma                            Telefon                Telefax');
    CmdBase:=cmLieferBase;
  End;

  Function TLieferantenStamm.GetNewItem: PStammItem;
  Begin
    GetNewItem:=New(PLieferant, Init);
  End;

  Function TLieferantenStamm.GetShortName(Nr: LongInt): String;
  Var
    I: Integer;
    S: String[5];
  Begin
    For I:=0 To Count-1 Do
      If PLieferant(At(I))^.LieferNr=Nr Then
      Begin
        GetShortName:=PLieferant(At(I))^.Short.GetStr;
        Exit;
      End;
    Str(Nr, S);
    GetShortName:=S;
  End;

  Function TLieferantenStamm.GetLieferNr(Short: String): LongInt;
  Var I: Integer;
  Begin
    GetLieferNr:=-1;
    For I:=0 To Count-1 Do
      If PLieferant(At(I))^.Short.GetStr=Short Then
      Begin
        GetLieferNr:=PLieferant(At(I))^.LieferNr;
        Exit;
      End;
  End;

  Function TLieferantenStamm.LieferNrValid(Nr: LongInt): Boolean;
  Var I: Integer;
  Begin
    LieferNrValid:=False;
    For I:=0 To Count-1 Do
      If PLieferant(At(I))^.LieferNr=Nr Then
      Begin
        LieferNrValid:=True;
        Exit;
      End;
  End;

{== TLfrInputLine =========================================================}

  Function TLfrInputLine.DataSize: Word;
  Begin
    DataSize:=SizeOf(LongInt);
  End;

  Procedure TLfrInputLine.GetData(Var Rec);
  Var Code: Integer;
  Begin
    If Data^<>'' Then
    Begin
      Val(Data^, LongInt(Rec), Code);
      If Code<>0 Then
        LongInt(Rec):=Lieferantenstamm^.GetLieferNr(Data^);
    End Else
      LongInt(Rec):=0;
  End;

  Procedure TLfrInputLine.SetData(Var Rec);
  Begin
    Data^:=Lieferantenstamm^.GetShortName(LongInt(Rec));
    If Data^='0' Then Data^:='';
  End;

  Function TLfrInputLine.Valid(Command: Word): Boolean;
  Var
    Code: Integer;
    Value: LongInt;
    Ok: Boolean;
  Begin
    Ok:=True;
    If (Command<>cmCancel) And (Command<>cmValid) And (Data^<>'') Then
    Begin
      Val(Data^, Value, Code);
      If ((Code<>0) And (Lieferantenstamm^.GetLieferNr(Data^)=-1)) Or
         ((Code=0) And (Not Lieferantenstamm^.LieferNrValid(Value))) Then
      Begin
        Select;
        MessageBox('Lieferantenangabe entspricht weder einer gültigen Lieferantennummer noch '+
          'einem Lieferantenkürzel.', nil, mfInformation+mfOkButton);
        SelectAll(True);
        Ok:=False;
      End;
    End;
    If Ok Then
      Valid := TInputLine.Valid(Command)
    Else
      Valid := False;
  End;

{== Prozeduren/Funktionen =================================================}

  Procedure OpenLieferanten;
  Var
    Strm: TBufStream;
    L: TLieferantenRec;
    NL: PLieferant;
    I: LongInt;
  Begin
    OpenFile(LieferF, 'LIEFER.DAT', SizeOf(TLieferantenRec));
    If Not OK Then
    Begin
      MessageBox('Lieferantenstamm existiert nicht. Dateien werden neu angelegt!',
        nil, mfInformation+mfOKButton);
      CreateFile(LieferF, 'LIEFER.DAT', SizeOf(TLieferantenRec));
      New(Lieferantenstamm, Init);
    End Else
    Begin
      Strm.Init('LIEFER.IDX', stOpen, 1024);
      Lieferantenstamm:=PLieferantenstamm(Strm.Get);
      If (Lieferantenstamm=nil) Or (Strm.Status<>stOK) Then
      Begin
        MessageBox('Lieferantenindex muß neu angelegt werden !', nil, mfError+mfOKButton);
        New(Lieferantenstamm, Init);
        For I:=1 To FileLen(LieferF) Do
        Begin
          GetRec(LieferF, I, L);
          If L.Status=0 Then
          Begin
            NL:=New(PLieferant, Init);
            NL^.Key.SetStr(L.Name);
            NL^.DataRef:=I;
            Lieferantenstamm^.Insert(NL);
          End;
        End;
      End;
      Strm.Done;
    End;
  End;

  Procedure CloseLieferanten;
  Var Strm: TBufStream;
  Begin
    CloseFile(LieferF);
    If Lieferantenstamm^.Changed Then
    Begin
      Strm.Init('LIEFER.IDX', stCreate, 1024);
      Strm.Put(Lieferantenstamm);
      If Strm.Status<>0 Then
        MessageBox('Lieferantenindex konnte nicht gesichert werden !', nil, mfError+mfOKButton);
      Strm.Done;
    End;
    Dispose(Lieferantenstamm, Done);
  End;

Begin
  RegisterType(RLieferant);
  RegisterType(RLieferantenStamm);
  RegisterType(RLieferantenDialog);
  RegisterType(RLfrInputLine);
End.