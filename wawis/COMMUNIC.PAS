{$I-}
unit Communication;
interface
  uses
    Objects, WinTypes, WinProcs, Strings, CommDlg,
    Globals;

  type
    TExportColl= object(TCollection)
      Size: LongInt;
      constructor Init(Len: Integer);
      procedure FreeItem(Item: Pointer); virtual;
      procedure InsertStr(S: PChar);
      { output functions }
      function SendToClipboard(Oem: Boolean): Boolean;
      function SendToFile(FileName: PChar): Boolean;
      function SendToPrinter: Boolean;
    end;

implementation

  function CreatePrinterDC: HDC;
  var
    Printer: array[0..80] of Char;
    Device, Driver, Port: PChar;
  begin
    CreatePrinterDC:=0;
    if GetProfileString('windows', 'device', nil, Printer, SizeOf(Printer))=0 then Exit;
    Device:=StrTok(Printer, ',');
    Driver:=StrTok(nil, ',');
    Port:=StrTok(nil, ',');
    CreatePrinterDC:=CreateDC(Driver, Device, Port, nil);
  end;

{ TExportColl object }
  constructor TExportColl.Init(Len: Integer);
  begin
    TCollection.Init(Len, 100);
    Size:=0;
  end; 

  procedure TExportColl.FreeItem(Item: Pointer);
  begin
    StrDispose(Item);
  end;

  procedure TExportColl.InsertStr(S: PChar);
  var P: PChar;
  begin
    Inc(Size, StrLen(S));
    Insert(StrNew(S));
  end;

  function TExportColl.SendToFile(FileName: PChar): Boolean;
  var
    T: Text;
    I: Integer;
  begin
    SendToFile:=False;
    if Count>0 then
    begin
      Assign(T, FileName);
      Rewrite(T);
      if IOResult<>0 then Exit; 
      for I:=0 to Count-1 do
      begin
        Writeln(T, PChar(At(I)));
        if IOResult<>0 then
        begin
          Close(T);
          Erase(T);
          Exit;
        end;
      end;
      Close(T);
    end;
    SendToFile:=IOResult=0;
  end;

  function TExportColl.SendToClipboard(Oem: Boolean): Boolean;
  var
    GlbHandle: THandle;
    GlbPtr: PByte;
    P: PChar;
    I, J: Word;
  begin
    if Count>0 then
    begin
      GlbHandle:=GlobalAlloc(gmem_Moveable, Size+1);
      if GlbHandle<>0 then
      begin
        GlbPtr:=GlobalLock(GlbHandle);
        if GlbPtr<>nil then
        begin
          for I:=0 to Count-1 do
          begin
            P:=PChar(At(I));
            if P<>nil then
            begin
              J:=0;
              while P[J]<>#0 do
              begin
                GlbPtr^:=Byte(P[J]);
                Inc(LongRec(GlbPtr).Lo);
                { Selector Tiling }
                if Ofs(GlbPtr^)=0 then Inc(LongRec(GlbPtr).Hi, 8);
                Inc(J);
              end;
            end;
          end;
          GlbPtr^:=0;
          GlobalUnlock(GlbHandle);
          if Oem then
            SetClipboardData(cf_OemText, GlbHandle)
          else
            SetClipboardData(cf_Text, GlbHandle);  
        end else
          GlobalFree(GlbHandle);
      end;
    end;
    SendToClipboard:=True;
  end;

  function TExportColl.SendToPrinter;
  var
    L: TLogFont;
    CF: TChooseFont;
    hdcPrn: HDC;
  begin
    hdcPrn:=CreatePrinterDC;
    FillChar(CF, SizeOf(CF), 0);
    with CF do
    begin
      lStructSize := SizeOf(CF);
      hInstance   := System.hInstance;
      hwndOwner   := hMainWindow;
      lpLogFont   := @L;
      Flags       := cf_PrinterFonts or cf_FixedPitchOnly;
      hdc         := hdcPrn;
    end;
    ChooseFont(CF);
    DeleteDC(hdcPrn);
  end;

end.