{ WBTRCALL - Btrieve requester for Windows 3.1, forwarding to Btrieve for DOS. }
{                                                                            }
{ Written in 2026. WAWIS imports WBTRCALL.DLL, Novell's Btrieve interface    }
{ for Windows, through BTPWIN.PAS; the original DLL has not been found.     }
{ Novell's smaller "requester" WBTRCALL.DLL passed every call on to a       }
{ Btrieve record manager loaded in DOS before Windows; this stand-in does   }
{ the same with Btrieve for DOS 5.10a (BTRIEVE.EXE). Per call it copies the }
{ position block, the key and the data into a buffer below 1 MB, fills the  }
{ parameter block exactly like Novell's TUR5BTRV.PAS and issues interrupt   }
{ 7Bh in real mode through DPMI (int 31h, function 0300h). Without the TSR  }
{ every call answers status 20, "Btrieve not loaded". If C:\AUTO\BTRV.LOG   }
{ exists, each call is appended to it (operation, key, status).             }
{                                                                            }
{ BTP asks for as many records per extended call (Get Next Extended etc.)   }
{ as fit into 32 KB; Btrieve 5.10a refuses that with status 22. The bridge  }
{ then asks again for half, a quarter, ... of the records; the program      }
{ reads on until the end of the file anyway.                                }

library WBTRCALL;

uses WinTypes, WinProcs;

const
  BtrieveNotLoaded = 20;
  BVersion         = 26;
  BtrInt           = $7B;
  BtrOffset        = $0033;          { Btrieve's interrupt handler offset }
  VarId            = $6176;          { 'va': language interface id }
  MaxData          = 32767;          { Btrieve buffer lengths are Integers }

  { layout of the buffer below 1 MB }
  OfsParms = 0;                      { 28-byte parameter block }
  OfsStat  = 28;                     { status word }
  OfsPos   = 32;                     { 128-byte position block }
  OfsKey   = 160;                    { key buffer, 256 bytes }
  OfsData  = 416;                    { data buffer }
  DosSize  = OfsData + MaxData;

type
  TBtrParms = record
    BufOfs, BufSeg: Word;
    BufLen: Integer;
    CurOfs, CurSeg: Word;
    FcbOfs, FcbSeg: Word;
    Func: Integer;
    KeyOfs, KeySeg: Word;
    KeyLen: Byte;
    KeyNum: ShortInt;
    StatOfs, StatSeg: Word;
    XfaceId: Integer;
  end;

  TRealRegs = record                 { DPMI real-mode call structure }
    EDI, ESI, EBP, Reserved, EBX, EDX, ECX, EAX: LongInt;
    Flags, ES, DS, FS, GS, IP, CS, SP, SS: Word;
  end;

  PBytes = ^TBytes;
  TBytes = array[0..65534] of Byte;

var
  DosSel, DosSeg: Word;              { protected-mode selector, real-mode segment }
  Regs: TRealRegs;

function GetSelectorLimit(Selector: Word): LongInt; far; external 'KERNEL' name 'GETSELECTORLIMIT';

const
  LogName = 'C:\AUTO\BTRV.LOG';

{$I-}
procedure LogHex(Data: PBytes; N: Word);
const H: array[0..15] of Char = '0123456789ABCDEF';
var
  F: Text;
  I: Word;
begin
  Assign(F, LogName);
  Append(F);
  if IOResult <> 0 then Exit;
  Write(F, '  descriptor:');
  for I := 0 to N - 1 do Write(F, ' ', H[Data^[I] shr 4], H[Data^[I] and 15]);
  Writeln(F);
  Close(F);
  if IOResult <> 0 then;
end;

procedure Log(Op, KeyNum, Stat, Len: Integer; Key: PBytes; KLen: Word);
var
  F: Text;
  I: Word;
begin
  Assign(F, LogName);
  Append(F);
  if IOResult <> 0 then Exit;
  Write(F, 'op=', Op, ' key#=', KeyNum, ' status=', Stat, ' len=', Len, ' key="');
  I := 0;
  while (I < KLen) and (I < 40) and (Key^[I] >= 32) and (Key^[I] < 127) do
  begin
    Write(F, Chr(Key^[I]));
    Inc(I);
  end;
  Writeln(F, '"');
  Close(F);
  if IOResult <> 0 then;
end;
{$I+}

{ How many bytes from P on can be read: the rest of its segment, at most Want. }
function Avail(var X; Want: Word): Word;
var Limit: LongInt;
begin
  Limit := GetSelectorLimit(Seg(X));
  if LongInt(Ofs(X)) + Want - 1 > Limit then
    Avail := Limit - Ofs(X) + 1
  else
    Avail := Want;
end;

function BtrieveLoaded: Boolean;
var VecOfs: Word;
begin
  asm
    mov ax, 0200h                    { get real-mode interrupt vector }
    mov bl, BtrInt
    int 31h
    mov VecOfs, dx
  end;
  BtrieveLoaded := VecOfs = BtrOffset;
end;

{ Issue interrupt 7Bh in real mode with DS:DX = the parameter block. }
function CallBtrieve: Integer;
begin
  Integer(Ptr(DosSel, OfsStat)^) := 0;
  FillChar(Regs, SizeOf(Regs), 0);
  Regs.DS := DosSeg;
  Regs.EDX := OfsParms;
  asm
    push es
    push di
    mov ax, ds
    mov es, ax
    mov di, offset Regs
    mov ax, 0300h                    { simulate real-mode interrupt }
    mov bx, BtrInt
    xor cx, cx
    int 31h
    pop di
    pop es
  end;
  CallBtrieve := Integer(Ptr(DosSel, OfsStat)^);
end;

{ Find the extractor of an extended descriptor in Buf at OfsData: the
  descriptor is length, 'EG'/'UC', max. rejects, number of terms (2 bytes
  each), the terms (7 bytes + value or 2-byte field offset), then the
  extractor: number of records, number of fields, fields (length, offset).
  Returns the offset of the record count; RecLen is the size of one record
  in the reply (fields + length word + position). }
function ExtInfo(Buf: PBytes; var RecLen: Word): Word;
var
  Terms, Fields, I, Ofs, Len: Word;
begin
  Terms := Word((@Buf^[OfsData + 6])^);
  Ofs := OfsData + 8;
  for I := 1 to Terms do
  begin
    Len := Word((@Buf^[Ofs + 1])^);
    if Buf^[Ofs + 5] and 64 <> 0 then Inc(Ofs, 7 + 2) else Inc(Ofs, 7 + Len);
  end;
  Fields := Word((@Buf^[Ofs + 2])^);
  RecLen := 6;
  for I := 0 to Fields - 1 do Inc(RecLen, Word((@Buf^[Ofs + 4 + 4 * I])^));
  ExtInfo := Ofs;
end;

function WBRQSHELLINIT(opStr: PChar): Integer; export;
begin
  WBRQSHELLINIT := 0;
end;

function WBTRVINIT(opStr: PChar): Integer; export;
begin
  WBTRVINIT := 0;
end;

procedure WBTRVSTOP; export;
begin
end;

function BTRCALL(Op: Integer; var FCB; var Dat; var Rec_Len: Integer;
  var Key; KLen: Byte; KeyNum: Byte): Integer; export;
var
  Buf: PBytes;
  P: ^TBtrParms;
  Len, Max, Need, NOfs, RecLen, OrigN, DescLen, Divisor: Word;
  Ext: Boolean;
  Stat: Integer;
begin
  BTRCALL := BtrieveNotLoaded;
  if (DosSel = 0) or not BtrieveLoaded then
  begin
    Log(Op, KeyNum, BtrieveNotLoaded, 0, @Key, 0);
    Exit;
  end;
  Buf := Ptr(DosSel, 0);
  Max := Word(Rec_Len);
  if Op mod 100 = BVersion then Max := 5;   { BTP passes length 0; Btrieve writes 5 bytes anyway }
  if Max > MaxData then Max := MaxData;
  Max := Avail(Dat, Max);
  KLen := Avail(Key, KLen);
  Move(FCB, Buf^[OfsPos], 128);
  if KLen > 0 then Move(Key, Buf^[OfsKey], KLen);
  if Max > 0 then Move(Dat, Buf^[OfsData], Max);

  P := Ptr(DosSel, OfsParms);
  with P^ do
  begin
    BufSeg := DosSeg;  BufOfs := OfsData;
    BufLen := Max;
    FcbSeg := DosSeg;  FcbOfs := OfsPos;
    CurSeg := DosSeg;  CurOfs := OfsPos + 38;
    Func := Op;
    KeySeg := DosSeg;  KeyOfs := OfsKey;
    KeyLen := 255;
    StatSeg := DosSeg; StatOfs := OfsStat;
    XfaceId := VarId;
  end;
  P^.KeyNum := ShortInt(KeyNum);
  Integer(Ptr(DosSel, OfsStat)^) := 0;

  Ext := (Op mod 100 >= 36) and (Op mod 100 <= 38);
  if Ext then
  begin
    NOfs := ExtInfo(Buf, RecLen);
    OrigN := Word((@Buf^[NOfs])^);
    DescLen := Word((@Buf^[OfsData])^);
  end;
  Stat := CallBtrieve;
  Divisor := 2;
  while Ext and (Stat = 22) and (OrigN div Divisor >= 1) do
  begin
    { the failed call may have overwritten the buffers: start afresh }
    Move(FCB, Buf^[OfsPos], 128);
    if KLen > 0 then Move(Key, Buf^[OfsKey], KLen);
    Move(Dat, Buf^[OfsData], Max);
    Word((@Buf^[NOfs])^) := OrigN div Divisor;
    Need := LongInt(OrigN div Divisor) * RecLen + 2;
    if Need < DescLen then Need := DescLen;
    if Need > Max then Need := Max;
    P^.BufLen := Need;
    Stat := CallBtrieve;
    Divisor := Divisor * 2;
  end;
  Len := Word(P^.BufLen);
  if Len > Max then Len := Max;
  Move(Buf^[OfsPos], FCB, 128);
  if KLen > 0 then Move(Buf^[OfsKey], Key, KLen);
  if Len > 0 then Move(Buf^[OfsData], Dat, Len);
  Rec_Len := Len;
  Log(Op, KeyNum, Stat, Len, @Key, KLen);
  BTRCALL := Stat;
end;

exports
  WBRQSHELLINIT,
  WBTRVINIT,
  WBTRVSTOP,
  BTRCALL;

var
  Block: LongInt;
begin
  Block := GlobalDosAlloc(DosSize);
  DosSel := LoWord(Block);
  DosSeg := HiWord(Block);
end.
