{***************************************************************************}
{* BTP Windows Unit                                                        *}
{***************************************************************************}
Unit BTPWin;
Interface
  Uses Objects, WinDos, Strings;

{$I BTRIEVE.INC}

{   Unit-Specific Constants         }
{ --------------------------------- }
  Const
    MaxFixedRecLength   =  4090; {Btrieve limits fixed record length for std  }
    MaxKBufferLength    =   255; {files to 4090.  Max key size is 255.        }
    MaxExtDBufferLength = 32767;

{***************************************************************************}
{* BTP type definitions                                                    *}
{***************************************************************************}
  Type
    TVersion= Record
      Case Integer Of
        1: (Number : Word;
            Rev    : Integer;
            Product: Char);
        2: (Entire : Array[1..5] Of Char);
      End;

    PRecMgr= ^TRecMgr;
    TRecMgr= Object(TObject)              {Base obj handles abort/begin/end}
      Version: TVersion;                  {tran, reset, version and stop.  }
      VersionString: Array[0..20] Of Char;
      Constructor Init;
      Function BT(OpCode, Key: Integer): Integer; virtual;
    End;

    { Data types for BFile object }
    { --------------------------- }
    BPosition= Longint;
    BFileName= Array[1..80] Of Char;      {79 + blank pad required by Btrieve}

    PKeySpec= ^TKeySpec;
    TKeySpec= Record                      {data type for a Btrieve key spec}
      Case Integer Of
        1: (KeyPos     : Integer;
            KeyLen     : Integer;
            KeyFlags   : Integer;
            NotUsed    : Array[1..4] Of Byte;
            ExtKeyType : Byte;
            NullValue  : Byte;
            Reserved   : Array[1..4] Of Byte);
        2: (Entire     : Array[1..16] Of Byte);
      End;

    PFileSpec= ^TFileSpec;
    TFileSpec= Record
      Case Integer Of
        1: (RecLen    : Integer;
            PageSize  : Integer;
            NumKeys   : Integer;
            NumRecs   : Array[1..2] Of Integer;
            FileFlags : Integer;
            Reserved  : Array[1..2] Of Char;
            PreAlloc  : Integer;
            KeyArray  : Array[0..23] Of TKeySpec);
        2: (SpecBuf   : Integer);
        3: (Entire    : Array[1..400] Of Byte);
      End;

    PBFile= ^BFile;
    BFile= Object(TObject)
      DFileName: Array[0..fsPathName] Of Char;
      Specs: TFileSpec;
      NumRecs: Longint;
      NumSegs: Integer;
      PosBlk: Array[1..128] Of Char;
      DBufferLen: Integer;
      Constructor Init(UserFileName: PChar; OpenMode: Integer);
      Function GetStats: Integer;
      Function BT(OpCode, Key: Integer): Integer; virtual;
      Function Open(OpenMode: Integer): Integer; virtual;
      Function Close: Integer; virtual;
    End;

    { Data types for BFixed object - descendant of BFile }
    { -------------------------------------------------- }
    TDBuffer= Array[1..MaxFixedRecLength] Of Byte;
    TKBuffer= Array[1..MaxKBufferLength] Of Byte;

    PBFixed= ^BFixed;
    BFixed= Object(BFile)
      DBuffer: TDBuffer;
      KBuffer: TKBuffer;
      Constructor Init(UserFileName: PChar; OpenMode: Integer);
      Function BT(OpCode, Key: Integer): Integer; virtual;
    End;

    { Data types for BFileExt object - descendant of BFile }
    { ---------------------------------------------------- }
   TCharArray= Array[1..255] Of Char;
   THeader= Record
     Case Integer Of
       1: (DBufferLen : Integer;
           Constant   : Array[1..2] Of Char);
       2: (Entire     : Array[1..4] Of Byte);
   End;
   TFilter= Record
     Case Integer Of
       1: (MaxSkip       : Integer;
           NumLogicTerms : Integer);
       2: (Entire        : Array[1..2] Of Integer);
   End;
   TLogicTerm= Record
     FieldType  : Byte;
     FieldLen   : Integer;
     Offset     : Integer;      
     CompCode   : Byte;
     Expression : Byte;              { 0 last term,1 AND w/next,2 OR w/next }
     Case FieldComp: Boolean Of
       True : (CompOffset: Integer);
       False: (Value: TCharArray);   { an arbitrary limitation of }
   End;                              { 255 on length of values    }
   PFilterSpec= ^TFilterSpec;
   TFilterSpec= Object(TObject)
     LogicTerm: TLogicTerm;
     Constructor InitF(FieldType: Byte; FieldLen, Offset:
                       Integer; CompCode, Expression: Byte;
                       FieldComp: Boolean; CompOffset: Integer);
     Constructor InitV(FieldType: Byte; FieldLen, Offset:
                       Integer; CompCode, Expression: Byte;
                       FieldComp: Boolean; Value: TCharArray);
   End;
   TExtractor= Record
     Case Integer Of
       1: (NumRecords: Word;
           NumFields : Word);
       2: (Entire    : Array[1..2] Of Word);
   End;
   TExtRepeater= Record
     FieldLen: Integer;
     Offset  : Integer;
   End;
   PExtSpec= ^TExtSpec;
   TExtSpec= Object(TObject)
     ExtRepeater: TExtRepeater;
     Constructor Init(Len, Ofs: Integer);
   End;
   PExtDBuffer= ^TExtDBuffer;
   TExtDBuffer= Record
     Case Integer Of
       1: (Header   : THeader;       
           Filter   : TFilter);         
       2: (NumRecs  : Integer;
           Repeater : Array[1..32765] Of Char);
             { Repeater structure is: 2 for length of record image,    }
             {                        4 for currency position of rec,  }
             {                        n for record image itself        }
       3: (Entire   : Array[1..$FFFF] Of Byte);
   End;
   PBFileExt= ^BFileExt;
   BFileExt= Object(BFile)
     Header        : THeader;
     Filter        : TFilter;
     FilterSpec    : PCollection;
     Extractor     : TExtractor;
     ExtractorSpec : PCollection;
     Constructor Init(UserFileName: PChar; OpenMode: Integer);
     Function BTExt(OpCode, Key: Integer): Integer; virtual;
     Destructor Done; virtual;
    private
     Procedure SetExtDBufferLen;
     Procedure MakeExtDBuffer;
   End;

{***************************************************************************}
{* BTP exported variables                                                  *}
{***************************************************************************}
  Var
    ExtDBuffer     : PExtDBuffer;
    BStatus        : Integer;
    VarNotRequired : Integer;
    VarPosBlk      : Array[1..128] Of Char;
    {$IFDEF LOG}
    LogFile        : Text;
    {$ENDIF}

{***************************************************************************}
{* BTP exported routines                                                   *}
{***************************************************************************}
  function BtpWinInit(opStr: PChar): Integer;
  Procedure BtpWinDone;
  Function CreateFile(UserFileName: PChar; UserFileSpec:PFileSpec): Integer;
  Function WBrqShellInit(opStr: PChar): Integer;
  Function WBtrvInit(opStr: PChar): Integer;
  Procedure WBtrvStop;
  Function BtrCall(Op: Integer;
                   var FCB;
                   var Dat;
                   var Rec_Len: Integer;
                   var Key;
                   KLen: Byte;
                   KeyNum: Byte): Integer;
  Function Btrv(Op: Integer; var FCB; var Dat; var Rec_Len: Integer;
    var Key; KeyNum: ShortInt): Integer;

Implementation

{***************************************************************************}
{* TRecMgr Object                                                          *}
{***************************************************************************}
  Constructor TRecMgr.Init;
  Var
    P: PChar;
    BNumber, BRev: Array[0..2] Of Char;
  Begin
    TObject.Init;
    BStatus := Btrv(BVersion, VarPosBlk, Version, VarNotRequired, VarNotRequired, Zero);
    Str(Version.Number:2, BNumber);
    If BNumber[0]=' ' Then Move(BNumber[1], BNumber[0], 2);
    Str(Version.Rev:2, BRev);
    StrCopy(VersionString, BNumber);
    StrCat(VersionString, '.');
    StrCat(VersionString, BRev);
    P:=StrEnd(VersionString);
    P^:=Version.Product;
    Inc(P);
    P^:=#0;
  End;

  { Will not handle reset of other workstations as written, as no true key   }
  { buffer is passed. Will handle begin/end/abort transaction, reset & stop. }
  { Would also handle version op, but is handled by BRecMgr.Init anyway !    }
  Function TRecMgr.BT(OpCode, Key: Integer): Integer;
  Begin
    BT:=Btrv(OpCode, VarPosBlk, VarNotRequired, VarNotRequired,
             VarNotRequired, Key);
  End;

{***************************************************************************}
{* BFile Object                                                            *}
{***************************************************************************}
  Constructor BFile.Init(UserFileName: PChar; OpenMode: Integer);
  Var
    Status: Integer;
  Begin
    TObject.Init;
    StrLCopy(DFileName, UserFileName, fsPathName);
    Status := Open(OpenMode);
    If Status = 0 Then Status:=GetStats;
    BStatus := Status;
  End;

  Function BFile.GetStats: Integer;
  Var
    FileBufLen, KeyBufLen: Integer;
    I, Status: Integer;
    NumRecsWord1,
    NumRecsWord2: Word;
  Begin
    FileBufLen:=400;
    KeyBufLen:=384;
    Status:=Btrv(BStat, PosBlk, Specs.SpecBuf, FileBufLen, KeyBufLen, Zero);
    If Status = 0 Then
    Begin
      NumRecsWord1 := Specs.NumRecs[1];  {get rid of sign bit!! by  }
      NumRecsWord2 := Specs.NumRecs[2];  {converting 2 ints to words}
      NumRecs := NumRecsWord1 + NumRecsWord2 * 65536;
      NumSegs := Specs.NumKeys;
      For I:=0 To 23 Do
        If (Specs.KeyArray[I].KeyFlags And Segmented)=Segmented Then
          Inc(NumSegs);
      DBufferLen := Specs.RecLen;
    End;
    GetStats:=Status;
  End;

  Function BFile.BT(OpCode, Key: Integer): Integer;
  Begin
    Abstract;
  End;

  Function BFile.Open(OpenMode: integer): Integer;
  Begin
    Open:=Btrv(BOpen, PosBlk, VarNotRequired, Zero, DFileName, OpenMode);
  End;

  Function BFile.Close: Integer;
  Begin
    Close:=Btrv(BClose, PosBlk, VarNotRequired, VarNotRequired,
                VarNotRequired, NotRequired);
  End;

{***************************************************************************}
{* BFixed Object                                                           *}
{***************************************************************************}
  Constructor BFixed.Init(UserFileName: PChar; OpenMode: Integer);
  Begin
    BFile.Init(UserFileName, OpenMode);
  End;

  Function BFixed.BT(OpCode, Key: Integer): Integer;
  Begin
    BT:=Btrv(OpCode, PosBlk, DBuffer, Specs.RecLen, KBuffer, Key);
  End;

{***************************************************************************}
{* TFilterSpec Object                                                      *}
{***************************************************************************}
  { Be sure to remember that the offset parameter here is 0 relative to }
  { start of record!!                                                   }
  Constructor TFilterSpec.InitF(FieldType: Byte; FieldLen, Offset: Integer;
                                CompCode, Expression: Byte; FieldComp: Boolean;
                                CompOffset: Integer);
  Begin
    TObject.Init;
    LogicTerm.FieldType  := FieldType;
    LogicTerm.FieldLen   := FieldLen;
    LogicTerm.Offset     := Offset;
    LogicTerm.CompCode   := CompCode;
    LogicTerm.Expression := Expression;
    LogicTerm.FieldComp  := FieldComp;
    LogicTerm.CompOffset := Offset;
  End;

  { Be sure to remember that the offset parameter here is 0 relative to }
  { start of record!!                                                   }
  Constructor TFilterSpec.InitV(FieldType: Byte; FieldLen, Offset: Integer;
                                CompCode, Expression: Byte; FieldComp: Boolean;
                                Value: TCharArray);
  Begin
    TObject.Init;
    LogicTerm.FieldType := FieldType;
    LogicTerm.FieldLen  := FieldLen;
    LogicTerm.Offset    := Offset;
    LogicTerm.CompCode  := CompCode;
    LogicTerm.Expression:= Expression;
    LogicTerm.FieldComp := FieldComp;
    LogicTerm.Value     := Value;
  End;

{___________________________________________________________________________}
{_ TExtSpec Object                                                         _}
{___________________________________________________________________________}
  Constructor TExtSpec.Init(Len, Ofs: Integer);
  Begin
    TObject.Init;
    ExtRepeater.FieldLen := Len;
    ExtRepeater.Offset   := Ofs;
  End;

{___________________________________________________________________________}
{_ BFileExt Object                                                         _}
{___________________________________________________________________________}
  Constructor BFileExt.Init(UserFileName: PChar; OpenMode: Integer);
  Begin
    BFile.Init(UserFileName, OpenMode);
    Header.Constant[1] := 'E';
    Header.Constant[2] := 'G';
    If ExtDBuffer=nil Then New(ExtDBuffer);
    FillChar(Filter, SizeOf(Filter), 0);
    FillChar(Extractor, SizeOf(Extractor), 0);
    FilterSpec    := New(PCollection, Init(2,2));
    ExtractorSpec := New(PCollection, Init(5,2));
    If (ExtDBuffer = nil) Or (FilterSpec = nil) Or (ExtractorSpec = nil) Then
      Fail;
  End;

  Destructor BFileExt.Done;
  Begin
    Dispose(ExtractorSpec, Done);
    Dispose(FilterSpec, Done);
    BFile.Done;
  End;

  { Compute sizes of data buffers sent and returned, to determine proper }
  { size to specify in call.                                             }
  { Assumes user program has inserted proper items into the collections  }
  { for filter terms and extractor specs.                                }
  Procedure BFileExt.SetExtDBufferLen;
  Var
    LengthSent, LengthReturned,
    RecordLengthReturned, RecordImageReturned: Word;

    Procedure MakeFilterSpecs;
      Procedure CalcFilterLengths(FSpec: PFilterSpec); far;
      Begin
        With FSpec^ Do
        Begin
          Inc(LengthSent, 7);
          If (LogicTerm.CompCode And UseField) = UseField Then
            Inc(LengthSent, 2)
          Else
            Inc(LengthSent, LogicTerm.FieldLen);
        End;
      End;
     Begin
       FilterSpec^.ForEach(@CalcFilterLengths);
     End;

     Procedure MakeExtSpecs;
       Procedure CalcExtLengths(ExtSpec: PExtSpec); far;
       Begin
         With ExtSpec^ Do
         Begin
           Inc(LengthSent, 4);
           Inc(RecordLengthReturned, ExtRepeater.FieldLen);
         End;
       End;
     Begin
       ExtractorSpec^.ForEach(@CalcExtLengths);
     End;

  Begin
    LengthSent := 8; {4 for header length, 4 for fixed filter length}
    {Work on filter logic term portion of spec.}
    MakeFilterSpecs;
    {Work on extractor portion of spec.}
    Inc(LengthSent, 4);
    RecordLengthReturned := 0;
    MakeExtSpecs;
    If RecordLengthReturned=0 Then RecordLengthReturned:=1;
    {2 for count of recs, 4 for currency pos}
    RecordImageReturned := RecordLengthReturned + 6;
    {2 for count of recs}
    LengthReturned := 2 + (RecordImageReturned * Extractor.NumRecords);
    Header.DBufferLen := LengthSent;
    If LengthSent >= LengthReturned Then
      DBufferLen := LengthSent
    Else
      DBufferLen := LengthReturned;
  End;

  { Private to BFileExt, called in BFileExt.BT, which is called by each }
  { descendant's override of BFileExt.BT.  Assumes program has already  }
  { set up the collections required.                                    }
  Procedure BFileExt.MakeExtDBuffer;
  Var Offset: Integer;

    Procedure MoveFilterSpecs;
      Procedure MoveSingleFilterSpec(FSpec: PFilterSpec); far;
      Begin
        With FSpec^ Do
        Begin
          {move fixed part of logic term}
          Move(LogicTerm, ExtDBuffer^.Entire[Offset], 7);
          {now need to move variable part of logic term}
          Inc(Offset, 7);
          If (LogicTerm.CompCode And UseField) = UseField Then
          Begin
            Move(LogicTerm.CompOffset, ExtDBuffer^.Entire[Offset],
                 SizeOf(LogicTerm.CompOffset));
            Inc(Offset, SizeOf(LogicTerm.CompOffset));
          End Else
          Begin
            Move(LogicTerm.Value, ExtDBuffer^.Entire[Offset],
                 LogicTerm.FieldLen);
            Inc(Offset, LogicTerm.FieldLen);
          End;
        End;
      End;
    Begin
      FilterSpec^.ForEach(@MoveSingleFilterSpec);
    End;

    Procedure MoveExtractorSpecs;
      Procedure MoveSingleExtractorSpec(ExtSpec: PExtSpec); far;
      Begin
        With ExtSpec^ Do
        Begin
          Move(ExtSpec^.ExtRepeater, ExtDBuffer^.Entire[Offset],
               SizeOf(ExtSpec^.ExtRepeater));
          Inc(Offset, SizeOf(ExtSpec^));
        End;
      End;
    Begin
      ExtractorSpec^.ForEach(@MoveSingleExtractorSpec);
    End;

  Begin
    {Move header definition into buffer.}
    Move(Header, ExtDBuffer^.Header, SizeOf(Header));
    {Move fixed part of filter definition into buffer.}
    Move(Filter, ExtDBuffer^.Filter, SizeOf(Filter));
    Offset:=SizeOf(Header) + SizeOf(Filter) + 1;
    {Read filter logic terms into buffer.}
    MoveFilterSpecs;
    {Move fixed part of extractor definition into buffer.}
    Move(Extractor, ExtDBuffer^.Entire[Offset], SizeOf(Extractor.Entire));
    Inc(Offset, SizeOf(Extractor.Entire));
    {Move extractor terms into buffer.}
    MoveExtractorSpecs;
  End;

  { In overrides of this function in BFileExt descendants, MUST call  }
  { BFileExt.BTExt, as it sets the buffer length in the header, and   }
  { puts together the 'send' buffer.  User program MUST have inserted }
  { filter logic terms and extractor specs into their respective      }
  { collections before making a Btrieve call.                         }
  Function BFileExt.BTExt(OpCode, Key: integer): Integer;
  Begin
    SetExtDBufferLen;
    MakeExtDBuffer;
  End;


{___________________________________________________________________________}
{_ Procedures / Functions                                                  _}
{___________________________________________________________________________}

  { Assumes a PFILETYPE variable has been instantiated and assigned its    }
  { values. No specific support for null keys, alt col, blank compression, }
  { pre-alloc or data-only files.                                          }
  Function CreateFile(UserFileName: PChar; UserFileSpec:PFileSpec): Integer;
  Var
    CFSpecLength, I: Integer;
    BtrieveFileName: BFileName;
  Begin
    I:=StrLen(UserFileName);
    If I>79 Then I:=79;
    Move(UserFileName^, BtrieveFileName[1], I);
    BtrieveFileName[I+1]:=' ';
    CFSpecLength:=16 + (UserFileSpec^.NumKeys * 16);
    For I:=0 To 23 Do
      If (UserFileSpec^.KeyArray[I].KeyFlags And Segmented) = Segmented Then
        CFSpecLength := CFSpecLength + Segmented;
    UserFileSpec^.Reserved[1] := #0;
    UserFileSpec^.Reserved[2] := #0;
    CreateFile:=Btrv(BCreate, VarPosBlk, UserFileSpec^.SpecBuf, CFSpecLength,
                     BtrieveFileName, Zero);
  End;

  Function WBrqShellInit;             external 'WBTRCALL';
  Function WBtrvInit;                 external 'WBTRCALL';
  Procedure WBtrvStop;                external 'WBTRCALL';
  Function BtrCall;                   external 'WBTRCALL';

  {$IFDEF LOG}
  Procedure WriteBuffer(T: String; Var Buf; Size: Integer);
  Var
    Buffer: Array[0..16000] Of Byte absolute Buf;
    P, I: Integer;
    S: String[3];
  Begin
    Writeln(LogFile, T);
    P:=0;
    While P<Size Do
    Begin
      For I:=0 To 15 Do
        If P+I<Size Then Write(LogFile, Buffer[P+I]:4) Else Write(LogFile, '':4);
      Write(LogFile, '':4);
      For I:=0 To 15 Do
        If P+I<Size Then
        Begin
          If Buffer[P+I]>=32 Then
            Write(LogFile, Char(Buffer[P+I]))
          Else
            Write(LogFile, '.');
        End Else
          Write(LogFile, ' ');
      Writeln(LogFile);
      Inc(P, 16);
    End;      
  End;
  {$ENDIF}

  Function Btrv;
  Const KLen: Byte= 255;
  Begin
    {$IFDEF LOG}
    Append(LogFile);
    Writeln(LogFile, 'Op: ', Op);
    WriteBuffer('FCB:', FCB, 128);
    {WriteBuffer('Data:', Dat, Rec_Len);}
    Writeln(LogFile, 'Rec length: ', Rec_Len);
    {WriteBuffer('Key:', Key, KLen);}
    Writeln(LogFile, 'Key length: ', KLen);
    Writeln(LogFile, 'Key number: ', KeyNum);
    Close(LogFile);
    {$ENDIF}
    Btrv:=BtrCall(Op, FCB, Dat, Rec_Len, Key, KLen, Byte(KeyNum));
    {$IFDEF LOG}
    Append(LogFile);
    Writeln(LogFile, 'Ok');
    Writeln(LogFile);
    Close(LogFile);
    {$ENDIF}
  End;

  function BtpWinInit;
  begin
    BtpWinInit:=WBtrvInit(opStr);
    {$IFDEF LOG}
    Assign(LogFile, 'C:\BTPWIN.LOG');
    Rewrite(LogFile);
    Close(LogFile);
    {$ENDIF}
  end;

  Procedure BtpWinDone;
  Begin
    If ExtDBuffer<>nil Then Dispose(ExtDBuffer);
    WBtrvStop;
  End;

Begin
  ExtDBuffer:=nil;
End.
