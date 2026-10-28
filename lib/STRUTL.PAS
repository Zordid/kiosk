{ StrUtl - string helpers.                                                   }
{                                                                            }
{ Reconstructed in 2026: the original unit is lost. Names and parameters    }
{ follow the calls in Kiosk 1.0-1.2C and Power-Choice 3.x; the bodies are   }
{ new. The ...G routines know the German umlauts of code page 437.          }

{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S+,V-,X+}
Unit StrUtl;
Interface

  Procedure StrMove(Var Dest: String; Source: String);
  Procedure StrCat(Var S: String; T: String; Max: Byte);
  Procedure StrIns(Var S: String; T: String; Pos, Max: Byte);
  Procedure StrCut(Var S: String; Len: Byte);
  Procedure ChrCat(Var S: String; C: Char);
  Procedure ChrDel(Var S: String; C: Char);
  Procedure ChrDelL(Var S: String; C: Char);
  Function ChrPosL(S: String; C: Char; Start: Byte): Byte;
  Function StrEqu(S1, S2: String): Boolean;
  Function UpCaseG(C: Char): Char;
  Procedure StrUpr(Var S: String);
  Procedure StrUprG(Var S: String);

Implementation

  Procedure StrMove(Var Dest: String; Source: String);
  Begin
    Move(Source, Dest, Length(Source)+1);
  End;

  Procedure StrCat(Var S: String; T: String; Max: Byte);
  Var L: Byte;
  Begin
    L:=Length(T);
    If Length(S)+L>Max Then
      If Length(S)>=Max Then L:=0 Else L:=Max-Length(S);
    Move(T[1], S[Length(S)+1], L);
    Inc(S[0], L);
  End;

  Procedure StrIns(Var S: String; T: String; Pos, Max: Byte);
  Var U: String;
  Begin
    U:=S;
    Insert(T, U, Pos);
    If Length(U)>Max Then U[0]:=Chr(Max);
    StrMove(S, U);
  End;

  Procedure StrCut(Var S: String; Len: Byte);
  Begin
    If Length(S)>Len Then S[0]:=Chr(Len);
  End;

  Procedure ChrCat(Var S: String; C: Char);
  Begin
    If Length(S)<255 Then
    Begin
      Inc(S[0]);
      S[Length(S)]:=C;
    End;
  End;

  Procedure ChrDel(Var S: String; C: Char);
  Var I, J: Byte;
  Begin
    J:=0;
    For I:=1 To Length(S) Do
      If S[I]<>C Then
      Begin
        Inc(J);
        S[J]:=S[I];
      End;
    S[0]:=Chr(J);
  End;

  Procedure ChrDelL(Var S: String; C: Char);
  Var I: Byte;
  Begin
    I:=0;
    While (I<Length(S)) And (S[I+1]=C) Do Inc(I);
    If I>0 Then Delete(S, 1, I);
  End;

  Function ChrPosL(S: String; C: Char; Start: Byte): Byte;
  Var I: Byte;
  Begin
    ChrPosL:=0;
    If Start=0 Then Start:=1;
    For I:=Start To Length(S) Do
      If S[I]=C Then
      Begin
        ChrPosL:=I;
        Exit;
      End;
  End;

  Function StrEqu(S1, S2: String): Boolean;
  Begin
    StrEqu:=S1=S2;
  End;

  Function UpCaseG(C: Char): Char;
  Begin
    Case C Of
      #132: UpCaseG:=#142;  { ae }
      #148: UpCaseG:=#153;  { oe }
      #129: UpCaseG:=#154;  { ue }
    Else
      UpCaseG:=UpCase(C);
    End;
  End;

  Procedure StrUpr(Var S: String);
  Var I: Byte;
  Begin
    For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
  End;

  Procedure StrUprG(Var S: String);
  Var I: Byte;
  Begin
    For I:=1 To Length(S) Do S[I]:=UpCaseG(S[I]);
  End;

End.
