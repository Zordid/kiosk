{$A+,B-,D+,F-,G-,I-,L+,N-,R-,S+,V+,W+,X+}
{$M 8192,8192}
Program ConvertArtikel;
Uses
  WinCrt, WinProcs, WObjects, Strings,
  Globals, Conv_DB, DBServer, BtpWin,
  Artikel, Lieferanten, Betriebe, Einkauf;

  Type
    TOPreise= Record
      EK: Real;
      Datum: String[8];
      VKVon, VKBis: Real;
    End;

    TOArtikelRec= Record
      Status: LongInt;
      Name: String[30];
      Menge: String[10];
      Lieferant: LongInt;
      ArtikelNr: String[10];
      Preise: Array[0..1] Of TOPreise;
    End;

    POLieferRec= ^TOLieferRec;
    TOLieferRec= Record
      Status: LongInt;
      LieferNr: LongInt;
      Name: String[35];
      Short: String[5];
      Strasse, Ort: String[60];
      Telefon, Telefax: String[30];
    End;

Var
  OldF: TDataFile;
  NewF: TDBFile;
  BF: BFixed;
  O: TOArtikelRec;
  L: TOLieferRec;
  LPtr: POLieferRec;
  D: LongInt;
  I: Byte;
  S: String;
  P: PChar;
  LieferColl: TCollection;
  ArtikelRec: TArtikelRec;
  LieferRec: TLieferRec;
  KioskRec: TBetriebRec;

Procedure CheckBtrieve;
Begin
  If BStatus<>0 Then
  Begin
    Writeln('Btrieve Error: ', BStatus);
    Halt;
  End;
End;

Procedure CreateArtikelFile(Name: String);
Var
  FSpec: PFileSpec;
Begin
  Write('  Lege Artikeldatenbank an... ');
  FSpec:=New(PFileSpec);
  With FSpec^ Do
  Begin
    RecLen    := SizeOf(TArtikelRec);
    FileFlags := 0;
    PageSize  := 1024;
    PreAlloc  := 0;
    NumKeys   := 5;
    FillChar(KeyArray, SizeOf(KeyArray), 0);
    { Schlüssel 0 - Nr }
      With KeyArray[0] Do
      Begin
        KeyPos:=Ofs(ArtikelRec.Nr)-Ofs(ArtikelRec)+1;
        KeyLen:=SizeOf(ArtikelRec.Nr);
        KeyFlags:=Modifiable + ExtType;
        ExtKeyType:=BAutoInc;
      End;
    { Schlüssel 1 - Name }
      With KeyArray[1] Do
      Begin
        KeyPos:=Ofs(ArtikelRec.Name)-Ofs(ArtikelRec)+1;
        KeyLen:=SizeOf(ArtikelRec.Name);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BZString;
      End;
    { Schlüssel 2 - Warengruppe, Name }
      With KeyArray[2] Do
      Begin
        KeyPos:=Ofs(ArtikelRec.Warengruppe)-Ofs(ArtikelRec)+1;
        KeyLen:=SizeOf(ArtikelRec.Warengruppe);
        KeyFlags:=Duplicates + Modifiable + Segmented;
        ExtKeyType:=BString;
      End;
      With KeyArray[3] Do
      Begin
        KeyPos:=Ofs(ArtikelRec.Name)-Ofs(ArtikelRec)+1;
        KeyLen:=SizeOf(ArtikelRec.Name);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BZString;
      End;
    { Schlüssel 3 - Einzelverpackungsart, Name }
      With KeyArray[4] Do
      Begin
        KeyPos:=Ofs(ArtikelRec.EVArt)-Ofs(ArtikelRec)+1;
        KeyLen:=SizeOf(ArtikelRec.EVArt);
        KeyFlags:=Duplicates + Modifiable + ExtType + Segmented;
        ExtKeyType:=BZString;
      End;
      With KeyArray[5] Do
      Begin
        KeyPos:=Ofs(ArtikelRec.Name)-Ofs(ArtikelRec)+1;
        KeyLen:=SizeOf(ArtikelRec.Name);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BZString;
      End;
    { Schlüssel 4 - Mehrwertsteuersatz, Name }
      With KeyArray[6] Do
      Begin
        KeyPos:=Ofs(ArtikelRec.MwSt)-Ofs(ArtikelRec)+1;
        KeyLen:=1;
        KeyFlags:=Duplicates + Modifiable + Segmented;
        ExtKeyType:=BString;
      End;
      With KeyArray[7] Do
      Begin
        KeyPos:=Ofs(ArtikelRec.Name)-Ofs(ArtikelRec)+1;
        KeyLen:=SizeOf(ArtikelRec.Name);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BZString;
      End;
  End;
  Name[Length(Name)+1]:=#0;
  BStatus:=CreateFile(@Name[1], FSpec);
  CheckBtrieve;
  Writeln('Ok');
End;

Procedure CreateLieferFile(Name: String);
Var
  FSpec: PFileSpec;
Begin
  Write('  Lege Lieferantendatenbank an... ');
  FSpec:=New(PFileSpec);
  With FSpec^ Do
  Begin
    RecLen    := SizeOf(TLieferRec);
    FileFlags := 0;
    PageSize  := 1024;
    PreAlloc  := 0;
    NumKeys   := 2;
    FillChar(KeyArray, SizeOf(KeyArray), 0);
    { Schlüssel 0 - Nr }
      With KeyArray[0] Do
      Begin
        KeyPos:=Ofs(LieferRec.Nr)-Ofs(LieferRec)+1;
        KeyLen:=SizeOf(LieferRec.Nr);
        KeyFlags:=Modifiable + ExtType;
        ExtKeyType:=BAutoInc;
      End;
    { Schlüssel 1 - Name }
      With KeyArray[1] Do
      Begin
        KeyPos:=Ofs(LieferRec.Name)-Ofs(LieferRec)+1;
        KeyLen:=SizeOf(LieferRec.Name);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BZString;
      End;
  End;
  Name[Length(Name)+1]:=#0;
  BStatus:=CreateFile(@Name[1], FSpec);
  CheckBtrieve;
  Writeln('Ok');
End;

Procedure CreateKioskFile(Name: String);
Var
  FSpec: PFileSpec;
Begin
  Write('  Lege Kioskdatenbank an... ');
  FSpec:=New(PFileSpec);
  With FSpec^ Do
  Begin
    RecLen    := SizeOf(TBetriebRec);
    FileFlags := 0;
    PageSize  := 1024;
    PreAlloc  := 0;
    NumKeys   := 2;
    FillChar(KeyArray, SizeOf(KeyArray), 0);
    { Schlüssel 0 - Nr }
      With KeyArray[0] Do
      Begin
        KeyPos:=Ofs(KioskRec.Nr)-Ofs(KioskRec)+1;
        KeyLen:=SizeOf(KioskRec.Nr);
        KeyFlags:=Modifiable + ExtType;
        ExtKeyType:=BAutoInc;
      End;
    { Schlüssel 1 - Name }
      With KeyArray[1] Do
      Begin
        KeyPos:=Ofs(KioskRec.Name)-Ofs(KioskRec)+1;
        KeyLen:=SizeOf(KioskRec.Name);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BZString;
      End;
  End;
  Name[Length(Name)+1]:=#0;
  BStatus:=CreateFile(@Name[1], FSpec);
  CheckBtrieve;
  Writeln('Ok');
End;

Procedure CreateArtikelEKFile(Name: String);
Var
  FSpec: PFileSpec;
  EK: TArtikelEKRec;
Begin
  Write('  Lege Artikel-EK-Liste an... ');
  FSpec:=New(PFileSpec);
  With FSpec^ Do
  Begin
    RecLen    := SizeOf(TArtikelEKRec);
    FileFlags := 0;
    PageSize  := 1024;
    PreAlloc  := 0;
    NumKeys   := 3;
    FillChar(KeyArray, SizeOf(KeyArray), 0);
    { Schlüssel 0 - EKNr }
      With KeyArray[0] Do
      Begin
        KeyPos:=Ofs(EK.Nr)-Ofs(EK)+1;
        KeyLen:=SizeOf(EK.Nr);
        KeyFlags:=Modifiable + ExtType;
        ExtKeyType:=BAutoInc;
      End;
    { Schlüssel 1 - Artikel }
      With KeyArray[1] Do
      Begin
        KeyPos:=Ofs(EK.ArtikelNr)-Ofs(EK)+1;
        KeyLen:=SizeOf(EK.ArtikelNr);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BInteger;
      End;
    { Schlüssel 2 - Lieferant }
      With KeyArray[2] Do
      Begin
        KeyPos:=Ofs(EK.LieferantenNr)-Ofs(EK)+1;
        KeyLen:=SizeOf(EK.LieferantenNr);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BInteger;
      End;
  End;
  Name[Length(Name)+1]:=#0;
  BStatus:=CreateFile(@Name[1], FSpec);
  CheckBtrieve;
  Writeln('Ok');
End;

Procedure CreateGlobalSettings(Name: String);
Var FSpec: PFileSpec;
Begin
  Write('  Lege globale Daten an... ');
  New(FSpec);
  With FSpec^ Do
  Begin
    RecLen:=SizeOf(TGlobalSettings);
    FileFlags:=0;
    PageSize:=1024;
    PreAlloc:=0;
    NumKeys:=1;
      With KeyArray[0] Do
      Begin
        KeyPos:=1;
        KeyLen:=1;
        KeyFlags:=Modifiable;
      End;
  End;
  Name[Length(Name)+1]:=#0;
  BStatus:=CreateFile(@Name[1], FSpec);
  CheckBtrieve;
  Writeln('Ok');
End;

Var
  Outpath, Inpath: String;

Function OutFile(F: String): PChar;
Begin
  S:=Outpath+F+#0;
  OutFile:=@S[1];
End;

procedure StrUpper(var S: String);
var i: Integer;
begin
  for i:=1 to Length(S) do S[i]:=UpCase(S[i]);
end;

Begin
  WBtrvInit('Convert');
  Write('Programmverzeichnis: '); Readln(Inpath);
  StrUpper(Inpath);
  Inpath[Length(Inpath)+1]:=#0;
  WritePrivateProfileString(pf_Paths, 'Programm', @Inpath[1], ProfileFile);
  Outpath:=Inpath+'\OS'#0;
  WritePrivateProfileString(pf_Paths, 'Ordersätze', @Outpath[1], ProfileFile);
  Outpath:=Inpath+'\DATEN'#0;
  WritePrivateProfileString(pf_Paths, 'Daten', @Outpath[1], ProfileFile);
  Write('ALTES Datenverzeichnis: '); Readln(Inpath);
  if Inpath[Length(Inpath)]<>'\' then Inpath:=Inpath+'\';
  Outpath[Length(Outpath)]:='\';
  Writeln;
  { Globale Daten }
  Writeln('Datei GLOBALS.DAT anlegen ? (J/N)');
  If ReadKey='j' Then
  Begin
    CreateGlobalSettings(Outpath+'GLOBALS.DAT');
    FillChar(GlobalSettings, SizeOf(GlobalSettings), 0);
    With GlobalSettings Do
    Begin
      MwSt[0]:=15.0;
      StrCopy(MwStString[0], '15,0%');
      MwSt[1]:=7.0;
      StrCopy(MwStString[1], '7,0%');
      MwSt[2]:=5.5;
      StrCopy(MwStString[2], '5,5%');
      StrCopy(Warengruppe[1], 'Getränke');
      StrCopy(Warengruppe[2], 'Spirituosen');
      StrCopy(Warengruppe[3], 'Süsswaren');
      StrCopy(Warengruppe[4], 'Tabakwaren');
      StrCopy(Warengruppe[5], 'Imbißartikel');
      StrCopy(Warengruppe[6], 'Eis');
    End;
    Write('  Speichere Daten... ');
    BF.Init(OutFile('GLOBALS.DAT'), Normal);
    Move(GlobalSettings, BF.DBuffer, SizeOf(GlobalSettings));
    BStatus:=BF.BT(BInsert, 0);
    CheckBtrieve;
    Writeln('Ok');
    BStatus:=BF.Close;
    BF.Done;
    Writeln;
  End;
  { Daten konvertieren }
  Writeln('Sollen die Lieferanten-Stammdaten konvertiert werden ? (J/N)');
  If ReadKey='j' Then
  Begin
    CreateLieferFile(Outpath+'LIEFER.DAT');
    Write('  Konvertiere Lieferanten...');
    OpenFile(OldF, Inpath+'LIEFER.DAT', SizeOf(TOLieferRec));
    If (Not Ok) Or (InOutRes<>0) Then
    Begin
      Writeln('Error: ', IOResult);
      Halt;
    End;
    LieferColl.Init(10, 5);
    NewF.Init(OutFile('LIEFER.DAT'), Accel, 0);
    CheckBtrieve;
    For D:=1 To FileLen(OldF)-1 Do
    Begin
      GetRec(OldF, D, L);
      New(LPtr);
      Move(L, LPtr^, SizeOf(L));        
      LieferColl.Insert(LPtr);        
      If (L.Status=0) Then
      Begin
        FillChar(LieferRec, SizeOf(LieferRec), 0);
        With LieferRec Do
        Begin
          Nr:=0;
          StrPCopy(Name, L.Name);
          OemToAnsi(Name, Name);
          StrPCopy(Short, L.Short);
          OemToAnsi(Short, Short);
          StrPCopy(Anschrift[0], L.Strasse);
          OemToAnsi(Anschrift[0], Anschrift[0]);
          StrPCopy(Anschrift[2], L.Ort);
          OemToAnsi(Anschrift[2], Anschrift[2]);
          StrPCopy(Telefon, L.Telefon);
          OemToAnsi(Telefon, Telefon);
          StrPCopy(Telefax, L.Telefax);
          OemToAnsi(Telefax, Telefax);
        End;
        Move(LieferRec, ExtDBuffer^.Entire, SizeOf(LieferRec));
        NewF.BT(BInsert, 0);
        Move(ExtDBuffer^, LieferRec, SizeOf(LieferRec));
        LPtr^.Status:=LieferRec.Nr;
        With LieferRec Do Write(Nr:4);
        GotoXY(WhereX-4, WhereY);
      End;
    End;
    Conv_DB.CloseFile(OldF);
    NewF.Close;
    NewF.Done;
    Writeln;
    Writeln;
  End;
  Writeln('Sollen die Artikel-Stammdaten konvertiert werden ? (J/N)');
  If ReadKey='j' Then
  Begin
    CreateArtikelFile(Outpath+'ARTIKEL.DAT');
    Write('  Konvertiere Artikel... ');
    OpenFile(OldF, Inpath+'ARTIKEL.DAT', SizeOf(TOArtikelRec));
    If (Not Ok) Or (InOutRes<>0) Then
    Begin
      Writeln('Error: ', IOResult);
      Halt;
    End;
    NewF.Init(OutFile('ARTIKEL.DAT'), Accel, 0);
    CheckBtrieve;
    For D:=1 To FileLen(OldF)-1 Do
    Begin
      GetRec(OldF, D, O);
      If (O.Status=0) And
         (O.Name<>'') And
         (Not (O.Name[1] In ['x', ',', ' '])) Then
      Begin
        FillChar(ArtikelRec, SizeOf(ArtikelRec), 0);
        With ArtikelRec Do
        Begin
          Nr:=0;
          StrPCopy(Name, O.Name);
          OemToAnsi(Name, Name);
          StrPCopy(EVInhalt, O.Menge);
          OemToAnsi(EVInhalt, EVInhalt);
          EVArt[0]:=#0;
          O.Menge:=Copy(O.Menge, 1,2);
          If (O.Menge='FL') Or (O.Menge='EW') Or
             (O.Menge='MW') Or (O.Menge='DS') Then
          Begin
            P:=StrRScan(EVInhalt, '/');
            If P<>nil Then
            Begin
              StrCopy(EVArt, EvInhalt);
              EVArt[2]:=#0;
              Inc(P);
              StrCopy(EVInhalt, P);
              StrCat(EVInhalt, ' l');
            End else
              EVInhalt[0]:=#0;
          End else
            EVInhalt[0]:=#0;
          Warengruppe:=0;
        End;
        Move(ArtikelRec, ExtDBuffer^, SizeOf(ArtikelRec));
        NewF.BT(BInsert, 0);
        Move(ExtDBuffer^, ArtikelRec, SizeOf(ArtikelRec));
        With ArtikelRec Do
          Write(Nr:4);
        GotoXY(WhereX-4, WhereY);
      End;
    End;
    Conv_DB.CloseFile(OldF);
    NewF.Close;
    NewF.Done;
    Writeln;
    Writeln;
  End;
  { Kiosk }
  Writeln('Sollen die Betriebe-Stammdaten angelegt werden ? (J/N)');
  If ReadKey='j' Then
    CreateKioskFile(Outpath+'BETRIEBE.DAT');
  { Artikel EK }
  Writeln('Sollen die Einkaufslisten-Stammdaten angelegt werden ? (J/N)');
  If ReadKey='j' Then
    CreateArtikelEKFile(Outpath+'EKLISTE.DAT');
  Writeln;
  Writeln('Programm beendet.');
  { Create global settings }
  WBtrvStop;
End.