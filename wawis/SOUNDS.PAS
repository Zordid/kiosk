unit Sounds;
interface
  uses
    WinTypes, WinProcs, MMSystem, Globals;

  procedure PlaySnd(Snd: PChar);
  procedure PlaySndFehler;

implementation

  procedure PlaySnd;
  var acFile: array[0..100] of Char;
  begin
    if GetPrivateProfileString(pf_Sounds, Snd, nil, acFile, SizeOf(acFile), ProfileFile)>0 then
    begin
      SndPlaySound(ProgramPathFile(acFile), snd_ASync or snd_NoStop);
    end;
  end;

  procedure PlaySndFehler;
  var acFile: array[0..100] of Char;
  begin
    if GetPrivateProfileString(pf_Sounds, 'Fehler', nil, acFile, SizeOf(acFile), ProfileFile)>0 then
      SndPlaySound(ProgramPathFile(acFile), snd_ASync or snd_NoStop)
    else
      MessageBeep(0);
  end;

end.