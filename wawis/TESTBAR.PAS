program TestBarCode;
uses
  WinTypes, WinProcs, WinCrt, Win31, BarCodes;

var
  S: array[0..30] of Char;
  B: TBarCode;
  DC: HDC;
  DocInfo: TDocInfo;
  y: Integer;

begin
  Writeln('BarCode-Printer');
  y:=50;
  DC:=CreateDC('JP350', 'Olivetti JP 350S', 'LPT1:', nil);
  DocInfo.cbSize:=SizeOf(DocInfo);
  DocInfo.lpszDocName:='BarCodes';
  DocInfo.lpszOutput:=nil;
  StartDoc(DC, DocInfo);
  StartPage(DC);
  repeat
    Write('Code: '); Readln(S);
    B.Init(S);
    case B.Typ of
      EAN8: Writeln('EAN-8');
      EAN13: Writeln('EAN-13');
      else Writeln('unbekannt');
    end;
    B.Draw(DC, 50, y, 4, 75);
    Inc(y, 100);
  until S[0]=#0;
  EndPage(DC);
  EndDoc(DC);
  DeleteDC(DC);
end.