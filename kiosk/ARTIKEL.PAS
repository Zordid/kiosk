{$I KIOSKCO.PAS}
Unit Artikel;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, Fields, MsgBox, App,
    Crt, StrObj, StrUtl, DataFile, DosTools,
    KioskCmds, KioskRez, Stamm;

  Type
    TPreise= Record
      EK: Real;
      Datum: String[8];
      VKVon, VKBis: Real;
    End;

    TArtikelRec= Record
      Status: LongInt;       
      Name: String[30];
      Menge: String[10];
      Lieferant: LongInt;
      ArtikelNr: String[10];
      Preise: Array[0..1] Of TPreise;
    End;

    PArtikel= ^TArtikel;
    TArtikel= Object(TStammItem)
      Temp: Boolean;
      Procedure GetRec(Var Rec); virtual;
      Procedure GetListText(Var S: String; MaxLen: Integer); virtual;
      Function Edit: Word; virtual;
      Procedure Delete; virtual;
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
    End;

    PArtikelstamm= ^TArtikelstamm;
    TArtikelstamm= Object(TStamm)
      Procedure InitStamm; virtual;
      Function GetNewItem: PStammItem; virtual;
    End;

    PArtikelDialog= ^TArtikelDialog;
    TArtikelDialog= Object(TItemDialog)
      Function DupKeyMessage: Word; virtual;
      Function GetKeyOfData: String; virtual;
    End;

  Const
    RArtikel: TStreamRec= (
      ObjType: 2002;
      VmtLink: Ofs(TypeOf(TArtikel)^);
      Load: @TArtikel.Load;
      Store: @TArtikel.Store
    );
    RArtikelstamm: TStreamRec= (
      ObjType: 2003;
      VmtLink: Ofs(TypeOf(TArtikelstamm)^);
      Load: @TArtikelstamm.Load;
      Store: @TArtikelstamm.Store
    );
    RArtikelDialog: TStreamRec= (
      ObjType: 3000;
      VmtLink: Ofs(TypeOf(TArtikelDialog)^);
      Load: @TArtikelDialog.Load;
      Store: @TArtikelDialog.Store
    );

  Var
    Artikelstamm: PArtikelstamm;

  Procedure OpenArtikel;
  Procedure CloseArtikel;
  Procedure GetArtikelRec(D: LongInt; Var Rec);

Implementation
  Uses Lieferanten;
  Var
    ArtikelF: TDataFile;

{== Prozeduren/Funktionen =================================================}

  Procedure GetArtikelRec;
  Begin
    GetRec(ArtikelF, D, Rec);
  End;

  Function CreateKey(Art: TArtikelRec): String;
  Var Key: String[40];
  Begin
    FillChar(Key[1], SizeOf(Key)-1, 0);
    StrMove(Key, Art.Name);
    Key[0]:=#30;
    Key:=Key+Art.Menge;
    StrUprG(Key);
    CreateKey:=Key;
  End;

{== TArtikelDialog ========================================================}

  Function TArtikelDialog.GetKeyOfData: String;
  Var DataRec: TArtikelRec;
  Begin
    GetData(DataRec.Name);
    GetKeyOfData:=CreateKey(DataRec);
  End;

  Function TArtikelDialog.DupKeyMessage: Word;
  Begin
    DupKeyMessage:=MessageBox('Artikel doppelt vorhanden. Bitte nochmals editieren!',
      nil, mfInformation+mfOKCancel);
  End;

{== TArtikel ==============================================================}

  Procedure TArtikel.GetRec(Var Rec);
  Begin
    If DataRef<>-1 Then
      DataFile.GetRec(ArtikelF, DataRef, Rec)
    Else
      FillChar(Rec, SizeOf(TArtikelRec), 0);
  End;

  Procedure TArtikel.GetListText(Var S: String; MaxLen: Integer);
  Const
    LongMask: String[30]= '%-30s │ %-10s │ %-10s │ %-5s %c';
    ShortMask: String[30]= '%-22s %-10s │ %-10s';
  Var
    Rec: TArtikelRec;
    Params: Array[0..4] Of PString;
  Begin
    GetRec(Rec);
    Params[0]:=@Rec.Name;
    Params[1]:=@Rec.Menge;
    Params[2]:=@Rec.ArtikelNr;
    Params[3]:=NewStr(Lieferantenstamm^.GetShortName(Rec.Lieferant));
    Byte(Params[4]):=Ord(Temp)*Ord('T');
    If MaxLen<58 Then
      FormatStr(S, ShortMask, Params)
    Else
      FormatStr(S, LongMask, Params);
    DisposeStr(Params[3]);
    If Length(S)>MaxLen Then S[0]:=Chr(MaxLen);
  End;

  Function TArtikel.Edit: Word;
  Var
    DataRec: TArtikelRec;
    Dlg: PArtikelDialog;
    Cmd: Word;
  Begin
    Dlg:=PArtikelDialog(GetRez('ArtikelDlg'));
    If Dlg<>nil Then
    Begin
      Dlg^.Stamm:=ArtikelStamm;
      GetRec(DataRec);
      Dlg^.SetData(DataRec.Name);
      Cmd:=DeskTop^.ExecView(Dlg);
      If Cmd<>cmCancel Then
      Begin
        Dlg^.GetData(DataRec.Name);
        StrUprG(DataRec.Menge);
        Key.SetStr(CreateKey(DataRec));
        If DataRef=-1 Then
          AddRec(ArtikelF, DataRef, DataRec)
        Else
          PutRec(ArtikelF, DataRef, DataRec);
      End;
      Dispose(Dlg, Done);
      Edit:=Cmd;
    End Else Edit:=cmCancel;
  End;

  Procedure TArtikel.Delete;
  Var R: TArtikelRec;
  Begin
    If DataRef<>-1 Then
    Begin
      DataFile.GetRec(ArtikelF, DataRef, R);
      R.Status:=100;
      PutRec(ArtikelF, DataRef, R);
    End;
  End;

  Constructor TArtikel.Load(Var S: TStream);
  Var
    P: Byte;
    K: String[40];
  Begin
    S.Read(K[0], 1);
    S.Read(K[1], Length(K));
    P:=ChrPosL(K, #1, 1);
    If P<>0 Then
    Begin
      Move(K[P+1], K[31], Length(K)-P);
      FillChar(K[P], 31-P, 0);
      K[0]:=Chr(30+Length(K)-P);
    End;
    Key.Init(K);
    S.Read(DataRef, SizeOf(DataRef));
    S.Read(Temp, SizeOf(Temp));
  End;

  Procedure TArtikel.Store(Var S: TStream);
  Var
    CKey: String[40];
    P: Byte;
  Begin
    CKey:=Key.GetStr;
    P:=ChrPosL(CKey, #0, 1);
    If P<>0 Then
    Begin
      CKey[P]:=#1;
      ChrDel(CKey, #0);
    End;
    S.WriteStr(@CKey);
    S.Write(DataRef, SizeOf(DataRef));
    S.Write(Temp, SizeOf(Temp));
  End;

{== TArtikelStamm =========================================================}

  Procedure TArtikelStamm.InitStamm;
  Begin
    Title:=NewStr('Artikelstamm');
    Lbl:=NewStr('Bezeichnung                      GE INH       Artikelnr    Lfr');
    CmdBase:=cmArtikelBase;
  End;

  Function TArtikelstamm.GetNewItem: PStammItem;
  Begin
    GetNewItem:=New(PArtikel, Init);
  End;

{== Prozeduren/Funktionen =================================================}

  Procedure OpenArtikel;
  Var
    Strm: TBufStream;
    A: TArtikelRec;
    I, J: LongInt;
    NA: PArtikel;
    F: TDataFile;
  Begin
    OpenFile(ArtikelF, 'ARTIKEL.DAT', SizeOf(TArtikelRec));
    If Not OK Then
    Begin
      MessageBox('Artikelstamm existiert nicht. Dateien werden neu angelegt!',
        nil, mfInformation+mfOkButton);
      CreateFile(ArtikelF, 'ARTIKEL.DAT', SizeOf(TArtikelRec));
      New(Artikelstamm, Init);
    End Else
    Begin
      If ParamStr(1)='/A' Then
      Begin
        CreateFile(F, 'NEWART.DAT', SizeOf(TArtikelRec));
        For I:=1 To FileLen(ArtikelF) Do
        Begin
          GetRec(ArtikelF, I, A);
          If (A.Status<>0) Or (A.Name='') Then
          Begin
            FillChar(A, SizeOf(A), 0);
            A.Status:=100;
          End;
          AddRec(F, J, A);
          If I<>J Then
          Begin
            I:=FileLen(ArtikelF);
            Ok:=False;
          End;
        End;
        If OK Then
        Begin
          CloseFile(ArtikelF);
          CloseFile(F);
          FileDelete('ARTIKEL.DAT');
          FileRename('NEWART.DAT', 'ARTIKEL.DAT');
          OpenFile(ArtikelF, 'ARTIKEL.DAT', SizeOf(TArtikelRec));
        End Else
        Begin
          ClrScr;
          Writeln('Fehler beim Komprimieren des Artikelstammes.');
          Halt(1);
        End;
        Artikelstamm^.Changed:=True;
      End;
      Strm.Init('ARTIKEL.IDX', stOpen, 1024);
      Artikelstamm:=PArtikelstamm(Strm.Get);
      If (Artikelstamm=nil) Or (Strm.Status<>stOK) Then
      Begin
        If ArtikelStamm<>nil Then Dispose(ArtikelStamm, Done);
        MessageBox('Artikelindex muß neu angelegt werden !', nil, mfError+mfOKButton);
        New(Artikelstamm, Init);
        For I:=1 To FileLen(ArtikelF) Do
        Begin
          GetRec(ArtikelF, I, A);
          If A.Status=0 Then
          Begin
            NA:=New(PArtikel, Init);
            NA^.Key.SetStr(CreateKey(A));
            NA^.DataRef:=I;
            NA^.Temp:=False;
            Artikelstamm^.Insert(NA);
          End;
        End;
      End;
      Strm.Done;
    End;
  End;

  Procedure CloseArtikel;
  Var Strm: TBufStream;
  Begin
    CloseFile(ArtikelF);
    If Artikelstamm^.Changed Then
    Begin
      Strm.Init('ARTIKEL.IDX', stCreate, 1024);
      Strm.Put(Artikelstamm);
      If Strm.Status<>0 Then
        MessageBox('Artikelindex konnte nicht gesichert werden !', nil, mfError+mfOKButton);
      Strm.Done;
    End;
    Dispose(Artikelstamm, Done);
  End;

Begin
  RegisterType(RArtikel);
  RegisterType(RArtikelStamm);
  RegisterType(RArtikelDialog);
End.