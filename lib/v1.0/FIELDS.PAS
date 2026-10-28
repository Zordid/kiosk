{ Fields - input lines for Kiosk 1.0 and 1.2.                                }
{                                                                            }
{ Reconstructed in 2026: the original unit is lost. Kiosk 1.2B replaced it  }
{ with Borland's Fields demo unit plus a stub TRealInputLine; 1.0 and 1.2   }
{ still need the older one. Interface from the calls in MAKEREZ.PAS and     }
{ OSACTIVE.PAS of 1.0/1.2:                                                   }
{   TKeyInputLine   invalid while empty                                      }
{   TIntInputLine   LongInt between Min and Max (1.2B maps it to Borland's  }
{                   TNumInputLine, which works the same way)                 }
{   TRealInputLine  Real with a number of decimals, Min=Max=0: no limits    }
{   TDateInputLine  date as DD.MM.YY, data is a PDate; the Boolean of Init  }
{                   is taken to allow an empty field (nil)                   }
{ The object IDs are guesses that fit the later 1.2B unit (10060-10062).    }

{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S+,V-,X+}
Unit Fields;
Interface
  Uses Objects, Drivers, Views, Dialogs, MsgBox, DateUtl;

  Type
    PKeyInputLine= ^TKeyInputLine;
    TKeyInputLine= Object(TInputLine)
      Function Valid(Command: Word): Boolean; virtual;
    End;

    PIntInputLine= ^TIntInputLine;
    TIntInputLine= Object(TInputLine)
      Min, Max: LongInt;
      Constructor Init(Var Bounds: TRect; AMaxLen: Integer; AMin, AMax: LongInt);
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function DataSize: Word; virtual;
      Procedure GetData(Var Rec); virtual;
      Procedure SetData(Var Rec); virtual;
      Function Valid(Command: Word): Boolean; virtual;
    End;

    PRealInputLine= ^TRealInputLine;
    TRealInputLine= Object(TInputLine)
      Decimals: Integer;
      Min, Max: Real;
      Constructor Init(Var Bounds: TRect; AMaxLen, ADecimals: Integer; AMin, AMax: Real);
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function DataSize: Word; virtual;
      Procedure GetData(Var Rec); virtual;
      Procedure SetData(Var Rec); virtual;
      Function Valid(Command: Word): Boolean; virtual;
    End;

    PDateInputLine= ^TDateInputLine;
    TDateInputLine= Object(TInputLine)
      AllowEmpty: Boolean;
      Constructor Init(Var Bounds: TRect; AAllowEmpty: Boolean);
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function DataSize: Word; virtual;
      Procedure GetData(Var Rec); virtual;
      Procedure SetData(Var Rec); virtual;
      Function Valid(Command: Word): Boolean; virtual;
    End;

  Const
    RKeyInputLine: TStreamRec= (
      ObjType: 10060;
      VmtLink: Ofs(TypeOf(TKeyInputLine)^);
      Load:    @TKeyInputLine.Load;
      Store:   @TKeyInputLine.Store
    );
    RIntInputLine: TStreamRec= (
      ObjType: 10061;
      VmtLink: Ofs(TypeOf(TIntInputLine)^);
      Load:    @TIntInputLine.Load;
      Store:   @TIntInputLine.Store
    );
    RRealInputLine: TStreamRec= (
      ObjType: 10062;
      VmtLink: Ofs(TypeOf(TRealInputLine)^);
      Load:    @TRealInputLine.Load;
      Store:   @TRealInputLine.Store
    );
    RDateInputLine: TStreamRec= (
      ObjType: 10063;
      VmtLink: Ofs(TypeOf(TDateInputLine)^);
      Load:    @TDateInputLine.Load;
      Store:   @TDateInputLine.Store
    );

  Procedure RegisterFields;

Implementation

  Function Refuse(Msg: String; Line: PInputLine): Boolean;
  Begin
    MessageBox(Msg, nil, mfError+mfOkButton);
    Line^.Select;
    Refuse:=False;
  End;

{== TKeyInputLine ===========================================================}

  Function TKeyInputLine.Valid(Command: Word): Boolean;
  Begin
    Valid:=True;
    If (Command<>cmCancel) And (Command<>cmValid) And (Data^='') Then
      Valid:=Refuse('Dieses Feld darf nicht leer sein.', @Self);
  End;

{== TIntInputLine ===========================================================}

  Constructor TIntInputLine.Init(Var Bounds: TRect; AMaxLen: Integer; AMin, AMax: LongInt);
  Begin
    TInputLine.Init(Bounds, AMaxLen);
    Min:=AMin;
    Max:=AMax;
  End;

  Constructor TIntInputLine.Load(Var S: TStream);
  Begin
    TInputLine.Load(S);
    S.Read(Min, 2*SizeOf(LongInt));
  End;

  Procedure TIntInputLine.Store(Var S: TStream);
  Begin
    TInputLine.Store(S);
    S.Write(Min, 2*SizeOf(LongInt));
  End;

  Function TIntInputLine.DataSize: Word;
  Begin
    DataSize:=SizeOf(LongInt);
  End;

  Procedure TIntInputLine.GetData(Var Rec);
  Var Code: Integer;
  Begin
    Val(Data^, LongInt(Rec), Code);
    If Code<>0 Then LongInt(Rec):=0;
  End;

  Procedure TIntInputLine.SetData(Var Rec);
  Var S: String[12];
  Begin
    Str(LongInt(Rec), S);
    TInputLine.SetData(S);
    SelectAll(True);
  End;

  Function TIntInputLine.Valid(Command: Word): Boolean;
  Var
    L: LongInt;
    Code: Integer;
    S1, S2: String[12];
  Begin
    Valid:=True;
    If (Command=cmCancel) Or (Command=cmValid) Then Exit;
    If Data^='' Then Data^:='0';
    Val(Data^, L, Code);
    If (Code<>0) Or (L<Min) Or (L>Max) Then
    Begin
      Str(Min, S1);
      Str(Max, S2);
      Valid:=Refuse('Bitte eine Zahl von '+S1+' bis '+S2+' eingeben.', @Self);
    End;
  End;

{== TRealInputLine ==========================================================}

  Constructor TRealInputLine.Init(Var Bounds: TRect; AMaxLen, ADecimals: Integer; AMin, AMax: Real);
  Begin
    TInputLine.Init(Bounds, AMaxLen);
    Decimals:=ADecimals;
    Min:=AMin;
    Max:=AMax;
  End;

  Constructor TRealInputLine.Load(Var S: TStream);
  Begin
    TInputLine.Load(S);
    S.Read(Decimals, SizeOf(Integer)+2*SizeOf(Real));
  End;

  Procedure TRealInputLine.Store(Var S: TStream);
  Begin
    TInputLine.Store(S);
    S.Write(Decimals, SizeOf(Integer)+2*SizeOf(Real));
  End;

  Function TRealInputLine.DataSize: Word;
  Begin
    DataSize:=SizeOf(Real);
  End;

  Function ToReal(S: String; Var R: Real): Boolean;
  Var
    I: Byte;
    Code: Integer;
  Begin
    For I:=1 To Length(S) Do
      If S[I]=',' Then S[I]:='.';
    While (S<>'') And (S[1]=' ') Do Delete(S, 1, 1);
    If S='' Then S:='0';
    Val(S, R, Code);
    ToReal:=Code=0;
  End;

  Procedure TRealInputLine.GetData(Var Rec);
  Begin
    If Not ToReal(Data^, Real(Rec)) Then Real(Rec):=0;
  End;

  Procedure TRealInputLine.SetData(Var Rec);
  Var
    S: String;
    I: Byte;
  Begin
    Str(Real(Rec):0:Decimals, S);
    For I:=1 To Length(S) Do
      If S[I]='.' Then S[I]:=',';
    If Length(S)>MaxLen Then S[0]:=Chr(MaxLen);
    TInputLine.SetData(S);
    SelectAll(True);
  End;

  Function TRealInputLine.Valid(Command: Word): Boolean;
  Var R: Real;
  Begin
    Valid:=True;
    If (Command=cmCancel) Or (Command=cmValid) Then Exit;
    If Not ToReal(Data^, R) Then
      Valid:=Refuse('Bitte eine Zahl eingeben.', @Self)
    Else
      If ((Min<>0) Or (Max<>0)) And ((R<Min) Or (R>Max)) Then
        Valid:=Refuse('Die Zahl liegt nicht im erlaubten Bereich.', @Self);
  End;

{== TDateInputLine ==========================================================}

  Constructor TDateInputLine.Init(Var Bounds: TRect; AAllowEmpty: Boolean);
  Begin
    TInputLine.Init(Bounds, 8);
    AllowEmpty:=AAllowEmpty;
  End;

  Constructor TDateInputLine.Load(Var S: TStream);
  Begin
    TInputLine.Load(S);
    S.Read(AllowEmpty, SizeOf(Boolean));
  End;

  Procedure TDateInputLine.Store(Var S: TStream);
  Begin
    TInputLine.Store(S);
    S.Write(AllowEmpty, SizeOf(Boolean));
  End;

  Function TDateInputLine.DataSize: Word;
  Begin
    DataSize:=SizeOf(PDate);
  End;

  Procedure TDateInputLine.GetData(Var Rec);
  Var D: TDate;
  Begin
    If Data^='' Then
    Begin
      If PDate(Rec)<>nil Then Dispose(PDate(Rec), Done);
      PDate(Rec):=nil;
    End Else
    Begin
      D.InitToday;
      If D.SetStrDate(Data^) Then
        If PDate(Rec)=nil Then
          PDate(Rec):=New(PDate, InitTDate(D))
        Else
          PDate(Rec)^.InitTDate(D);
    End;
  End;

  Procedure TDateInputLine.SetData(Var Rec);
  Var S: String[8];
  Begin
    If PDate(Rec)<>nil Then S:=PDate(Rec)^.GetStrDate Else S:='';
    TInputLine.SetData(S);
    SelectAll(True);
  End;

  Function TDateInputLine.Valid(Command: Word): Boolean;
  Var D: TDate;
  Begin
    Valid:=True;
    If (Command=cmCancel) Or (Command=cmValid) Then Exit;
    D.InitToday;
    If Data^='' Then
    Begin
      If Not AllowEmpty Then
        Valid:=Refuse('Bitte ein Datum eingeben.', @Self);
    End Else
      If Not D.SetStrDate(Data^) Then
        Valid:=Refuse('Bitte ein korrektes Datum angeben (TT.MM.JJ).', @Self);
  End;

  Procedure RegisterFields;
  Begin
    RegisterType(RKeyInputLine);
    RegisterType(RIntInputLine);
    RegisterType(RRealInputLine);
    RegisterType(RDateInputLine);
  End;

End.
