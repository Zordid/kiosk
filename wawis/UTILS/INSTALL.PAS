program WAWISInstall;
uses WinProcs, WinCrt, Strings, Globals;

begin
  StrCopy(WindowTitle, 'WAWIS Installation');
  Writeln('****************************');
  Writeln('* W A W I S - Installation *');
  Writeln('****************************');
  Writeln;
  Writeln('Strg-C bricht Installation ab !');
  Writeln;
  Write('Benutzername: '); Readln(UserSettings.Name);
  Writeln;
  Write('Programmverzeichnis: '); Readln(ProgramPath);
  Write('Datenverzeichnis: '); Readln(Datapath);
  Write('Ordersatzverzeichnis: '); Readln(OSPath);
  Writeln;
  WritePrivateProfileString(pf_Paths, 'Daten', Datapath, ProfileFile);
  WritePrivateProfileString(pf_Paths, 'Programm',  Programpath, ProfileFile);
  WritePrivateProfileString(pf_Paths, 'Ordersätze', OSPath, ProfileFile);
  with UserSettings do
  begin
    DefaultWindowSize:=True;
    AutoDB:=True;
    DefaultArtikelSort:=1;
    DefaultArtikelEKSort:=1;
  end;
  SaveUserSettings;
  Writeln('WAWIS.INI ist eingerichtet worden. Sie können nun ein Icon im');
  Writeln('Programm-Manager anlegen und WAWIS starten.');
end.