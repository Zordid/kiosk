{ DateUtl - date and time objects.                                           }
{                                                                            }
{ Reconstructed in 2026: the original unit is lost. The interface follows   }
{ the calls in Kiosk 1.0-1.2C and Power-Choice 3.x. The stream format       }
{ matches the Kiosk data files of 1992/93: TDate is Day, Month, Year and    }
{ TTime is Hour, Minute, Second, all as Words. Object ID 1001 for TDate     }
{ comes from Power-Choice's OBJID.TXT.                                       }

{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S+,V-,X+}
Unit DateUtl;
Interface
  Uses Objects;

  Const
    { Parts for TTime.GetStrTime }
    tHour=   $01;
    tMinute= $02;
    tSecond= $04;

  Type
    PDate= ^TDate;
    TDate= Object(TObject)
      Day, Month, Year: Word;
      Constructor InitToday;
      Constructor InitDate(D, M, Y: Word);
      Constructor InitTDate(Var D: TDate);
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function GetStrDate: String;
      Function SetStrDate(S: String): Boolean;
      Function DayNumber: LongInt;
      Function DaysLeftTill(Var D: TDate): LongInt;
    End;

    PTime= ^TTime;
    TTime= Object(TObject)
      Hour, Minute, Second: Word;
      Constructor InitNow;
      Constructor InitTTime(Var T: TTime);
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function GetHour: Word;
      Function GetMinute: Word;
      Function GetSecond: Word;
      Function GetStrTime(Sep: Char; Parts: Byte): String;
    End;

  Const
    RDate: TStreamRec= (
      ObjType: 1001;
      VmtLink: Ofs(TypeOf(TDate)^);
      Load:    @TDate.Load;
      Store:   @TDate.Store
    );

  Var
    Today: TDate;

  Function ValidDate(D, M, Y: Word): Boolean;

Implementation
  Uses Dos;

  Const
    DaysInMonth: Array[1..12] Of Byte= (31,28,31,30,31,30,31,31,30,31,30,31);

  Function LeapYear(Y: Word): Boolean;
  Begin
    LeapYear:=((Y Mod 4=0) And (Y Mod 100<>0)) Or (Y Mod 400=0);
  End;

  Function ValidDate(D, M, Y: Word): Boolean;
  Var Max: Byte;
  Begin
    ValidDate:=False;
    If (M<1) Or (M>12) Or (D<1) Or (Y<1) Then Exit;
    Max:=DaysInMonth[M];
    If (M=2) And LeapYear(Y) Then Inc(Max);
    ValidDate:=D<=Max;
  End;

  Function Two(W: Word): String;
  Var S: String[5];
  Begin
    Str(W:2, S);
    If S[1]=' ' Then S[1]:='0';
    Two:=S;
  End;

{== TDate ===================================================================}

  Constructor TDate.InitToday;
  Var DoW: Word;
  Begin
    TObject.Init;
    GetDate(Year, Month, Day, DoW);
  End;

  Constructor TDate.InitDate(D, M, Y: Word);
  Begin
    TObject.Init;
    Day:=D;
    Month:=M;
    Year:=Y;
  End;

  Constructor TDate.InitTDate(Var D: TDate);
  Begin
    TObject.Init;
    Day:=D.Day;
    Month:=D.Month;
    Year:=D.Year;
  End;

  Constructor TDate.Load(Var S: TStream);
  Begin
    S.Read(Day, 3*SizeOf(Word));
  End;

  Procedure TDate.Store(Var S: TStream);
  Begin
    S.Write(Day, 3*SizeOf(Word));
  End;

  Function TDate.GetStrDate: String;
  Begin
    GetStrDate:=Two(Day)+'.'+Two(Month)+'.'+Two(Year Mod 100);
  End;

  Function TDate.SetStrDate(S: String): Boolean;
  Var
    V: Array[1..3] Of Word;
    I, N, P: Byte;
    Code: Integer;
  Begin
    SetStrDate:=False;
    V[3]:=Year;
    N:=0;
    While (S<>'') And (N<3) Do
    Begin
      P:=Pos('.', S);
      If P=0 Then P:=Length(S)+1;
      Inc(N);
      Val(Copy(S, 1, P-1), V[N], Code);
      If Code<>0 Then Exit;
      Delete(S, 1, P);
    End;
    If (N<2) Or (S<>'') Then Exit;
    If V[3]<100 Then
      If V[3]<80 Then Inc(V[3], 2000) Else Inc(V[3], 1900);
    If Not ValidDate(V[1], V[2], V[3]) Then Exit;
    Day:=V[1];
    Month:=V[2];
    Year:=V[3];
    SetStrDate:=True;
  End;

  Function TDate.DayNumber: LongInt;
  Var
    Y, M: LongInt;
  Begin
    { days since 1 March of year 0, Gregorian calendar }
    Y:=Year;
    M:=Month;
    If M<3 Then
    Begin
      Dec(Y);
      Inc(M, 12);
    End;
    DayNumber:=365*Y+Y Div 4-Y Div 100+Y Div 400+(153*(M-3)+2) Div 5+Day-1;
  End;

  Function TDate.DaysLeftTill(Var D: TDate): LongInt;
  Begin
    DaysLeftTill:=D.DayNumber-DayNumber;
  End;

{== TTime ===================================================================}

  Constructor TTime.InitNow;
  Var Sec100: Word;
  Begin
    TObject.Init;
    GetTime(Hour, Minute, Second, Sec100);
  End;

  Constructor TTime.InitTTime(Var T: TTime);
  Begin
    TObject.Init;
    Hour:=T.Hour;
    Minute:=T.Minute;
    Second:=T.Second;
  End;

  Constructor TTime.Load(Var S: TStream);
  Begin
    S.Read(Hour, 3*SizeOf(Word));
  End;

  Procedure TTime.Store(Var S: TStream);
  Begin
    S.Write(Hour, 3*SizeOf(Word));
  End;

  Function TTime.GetHour: Word;
  Begin
    GetHour:=Hour;
  End;

  Function TTime.GetMinute: Word;
  Begin
    GetMinute:=Minute;
  End;

  Function TTime.GetSecond: Word;
  Begin
    GetSecond:=Second;
  End;

  Function TTime.GetStrTime(Sep: Char; Parts: Byte): String;
  Var S: String[12];
  Begin
    S:='';
    If Parts And tHour<>0 Then S:=Two(Hour);
    If Parts And tMinute<>0 Then
    Begin
      If S<>'' Then S:=S+Sep;
      S:=S+Two(Minute);
    End;
    If Parts And tSecond<>0 Then
    Begin
      If S<>'' Then S:=S+Sep;
      S:=S+Two(Second);
    End;
    GetStrTime:=S;
  End;

Begin
  Today.InitToday;
End.
