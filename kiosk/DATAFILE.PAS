{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S+,V-,X+}
Unit Datafile;
Interface

  Type
    PRecordBuffer= ^LongInt;

    PDataFile= ^TDataFile;
    TDataFile= Record
      F: File;
      FirstFree,
      NumberFree: LongInt;
      ItemSize: Word;
      NumRecs: LongInt;
      RecBuf: PRecordBuffer;
    End;

  Var
    OK: Boolean;

  Procedure FlushDosFile(Var F: File);
  Function ExistDosFile(N: String): Boolean;

  Procedure OpenFile(Var D: TDataFile; N: String; Size: Word);
  Procedure CreateFile(Var D: TDataFile; N: String; Size: Word);
  Procedure CloseFile(Var D: TDataFile);
  Procedure FlushFile(Var D: TDataFile);

  Procedure PutRec(Var D: TDataFile; R: LongInt; Var Data);
  Procedure GetRec(Var D: TDataFile; R: LongInt; Var Data);

  Procedure AddRec(Var D: TDataFile; Var R: LongInt; Var Data);
  Procedure DeleteRec(Var D: TDataFile; Var R: LongInt);

  Function FileLen(Var D: TDataFile): LongInt;
  Function UsedRecs(Var D: TDataFile): LongInt;

Implementation
  Uses Dos;

  Type
    PInfoRec= ^TInfoRec;
    TInfoRec= Record
      FirstFree, NumberFree: LongInt;
      ItemSize: Word;
    End;
  Const
    FileHeaderSize= SizeOf(TInfoRec);

  Procedure ReadHeader(Var D: TDataFile);
  Begin
    Seek(D.F, 0);
    BlockRead(D.F, D.RecBuf^, 1);
    Move(D.RecBuf^, D.FirstFree, FileHeaderSize);
    D.NumRecs:=FileSize(D.F);
  End;

  Procedure PutHeader(Var D: TDataFile);
  Begin
    FillChar(D.RecBuf^, D.ItemSize, 0);
    Move(D.FirstFree, D.RecBuf^, FileHeaderSize);
    Seek(D.F, 0);
    BlockWrite(D.F, D.RecBuf^, 1);
  End;

  Procedure OpenFile(Var D: TDataFile; N: String; Size: Word);
  Begin
    OK:=False;
    If Size<FileHeaderSize Then Exit;
    Assign(D.F, N);
    Reset(D.F, Size);
    If IOResult=0 Then
    Begin
      GetMem(D.RecBuf, Size);
      ReadHeader(D);
      OK:=(D.ItemSize=Size) And (IOResult=0);
    End;
  End;

  Procedure CreateFile(Var D: TDataFile; N: String; Size: Word);
  Begin
    OK:=False;
    If Size<SizeOf(TInfoRec) Then Exit;
    Assign(D.F, N);
    Rewrite(D.F, Size);
    If IOResult=0 Then With D Do
    Begin
      GetMem(D.RecBuf, Size);
      ItemSize:=Size;
      FirstFree:=-1;
      NumberFree:=0;
      NumRecs:=1;
      PutHeader(D);
      OK:=IOResult=0;
    End;
  End;

  Procedure PutRec(Var D: TDataFile; R: LongInt; Var Data);
  Begin
    Seek(D.F, R);
    BlockWrite(D.F, Data, 1);
  End;

  Procedure GetRec(Var D: TDataFile; R: LongInt; Var Data);
  Begin
    Seek(D.F, R);
    BlockRead(D.F, Data, 1);
  End;

  Procedure NewRec(Var D: TDataFile; Var R: LongInt);
  Begin
    If (D.FirstFree=-1) Or (D.NumberFree=0) Then
    Begin
      D.FirstFree:=-1;
      R:=D.NumRecs;
      Inc(D.NumRecs);
    End Else
    Begin
      R:=D.FirstFree;
      GetRec(D, R, D.RecBuf^);
      D.FirstFree:=D.RecBuf^;
      Dec(D.NumberFree);
    End;
  End;

  Procedure AddRec(Var D: TDataFile; Var R: LongInt; Var Data);
  Begin
    NewRec(D, R);
    PutRec(D, R, Data);
  End;

  Procedure DeleteRec(Var D: TDataFile; Var R: LongInt);
  Begin
    D.RecBuf^:=D.FirstFree;
    PutRec(D, R, D.RecBuf^);
    D.FirstFree:=R;
    Inc(D.NumberFree);
  End;

  Procedure CloseFile(Var D: TDataFile);
  Begin
    PutHeader(D);
    Close(D.F);
    FreeMem(D.RecBuf, D.ItemSize);
  End;

  Function FileLen(Var D: TDataFile): LongInt;
  Begin
    FileLen:=D.NumRecs;
  End;

  Function UsedRecs(Var D: TDataFile): LongInt;
  Begin
    UsedRecs:=D.NumRecs-D.NumberFree-1;
  End;

  Function DupHandle(Handle: Word): Word; assembler;
  Asm
    Mov AH, $45
    Mov BX, Handle
    Int $21
  End;

  Procedure CloseFileHandle(Handle: Word); assembler;
  Asm
    Mov AH, $3E
    Mov BX, Handle
    Int $21
  End;

  Procedure FlushDOSFile(Var F: File);
  Var
    CloneHandle : Word;
  Begin
    CloneHandle := DupHandle(FileRec(F).Handle);
    CloseFileHandle (CloneHandle);
  End;  { FlushDOSFile }

  Procedure FlushFile(Var D: TDataFile);
  Begin
    PutHeader(D);
    FlushDOSFile(D.F);
  End; { FlushFile }

  Function ExistDosFile;
  Var F: File;
  Begin
    Assign(F, N);
    Reset(F);
    Close(F);
    ExistDosFile:=IOResult=0;
  End;

End.