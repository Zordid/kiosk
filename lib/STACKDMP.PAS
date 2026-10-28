{ StackDmp - report where a program stopped with a runtime error.            }
{                                                                            }
{ Reconstructed in 2026: the original unit is lost. Kiosk only names it in  }
{ its uses clause; judging by the name it dumped the stack after a runtime  }
{ error. This stand-in installs an exit procedure that leaves text mode     }
{ and writes the error code and address to KIOSK.ERR.                       }

{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S+,V-,X+}
Unit StackDmp;
Interface

Implementation

  Var
    OldExitProc: Pointer;

  Function Hex(W: Word): String;
  Const Digits: Array[0..15] Of Char= '0123456789ABCDEF';
  Begin
    Hex:=Digits[Hi(W) Shr 4]+Digits[Hi(W) And 15]+
      Digits[Lo(W) Shr 4]+Digits[Lo(W) And 15];
  End;

  {$F+}
  Procedure DumpExit;
  Var T: Text;
  Begin
    ExitProc:=OldExitProc;
    If ErrorAddr<>nil Then
    Begin
      Assign(T, 'KIOSK.ERR');
      Rewrite(T);
      If IOResult=0 Then
      Begin
        Writeln(T, 'Runtime error ', ExitCode, ' at ',
          Hex(Seg(ErrorAddr^)), ':', Hex(Ofs(ErrorAddr^)));
        Close(T);
      End;
    End;
  End;
  {$F-}

Begin
  OldExitProc:=ExitProc;
  ExitProc:=@DumpExit;
End.
