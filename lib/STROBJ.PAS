{ StrObj - a string on the heap as a Turbo Vision object.                    }
{                                                                            }
{ Reconstructed in 2026: the original unit is lost. Its interface follows   }
{ the way Kiosk 1.0-1.2C and Power-Choice 3.x use it, and the stream format }
{ matches the Kiosk data files of 1992/93 (VMT word, then the string as     }
{ written by TStream.WriteStr). Object ID 1000 comes from Power-Choice's    }
{ OBJID.TXT.                                                                 }

{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S+,V-,X+}
Unit StrObj;
Interface
  Uses Objects;

  Type
    PStr= ^TStr;
    TStr= Object(TObject)
      P: PString;
      Constructor Init(S: String);
      Constructor Load(Var S: TStream);
      Destructor Done; virtual;
      Procedure Store(Var S: TStream);
      Procedure SetStr(S: String);
      Function GetStr: String;
      Function GetPtr: PString;
    End;

  Const
    RStr: TStreamRec= (
      ObjType: 1000;
      VmtLink: Ofs(TypeOf(TStr)^);
      Load:    @TStr.Load;
      Store:   @TStr.Store
    );

Implementation

  Const
    EmptyStr: String[1]= '';

  Constructor TStr.Init(S: String);
  Begin
    TObject.Init;
    P:=NewStr(S);
  End;

  Constructor TStr.Load(Var S: TStream);
  Begin
    P:=S.ReadStr;
  End;

  Destructor TStr.Done;
  Begin
    DisposeStr(P);
    P:=nil;
    TObject.Done;
  End;

  Procedure TStr.Store(Var S: TStream);
  Begin
    S.WriteStr(P);
  End;

  Procedure TStr.SetStr(S: String);
  Begin
    DisposeStr(P);
    P:=NewStr(S);
  End;

  Function TStr.GetStr: String;
  Begin
    If P<>nil Then GetStr:=P^ Else GetStr:='';
  End;

  Function TStr.GetPtr: PString;
  Begin
    If P<>nil Then GetPtr:=P Else GetPtr:=@EmptyStr;
  End;

End.
