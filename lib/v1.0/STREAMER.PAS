{ StreamEr - report stream errors (used by MAKEREZ of Kiosk 1.0).            }
{                                                                            }
{ Reconstructed in 2026: the original unit is lost. MAKEREZ only names it   }
{ in its uses clause; judging by the name it reported errors while the      }
{ resource file was written. This stand-in hooks Turbo Vision's StreamError }
{ and prints the stream status.                                              }

{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S+,V-,X+}
Unit StreamEr;
Interface

Implementation
  Uses Objects;

  {$F+}
  Procedure ReportStreamError(Var S: TStream);
  Begin
    Write('Stream-Fehler ', S.Status);
    If S.ErrorInfo<>0 Then Write(' (', S.ErrorInfo, ')');
    Writeln;
  End;
  {$F-}

Begin
  StreamError:=@ReportStreamError;
End.
