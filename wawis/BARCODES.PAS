unit BarCodes;
interface
  uses
    Objects, WinTypes, WinProcs;

  type
    TBarTyp= (None, EAN8, EAN13);

    PBarCode= ^TBarCode;
    TBarCode= object(TObject)
      Nr: array[0..13] of Byte;
      Typ: TBarTyp; 
      constructor Init(P: PChar);
      procedure Draw(DC: HDC; x, y, Module, Height: Integer);
    end;

implementation

  constructor TBarCode.Init(P: PChar);
  var
    i: Integer;
    Sum: Word;
    Multi, Check: Byte;
  begin
    FillChar(Nr, SizeOf(Nr), $FF);
    i:=0;
    if P<>nil then
    begin
      while P^<>#0 do
      begin
        if (P^>='0') and (P^<='9') then
        begin
          Nr[i]:=Byte(P^)-Byte('0');
          Inc(i);
        end;
        Inc(P);
      end;
    end;
    case i of
      8: Typ:=EAN8;
      13: Typ:=EAN13;
      else Typ:=None;
    end;
    if Typ<>None then
    begin
      Dec(i,2);
      Check:=Nr[i+1];
      Sum:=0;
      Multi:=3;
      while i>=0 do
      begin
        Inc(Sum, Nr[i]*Multi);
        Multi:=Multi Xor 2;
        Dec(i);
      end;
      if ((10-(Sum Mod 10)) Mod 10)<>Check then Typ:=None;
    end;
  end;

  procedure TBarCode.Draw(DC: HDC; x, y, Module, Height: Integer);
  const
    A=0; B=1; C=2;
    CharCode: array[0..2, 0..9] of Byte=
      (($0D, $19, $13, $3D, $23, $31, $2F, $3B, $37, $0B),
       ($27, $33, $1B, $21, $1D, $39, $05, $11, $09, $17),
       ($72, $66, $6C, $42, $5C, $4E, $50, $44, $48, $74));
    Parities: array[0..9] of Byte=
      ($00, $0B, $0D, $0E, $13, $19, $1C, $15, $16, $1A);
  var
    Codes: array[0..13] of Byte;
    OldPen: HPen;
    i: Integer;
    Ch, bit, Middle: Byte;

    procedure DrawModule(On: Byte);
    begin
      if On>0 then
      begin
        MoveTo(DC, x, y);
        if On=1 then
          LineTo(DC, x, y+Height-Height Div 8)
        else
          LineTo(DC, x, y+Height);
      end;
      Inc(x, Module);
    end;

  begin
    if Typ=None then Exit;
    if Typ=EAN8 then
    begin
      FillChar(Codes[0], 4, A);
      Middle:=4;
      FillChar(Codes[4], 4, C);
      i:=0;
    end else
    if Typ=EAN13 then
    begin
      for i:=1 to 6 do
        Codes[i]:=(Parities[Nr[0]] Shr (6-i)) And 1;
      Middle:=7;
      FillChar(Codes[7], 6, C);
      i:=1;
    end;
    OldPen:=SelectObject(DC, CreatePen(ps_Solid, Module, 0));
    DrawModule(2);
    DrawModule(0);
    DrawModule(2);
    while Nr[i]<>$FF do
    begin
      Ch:=CharCode[Codes[i], Nr[i]];
      for bit:=0 to 6 do
        DrawModule((Ch Shr (6-bit)) And 1);
      Inc(i);
      if i=Middle then
      begin
        DrawModule(0);
        DrawModule(2);
        DrawModule(0);
        DrawModule(2);
        DrawModule(0);
      end;
    end;
    DrawModule(2);
    DrawModule(0);
    DrawModule(2);
    DeleteObject(SelectObject(DC, OldPen));
  end;

end.