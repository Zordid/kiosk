{ DosTools - file helpers.                                                   }
{                                                                            }
{ Reconstructed in 2026: the original unit is lost. Names and parameters    }
{ follow the calls in Kiosk 1.0-1.2C and Power-Choice 3.x; the bodies are   }
{ new.                                                                       }

{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S+,V-,X+}
Unit DosTools;
Interface

  Function FileExists(N: String): Boolean;
  Procedure FileDelete(N: String);
  Procedure FileRename(OldName, NewName: String);
  Function FileName(N: String): String;

Implementation
  Uses Dos;

  Function FileExists(N: String): Boolean;
  Var SR: SearchRec;
  Begin
    FindFirst(N, ReadOnly+Hidden+SysFile+Archive, SR);
    FileExists:=DosError=0;
  End;

  Procedure FileDelete(N: String);
  Var F: File;
  Begin
    Assign(F, N);
    Erase(F);
    If IOResult<>0 Then;
  End;

  Procedure FileRename(OldName, NewName: String);
  Var F: File;
  Begin
    Assign(F, OldName);
    Rename(F, NewName);
    If IOResult<>0 Then;
  End;

  Function FileName(N: String): String;
  Var
    D: DirStr;
    Nm: NameStr;
    E: ExtStr;
  Begin
    FSplit(N, D, Nm, E);
    FileName:=Nm+E;
  End;

End.
