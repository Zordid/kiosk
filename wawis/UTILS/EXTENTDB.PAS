program Extent;
uses WinCrt, BtpWin, Strings;

type
  TOldData= record
    Nr: LongInt;
    ChangeRev: Byte;
    ArtikelNr: LongInt;
    LieferantenNr: LongInt;
    LieferArtNr: array[0..10] of Char;
    UVMenge: Integer;
    UVPreis: Single;
  end;

  TNewData= record
    Nr: LongInt;
    ChangeRev: Byte;
    ArtikelNr: LongInt;
    LieferantenNr: LongInt;
    LieferArtNr: array[0..13] of Char;
    UVMenge: Integer;
    UVPreis: Single;
  end;

  TOldFile= object(BFile)
    Fields: TOldData;
    KeyBuf: array[0..20] of Char;
    constructor Init;
    function BT(OpCode, Key:integer):integer; virtual;
  end;

  TNewFile= object(BFile)
    Fields: TNewData;
    KeyBuf: array[0..20] of Char;
    constructor Init;
    function BT(OpCode, Key:integer):integer; virtual;
    procedure SetFields;
  end;

var
  NewFile: TNewFile;
  OldFile: TOldFile;

constructor TOldFile.Init;
begin
   BFile.Init('c:\prgs\wawis\daten\ekliste.wd', Accel);              
end;

function TOldFile.BT(OpCode, Key:integer):integer;
begin
   DBufferLen := Specs.RecLen;
   BT := Btrv(OpCode, PosBlk, Fields, DBufferLen, KeyBuf, Key);
end;

constructor TNewFile.Init;
begin
   BFile.Init('c:\prgs\wawis\daten\ekliste.wd2', Accel);              
end;

function TNewFile.BT(OpCode, Key:integer):integer;
begin
   DBufferLen := Specs.RecLen;
   BT := Btrv(OpCode, PosBlk, Fields, DBufferLen, KeyBuf, Key);
end;

procedure TNewFile.SetFields;
begin
  with OldFile.Fields do
  begin
    Fields.Nr:=Nr;
    Fields.ChangeRev:=ChangeRev;
    Fields.ArtikelNr:=ArtikelNr;
    Fields.LieferantenNr:=LieferantenNr;
    StrCopy(Fields.LieferArtNr, LieferArtNr);
    Fields.UVMenge:=UVMenge;
    Fields.UVPreis:=UVPreis;
  end;
end;

Procedure CreateArtikelEKFile(Name: String);
Var
  FSpec: PFileSpec;
  NewData: TNewData;
Begin
  Write('  Lege Artikel-EK-Liste an... ');
  FSpec:=New(PFileSpec);
  With FSpec^ Do
  Begin
    RecLen    := SizeOf(TNewData);
    FileFlags := 0;
    PageSize  := 1024;
    PreAlloc  := 0;
    NumKeys   := 3;
    FillChar(KeyArray, SizeOf(KeyArray), 0);
    { Schlüssel 0 - EKNr }
      With KeyArray[0] Do
      Begin
        KeyPos:=Ofs(NewData.Nr)-Ofs(NewData)+1;
        KeyLen:=SizeOf(NewData.Nr);
        KeyFlags:=Modifiable + ExtType;
        ExtKeyType:=BAutoInc;
      End;
    { Schlüssel 1 - Artikel }
      With KeyArray[1] Do
      Begin
        KeyPos:=Ofs(NewData.ArtikelNr)-Ofs(NewData)+1;
        KeyLen:=SizeOf(NewData.ArtikelNr);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BInteger;
      End;
    { Schlüssel 2 - Lieferant }
      With KeyArray[2] Do
      Begin
        KeyPos:=Ofs(NewData.LieferantenNr)-Ofs(NewData)+1;
        KeyLen:=SizeOf(NewData.LieferantenNr);
        KeyFlags:=Duplicates + Modifiable + ExtType;
        ExtKeyType:=BInteger;
      End;
  End;
  Name[Length(Name)+1]:=#0;
  BStatus:=CreateFile(@Name[1], FSpec);
  If BStatus<>0 Then
  Begin
    Writeln('Btrieve Error: ', BStatus);
    Halt;
  End;
  Writeln('Ok');
End;

var
  Count: Word;

begin
  CreateArtikelEKFile('c:\prgs\wawis\daten\ekliste.wd2');
  OldFile.Init;
  NewFile.Init;
  Writeln;
  Writeln('Kopiere ', OldFile.NumRecs, ' Datensätze...');
  Count:=0;
  BStatus:=OldFile.BT(BGetFirst, 0);
  while BStatus=0 do
  begin
    Inc(Count);
    Write(Count:5); GotoXY(1, WhereY);
    NewFile.SetFields;
    BStatus:=NewFile.BT(BInsert, 0);
    if BStatus<>0 then
    begin
      Writeln;
      Writeln('BTrieve Error !');
      Halt;
    end;
    BStatus:=OldFile.BT(BGetNext, 0);
  end;
  Writeln;
  NewFile.Close;
  NewFile.Init;
  Writeln('Neue Datei enthält ', NewFile.NumRecs, ' Records');
  NewFile.Close;
  OldFile.Close;
  NewFile.Done;
  OldFile.Done;
end.