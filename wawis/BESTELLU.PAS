unit Bestellungen;
interface
  uses
    Objects, OWindows, ODialogs,
    WinTypes, WinProcs, WinDos, SWinPrn, Strings, CommDlg,
    Globals, Barcodes, Dialogs, Artikel, Betriebe, Lieferanten, Einkauf,
    Ordersatz, Sounds;

  procedure Bestellung;

implementation
  const
    TabsContents: array[0..1] of Integer= (0, 150);

  type
    PBestellArtikel= ^TBestellArtikel;
    TBestellArtikel= object(TObject)
      ArtikelNr: LongInt;
      ArtikelEKNr: LongInt;
      { Artikeldaten }
      Name: PChar;
      Warengruppe: Byte;
      EVArt: PChar;
      EVInhalt: PChar;
      MwSt: Single;
      ChangeRev: Byte;
      { Artikel-EK-Daten }
      LieferantenNr: LongInt;
      EANCode: PChar;
      UVMenge: Integer;
      UVPreis: Single;
      { neue Daten }
      Count: Word;
      constructor Init(AnArtikelEK: LongInt; ACount: Word);
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
      destructor Done; virtual;
      procedure GetString(P: PChar);
      procedure GetPrintString(P: PChar; Nr, Line: Integer);
    end;

    PBestellung= ^TBestellung;
    PBestellungIdx= ^TBestellungIdx;
    TBestellungIdx= object(TObject)
      Pos: LongInt;
      BetriebNr: LongInt;
      Betrieb: PChar;
      Time: TTime;
      Printed: Boolean;
      constructor Init(ABestellung: PBestellung; APos: LongInt);
      destructor Done; virtual;
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
    end;

    TBestellung= object(TCollection)
      Nr: LongInt;
      BetriebNr: LongInt;
      Betrieb: PChar;
      Time: TTime;
      constructor Init(ABetriebNr: LongInt);
      destructor Done; virtual;
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
      function GetTitle(P: PChar): PChar;
    end;

    PBestellungContents= ^TBestellungContents;
    TBestellungContents= object(TSortedCollection)
      Deleted: Word;
      constructor Init;
      constructor Load(var S: TStream);
      procedure Store(var S: TStream);
      function Compare(Item1, Item2: Pointer): Integer; virtual;
    end;

  type
    TMode= (bd_Contents, bd_Edit, bd_View, bd_Change);

  const
    id_Bestellungen= id_Ordersatz;

  procedure GetFileName(Year, Month: Word; Buf: PChar);
  var
    acS: array[0..200] of Char;
    acMonth: array[0..8] of Char;
  begin
    StrLCopy(acS, GetResString(str_Monat+Month), 6);
    StrCopy(acS, BestellPathFile(StrCat(acS, '%02u.wb')));
    Dec(Year, 1900); if Year>99 then Dec(Year, 100);
    wvsprintf(Buf, acS, Year);
  end;

{== File I/O ==}
  const
    IDCode: LongInt= $EF67;

  procedure PrintBestellung(B: PBestellung);
  var
    Page, Line, TopMargin, LeftMargin, LPP, CPL: Integer;
    acS: array[0..150] of Char;
    PrinterInfo: array[0..10] of Char;
    HeaderStr: String;
    Prn: Text;
    Artikel: PBestellArtikel;
    LieferantNr: LongInt;
    Lieferant: PLieferRec;
    I, LfdNr, y: Integer;
    SaveItems: PItemList;
    SaveCount: Integer;
    Dlg: PPrintFaxDlg;
    Font, OldFont: HFont;
    BarCode: TBarCode;
    BarPos, BarHeight, BarModule: Integer;

    procedure PrintText(S: String);
    const
      SpaceString: String[20]= '          ';
    begin
      SpaceString[0]:=Char(LeftMargin);
      Writeln(Prn, SpaceString, S);
      Inc(Line);      
    end;

    procedure Header(Full: Boolean);
    var
      i: Integer;
      S: String;
      Date: array[0..20] of Char;
    begin
      Inc(Page);
      for i:=1 to TopMargin do Writeln(Prn);
      Line:=TopMargin+1;      
      Str(Page, S);
      Insert('Seite ', S, 1);
      while Length(S)<CPL do Insert(' ', S, 1); 
      PrintText(S);
      if Full then
      begin
        B^.Time.GetString(Date, False);
        PrintText('Warenbestellung vom '+StrPas(Date));
        PrintText('');
        PrintText('An Firma: '+StrPas(Lieferant^.Name));
        PrintText('Von Kunde: '+StrPas(B^.Betrieb));
      end else
        PrintText('Bestellung von: '+StrPas(B^.Betrieb));
      PrintText('');
      PrintText(HeaderStr);
      FillChar(S[1], CPL, '-');
      S[0]:=Char(CPL); 
      PrintText(S);
    end;

  begin
    SaveCount:=B^.Count;
    GetMem(SaveItems, SaveCount*SizeOf(Pointer));
    Move(B^.Items^, SaveItems^, SaveCount*SizeOf(Pointer));    
    while B^.Count>0 do
    begin
      LieferantNr:=PBestellArtikel(B^.At(0))^.LieferantenNr;
      Lieferant:=PLieferRec(LieferDB^.GetRecNr(LieferantNr));
      if Lieferant=nil then
      begin
        MessageBox(hMainWindow, 'Lieferant einiger Artikel wurde gelöscht.', 'Fehler',
          mb_IconHand or mb_Ok);
      end else
      begin
        New(Dlg, Init(Lieferant^.Name));
        case Application^.ExecDialog(Dlg) of
          id_Fax: StrCopy(PrinterInfo, 'Fax');
          id_Print: StrCopy(PrinterInfo, 'Printer');
          else PrinterInfo[0]:=#0;
        end;
        if PrinterInfo[0]<>#0 then
          if GetPrivateProfileString(PrinterInfo, 'device', nil, acS, SizeOf(acS), ProfileFile)>0 then
          begin
            AssignPrn(Prn, StrTok(acS, ','), StrTok(nil, ','), StrTok(nil, ','));
            if IOResult=0 then
            begin
              TitlePrn(Prn, Lieferant^.Name);
              if GetPrivateProfileString(PrinterInfo, 'FontName', nil, acS, SizeOf(acS), ProfileFile)>0 then
              begin
                Font:=CreateFont(GetPrivateProfileInt(PrinterInfo, 'FontSize', 10, ProfileFile), 0,
                  0, 0, fw_Normal, 0, 0, 0, 1, Out_Default_Precis,
                  Clip_Default_Precis, Default_Quality, Fixed_Pitch, acS);
                if Font<>0 then
                  OldFont:=SetPrnFont(Prn, Font)
                else
                  OldFont:=0;                                      
              end;
              Rewrite(Prn);
              LeftMargin:=
                GetPrivateProfileInt(PrinterInfo, 'Links', 0, ProfileFile);
              TopMargin:=
                GetPrivateProfileInt(PrinterInfo, 'Oben', 0, ProfileFile);
              CPL:=75;
              LPP:=
                GetPrivateProfileInt(PrinterInfo, 'Zeilen', 70, ProfileFile);
              BarPos:=
                GetPrivateProfileInt(PrinterInfo, 'BarCodePos', 1400, ProfileFile);
              BarHeight:=
                GetPrivateProfileInt(PrinterInfo, 'BarCodeHöhe', 75, ProfileFile);
              BarModule:=
                GetPrivateProfileInt(PrinterInfo, 'BarCodeModul', 4, ProfileFile);
              HeaderStr:='  NR   ARTIKEL                    ART.NUMMER   EAN-CODE    MENGE  ÄNDERUNG';
              Page:=0;
              Header(True);
              i:=0;
              LfdNr:=1;
              while i<B^.Count do
              begin
                Artikel:=PBestellArtikel(B^.At(i));
                if Artikel^.LieferantenNr=LieferantNr then
                begin
                  if Line+1>LPP then
                  begin
                    Write(Prn, #12);
                    Header(False);
                  end;
                  y:=PrnRec(TTextRec(Prn).UserData).Cur.y;
                  Artikel^.GetPrintString(acS, LfdNr, 1);
                  PrintText(StrPas(acS));
                  Artikel^.GetPrintString(acS, LfdNr, 2);
                  PrintText(StrPas(acS));
                  BarCode.Init(Artikel^.EANCode);
                  with PrnRec(TTextRec(Prn).UserData) do
                    BarCode.Draw(DC, BarPos, y, BarModule, BarHeight);
                  BarCode.Done;
                  Inc(LfdNr);
                  B^.AtDelete(i);
                end else
                  Inc(i);
              end;
              Close(Prn);
              if OldFont<>0 then
                DeleteObject(SetPrnFont(Prn, OldFont));
            end else
              MessageBox(hMainWindow, 'Drucker nicht korrekt installiert!', 'Fehler beim Drucken', MB_OK);
          end;
      end;
      i:=0;
      while i<B^.Count do
      begin
        if PBestellArtikel(B^.At(i))^.LieferantenNr=LieferantNr then
          B^.AtDelete(i)
        else
          Inc(i);
      end;
    end;
    B^.Count:=SaveCount;
    Move(SaveItems^, B^.Items^, SaveCount*SizeOf(Pointer));
    FreeMem(SaveItems, SaveCount);
  end;

  function LoadBestellung(Idx: PBestellungIdx): PBestellung;
  var
    Strm: TShareStream;
    B: PBestellung;
    acS: array[0..100] of Char;
    ID: LongInt;
  begin
    B:=nil;
    with Idx^.Time do
      GetFileName(Year, Month, acS);
    Strm.Init(acS, of_Read or of_Share_Deny_None, 5);
    if Strm.Status=stOk then
    begin
      Strm.Read(ID, SizeOf(ID));
      if (ID=IDCode) and (Strm.GetSize>Idx^.Pos) then
      begin            
        Strm.Seek(Idx^.Pos);
        B:=PBestellung(Strm.Get);
      end;
      Strm.Done;
      if B=nil then
      begin
        ID:=LongInt(@acS);
        GlbError(em_WrongIDCode, @ID);
      end;
    end;
    LoadBestellung:=B;
  end;

  procedure DeleteBestellung(Idx: PBestellungIdx);
  var
    Strm: TShareStream;
    acS: array[0..100] of Char;
    ID, IndexPos: LongInt;
    B: PBestellung;
    C: PBestellungContents;
    I: PBestellungIdx;
    Ok: Boolean;

    function HasPos(P: PBestellungIdx): Boolean; far;
    begin
      HasPos:=P^.Pos=Idx^.Pos;  
    end;

  begin
    with Idx^.Time do GetFileName(Year, Month, acS);
    Strm.Init(acS, of_ReadWrite or of_Share_Deny_Read, 5);
    if Strm.Status=stOk then
    begin
      Ok:=False;
      Strm.Read(ID, SizeOf(ID));
      if ID=IDCode then
      begin
        Strm.Read(IndexPos, SizeOf(IndexPos));
        Strm.Seek(IndexPos);
        C:=PBestellungContents(Strm.Get);
        if C<>nil then
        begin
          Inc(C^.Deleted);
          I:=C^.FirstThat(@HasPos);
          if I<>nil then
          begin
            C^.Free(I);
            Strm.Seek(IndexPos);
            Strm.Put(C);
            Ok:=Strm.Status=stOk;                        
          end else
          begin
            MessageBox(hMainWindow, 'Bestellung wurde schon gelöscht !', Title, mb_IconInformation or mb_Ok);
            Ok:=True;
          end;
        end;
      end;
      Strm.Done;
      if not Ok then
      begin
        ID:=LongInt(@acS);
        GlbError(em_WrongIDCode, @ID);
      end;   
    end;
  end;

  function SaveBestellung(B: PBestellung): Boolean;
  var
    Strm: TShareStream;
    acS: array[0..100] of Char;
    ID, IndexPos: LongInt;
    Contents: PBestellungContents;
  begin
    SaveBestellung:=False;
    with B^.Time do
      GetFileName(Year, Month, acS);
    if not FileExist(acS) then
    begin
      Strm.Init(acS, of_Create, 0);
      Strm.Write(IDCode, SizeOf(IDCode));
      IndexPos:=0;
      Strm.Write(IndexPos, SizeOf(IndexPos));
      Strm.Done;
    end;
    Strm.Init(acS, of_ReadWrite or of_Share_Deny_Read, 5);
    if Strm.Status=stOk then
    begin
      Strm.Read(ID, SizeOf(ID));
      if ID=IDCode then
      begin
        Strm.Read(IndexPos, SizeOf(IndexPos));
        if IndexPos<>0 then
        begin
          Strm.Seek(IndexPos);
          Contents:=PBestellungContents(Strm.Get);
          Strm.Seek(IndexPos);
        end else
        begin
          New(Contents, Init);
          IndexPos:=Strm.GetPos;
        end;
        Contents^.Insert(New(PBestellungIdx, Init(B, IndexPos)));
        Strm.Put(B);
        IndexPos:=Strm.GetPos;
        Strm.Put(Contents);
        Dispose(Contents, Done);
        Strm.Seek(4);
        Strm.Write(IndexPos, SizeOf(IndexPos));
        SaveBestellung:=Strm.Status=stOk;
        Strm.Done;
      end else
      begin
        Strm.Done; ID:=LongInt(@acS);
        GlbError(em_WrongIDCode, @ID);
      end;
    end else
    begin
      MessageBeep(0);
      MessageBox(hMainWindow, 'Kann Bestellung nicht speichern !', Title,
        mb_IconExclamation or mb_Ok);
    end;
  end;

  function GetContents(Month, Year: Word): PBestellungContents;
  var
    Strm: TShareStream;
    acS: array[0..100] of Char;
    acErr: array[0..100] of Char;
    Contents: PBestellungContents;
    ID, IndexPos: LongInt;
  begin
    Contents:=nil;
    GetFileName(Year, Month, acS);
    if FileExist(acS) then
    begin
      Strm.Init(acS, of_Read or of_Share_Deny_None, 5);
      if Strm.Status=stOk then
      begin
        Strm.Read(ID, SizeOf(ID));
        if ID=IDCode then
        begin
          Strm.Read(IndexPos, SizeOf(IndexPos));
          Strm.Seek(IndexPos);
          Contents:=PBestellungContents(Strm.Get);
          Strm.Done;
        end else
        begin
          Strm.Done; ID:=LongInt(@acS);
          GlbError(em_WrongIDCode, @ID); 
        end;
      end else
      begin
        IndexPos:=LongInt(@acS);
        wvsprintf(acErr, 'Kann Bestelldatei %s nicht lesen.', IndexPos);
        MessageBox(hMainWindow, acErr, Title, mb_IconExclamation or mb_Ok);
      end;
    end;
    GetContents:=Contents;
  end;

{== TBestellungIdx ==}
  constructor TBestellungIdx.Init(ABestellung: PBestellung; APos: LongInt);
  begin
    TObject.Init;
    Pos:=APos;
    BetriebNr:=ABestellung^.BetriebNr;
    Betrieb:=StrNew(ABestellung^.Betrieb);
    Time.InitCopy(ABestellung^.Time);
    Printed:=False;
  end;

  destructor TBestellungIdx.Done;
  begin
    StrDispose(Betrieb);
  end;

  constructor TBestellungIdx.Load(var S: TStream);
  begin
    S.Read(Pos, SizeOf(Pos));
    S.Read(BetriebNr, SizeOf(BetriebNr));
    Betrieb:=S.StrRead;
    Time.Load(S);
    S.Read(Printed, SizeOf(Printed));
  end;

  procedure TBestellungIdx.Store(var S: TStream);
  begin
    S.Write(Pos, SizeOf(Pos));
    S.Write(BetriebNr, SizeOf(BetriebNr));
    S.StrWrite(Betrieb);
    Time.Store(S);
    S.Write(Printed, SizeOf(Printed));
  end;

{== TBestellungContents ==}
  constructor TBestellungContents.Init;
  begin
    TSortedCollection.Init(50, 10);
    Duplicates:=True;
    Deleted:=0;
  end;

  constructor TBestellungContents.Load(var S: TStream);
  begin
    TSortedCollection.Load(S);
    S.Read(Deleted, SizeOf(Deleted));
  end;

  procedure TBestellungContents.Store(var S: TStream);
  begin
    TSortedCollection.Store(S);
    S.Write(Deleted, SizeOf(Deleted));
  end;

  function TBestellungContents.Compare;
  var
    I1: PBestellungIdx absolute Item1;
    I2: PBestellungIdx absolute Item2;
  begin
    Compare:=I1^.Time.CompareTo(I2^.Time);
  end;

{== TBestellArtikel ==}
  constructor TBestellArtikel.Init(AnArtikelEK: LongInt; ACount: Word);
  var
    Artikel: PArtikelRec;
    ArtikelEK: PArtikelEKRec;
  begin
    ArtikelEK:=PArtikelEKRec(EKDB^.GetRecNr(AnArtikelEK));
    if ArtikelEK<>nil then
    begin
      Artikel:=PArtikelRec(ArtikelDB^.GetRecNr(ArtikelEK^.ArtikelNr));
      if Artikel<>nil then
      begin
        ArtikelNr:=ArtikelEK^.ArtikelNr;
        ArtikelEKNr:=AnArtikelEK;
        Name:=StrNew(Artikel^.Name);
        Warengruppe:=Artikel^.Warengruppe;
        EVArt:=StrNew(Artikel^.EVArt);
        EVInhalt:=StrNew(Artikel^.EVInhalt);
        MwSt:=GlobalSettings.MwSt[Artikel^.MwSt];
        ChangeRev:=Artikel^.ChangeRev;
        LieferantenNr:=ArtikelEK^.LieferantenNr;
        EANCode:=StrNew(ArtikelEk^.LieferArtNr);
        UVMenge:=ArtikelEK^.UVMenge;
        UVPreis:=ArtikelEK^.UVPreis;
        Count:=ACount;
      end else
        Fail;
    end else
      Fail;
  end;

  destructor TBestellArtikel.Done;
  begin
    StrDispose(Name);
    StrDispose(EVArt);
    StrDispose(EVInhalt);
    StrDispose(EANCode);
  end;

  constructor TBestellArtikel.Load(var S: TStream);
  begin
    S.Read(ArtikelNr, SizeOf(ArtikelNr));
    S.Read(ArtikelEKNr, SizeOf(ArtikelEKNr));
    Name:=S.StrRead;
    S.Read(Warengruppe, SizeOf(Warengruppe));
    EVArt:=S.StrRead;
    EVInhalt:=S.StrRead;
    S.Read(MwSt, SizeOf(MwSt));
    S.Read(ChangeRev, SizeOf(ChangeRev));
    S.Read(LieferantenNr, SizeOf(LieferantenNr));
    EANCode:=S.StrRead;
    S.Read(UVMenge, SizeOf(UVMenge));
    S.Read(UVPreis, SizeOf(UVPreis));
    S.Read(Count, SizeOf(Count));
  end;

  procedure TBestellArtikel.Store(var S: TStream);
  begin
    S.Write(ArtikelNr, SizeOf(ArtikelNr));
    S.Write(ArtikelEKNr, SizeOf(ArtikelEKNr));
    S.StrWrite(Name);
    S.Write(Warengruppe, SizeOf(Warengruppe));
    S.StrWrite(EVArt);
    S.StrWrite(EVInhalt);
    S.Write(MwSt, SizeOf(MwSt));
    S.Write(ChangeRev, SizeOf(ChangeRev));
    S.Write(LieferantenNr, SizeOf(LieferantenNr));
    S.StrWrite(EANCode);
    S.Write(UVMenge, SizeOf(UVMenge));
    S.Write(UVPreis, SizeOf(UVPreis));
    S.Write(Count, SizeOf(Count));
  end;

  procedure TBestellArtikel.GetString(P: PChar);
  var
    Data: record
      Name, EVArt, EVInhalt: PChar;
      UVMenge, Count: Word;
    end;
  begin
    Data.Name:=Name;
    Data.EVArt:=EVArt;
    Data.EVInhalt:=EVInhalt;
    Data.UVMenge:=UVMenge;
    Data.Count:=Count;
    wvsprintf(P, '%s'#9'%s'#9'%s'#9'%u'#9'%ux', Data);
  end;

  procedure TBestellArtikel.GetPrintString(P: PChar; Nr, Line: Integer);
  const
    {Template1: array[0..35] of Char= '%4u  %-30s  %13s  %5ux   I_____I';}
    Template1: array[0..50] of Char= '%4u  %-30s                      %5ux   I_____I';
    Template2: array[0..50] of Char= '      %i  %s  %s';
  var
    Data1: record
      Nr: Word;
      Name: PChar;
      Menge: Word;
    end;
    Data2: record
      UVMenge: Integer;
      EVArt, EVInhalt: PChar;
    end;
    S: PChar;
    I: Integer;   
  begin
    if Line=1 then
    begin
      Data1.Nr:=Nr;
      Data1.Name:=Name;
      Data1.Menge:=Count;
      wvsprintf(P, Template1, Data1);
    end else
    begin
      Data2.EVArt:=EVArt;
      Data2.EVInhalt:=EVInhalt;
      Data2.UVMenge:=UVMenge;
      FillChar(P^, 80, #32); 
      wvsprintf(P, Template2, Data2);
      if EANCode<>nil then
      begin
        S:=StrEnd(P);
        S^:=#32;
        I:=StrLen(EANCode);
        while (S-P)+I<45 do Inc(S);
        StrCopy(S, EANCode);
      end;
    end;
  end;

{== TBestellung ==}
  constructor TBestellung.Init(ABetriebNr: LongInt);
  var B: PBetriebRec;
  begin
    TCollection.Init(50, 50);
    B:=PBetriebRec(BetriebeDB^.GetRecNr(ABetriebNr));
    if B=nil then Fail;
    Nr:=-1;
    BetriebNr:=ABetriebNr;
    Betrieb:=StrNew(B^.Name);
    Time.Init;
  end;

  destructor TBestellung.Done;
  begin
    StrDispose(Betrieb);
    TCollection.Done;    
  end;

  constructor TBestellung.Load(var S: TStream);
  begin
    TCollection.Load(S);
    S.Read(Nr, SizeOf(Nr));
    S.Read(BetriebNr, SizeOf(BetriebNr));
    Betrieb:=S.StrRead;
    Time.Load(S);    
  end;

  procedure TBestellung.Store(var S: TStream);
  begin
    TCollection.Store(S);
    S.Write(Nr, SizeOf(Nr));
    S.Write(BetriebNr, SizeOf(BetriebNr));
    S.StrWrite(Betrieb);
    Time.Store(S);
  end;

  function TBestellung.GetTitle(P: PChar): PChar;
  var acS: array[0..50] of Char;
  begin
    StrCopy(StrECopy(StrECopy(StrECopy(P, 'Bestellung: '), Betrieb), ' vom '),
      Time.GetString(acS, True));
    GetTitle:=P;
  end;

{== TBestellDlg ==}
  type
    PBestellDlg= ^TBestellDlg;
    TBestellDlg= object(TDlgWindow)
      BetriebeColl: TCollection;
      ActOSNr, ActBetriebNr: LongInt;
      ActOrdersatz: POrdersatz;
      ActContents: PBestellungContents;
      ActBestellung: PBestellung;
      ActBestellungIdx: PBestellungIdx;
      constructor Init;
      destructor Done; virtual;
      procedure SetupWindow; virtual;
      procedure SetMode(AMode: TMode);
      function GetClassName: PChar; virtual;
      procedure GetWindowClass(var AWndClass: TWndClass); virtual;
      procedure WMSize(var Msg: TMessage); virtual wm_First+wm_Size;
      procedure WMClose(var Msg: TMessage); virtual wm_First+wm_Close;
      procedure IDMViewBestellung(var Msg: TMessage); virtual cm_First+idm_Update;
      procedure IDMAddBestellung(var Msg: TMessage); virtual cm_First+idm_Insert;
      procedure IDMPrint(var Msg: TMessage); virtual cm_First+idm_Print;
      procedure IDMDeleteBestellung(var Msg: TMessage); virtual cm_First+idm_Delete;
      procedure IDMBestellen(var Msg: TMessage); virtual cm_First+idm_Bestellen;
      procedure IDMSaveBestellung(var Msg: TMessage); virtual cm_First+idm_SaveBestellung;
      procedure IDMEnde(var Msg: TMessage); virtual cm_First+idm_Ende;
      procedure IDMInfo(var Msg: TMessage); virtual cm_First+idm_Info;
      procedure IDMEditBestellung(var Msg: TMessage); virtual cm_First+idm_EditBestellung;
      procedure IDBestellungen(var Msg: TMessage); virtual id_First+id_Bestellungen;
      procedure IDBetriebe(var Msg: TMessage); virtual id_First+id_Betrieb;
      procedure IDJahr(var Msg: TMessage); virtual id_First+id_Jahr;
      procedure IDMonat(var Msg: TMessage); virtual id_First+id_Monat;
      procedure Ok(var Msg: TMessage); virtual id_First+id_Ok;
      procedure Save(var Msg: TMessage); virtual id_First+id_Save;
      procedure Cancel(var Msg: TMessage); virtual id_First+id_Cancel;
      procedure Extra(var Msg: TMessage); virtual id_First+id_Extra;
     private
      OldMainWindow: PWindowsObject;
      Mode: TMode; InputMode: Byte;
      InputIdx: Integer;
      BetriebeCB, MonatCB, JahrCB: PComboBox;
      MainListBox: PListBox;
      InputED: PEdit;
      BigY, SmallY, NormalX: Integer;
      procedure Update;
      procedure SetInputIdx(Index: Integer);
      procedure SetInputCnt(Count: Integer);
      procedure TransformActBestellung;
    end;

  constructor TBestellDlg.Init;
  var
    P: PWindowsObject;
  begin
    P:=Application^.MainWindow;
    if GlbBestellung then P:=nil;
    TDlgWindow.Init(P, MakeIntResource(BestellDlg));
    New(BetriebeCB, InitResource(@Self, id_Betrieb, 100));
    New(MonatCB, InitResource(@Self, id_Monat, 20));
    New(JahrCB, InitResource(@Self, id_Jahr, 10));
    New(MainListBox, InitResource(@Self, id_Bestellungen));
    New(InputED, InitResource(@Self, id_Input, 10));
    BetriebeColl.Init(10, 10);
    ActOrdersatz:=nil;
    ActContents:=nil;
    ActBestellung:=nil;
  end;

  destructor TBestellDlg.Done;
  begin
    if ActBestellung<>nil then Dispose(ActBestellung, Done);
    if ActContents<>nil then Dispose(ActContents, Done);
    if ActOrdersatz<>nil then Dispose(ActOrdersatz, Done);
    BetriebeColl.DeleteAll;
    BetriebeColl.Done;
    Application^.MainWindow:=OldMainWindow;
    hMainWindow:=OldMainWindow^.hWindow;
    if GlbBestellung then
      PostQuitMessage(0)
    else
      ShowWindow(hMainWindow, sw_Show);
    EnableWindow(hMainWindow, True);
    SetFocus(hMainWindow);
    TDlgWindow.Done;
  end;

  procedure TBestellDlg.SetupWindow;
  var
    R, R2: TRect;
    i: Integer;
    P: PBetriebRec;
    acS: array[0..100] of Char;
    Time: TTime;
  begin
    TDlgWindow.SetupWindow;
    ActBetriebNr:=-1;
    OldMainWindow:=Application^.MainWindow;
    Application^.MainWindow:=@Self;
    hMainWindow:=hWindow;
    GetWindowRect(hWindow, R);
    GetWindowRect(GetItemHandle(50), R2);
    BigY:=R.Bottom-R.Top; SmallY:=R2.Top-R.Top;
    NormalX:=R.Right-R.Left;
    MoveWindow(hWindow,
      (GetSystemMetrics(sm_CXScreen)-(R.Right-R.Left)) Div 2,
      (GetSystemMetrics(sm_CYScreen)-(R.Bottom-R.Top)) Div 2,
      NormalX, SmallY, False);
    ShowWindow(hWindow, sw_Show);
    EnableWindow(OldMainWindow^.hWindow, False);
    Time.Init;
    with BetriebeCB^ do
    begin
      BetriebeColl.DeleteAll;
      ClearList;
      AddString('Alle');
      BetriebeDB^.Register(hWindow, 1);
      for i:=0 to BetriebeDB^.NumRecs(hWindow)-1 do
      begin
        P:=PBetriebRec(BetriebeDB^.GetRec(hWindow, i));
        BetriebeColl.Insert(Pointer(P^.Nr));
        AddString(P^.Name);
      end;
      BetriebeDB^.Unregister(hWindow);
      SetSelIndex(0);
    end;
    with MonatCB^ do
    begin
      ClearList;
      AddString('Alle');
      for i:=1 to 12 do AddString(GetResString(str_Monat+i));
      SetSelIndex(Time.Month);
    end;
    with JahrCB^ do
    begin
      ClearList;
      AddString('Alle');
      for i:=1994 to 1999 do
      begin
        wvsprintf(acS, '%d', i);
        AddString(acS);
      end;
      SetSelIndex(Time.Year-1993);
    end;
    SetMode(bd_Contents);
  end;

  procedure TBestellDlg.SetMode(AMode: TMode);
  var
    A: LongInt;
    Line, i: Integer;
    acS: array[0..100] of Char;
    P: PChar;
    M: HMenu;
  begin
    if AMode=bd_Contents then
    begin
      if ActBestellung<>nil then Dispose(ActBestellung, Done);
      ActBestellung:=nil;
      SetWindowPos(hWindow, 0, 0, 0, NormalX, SmallY, swp_NoZOrder or swp_NoMove);
      EnableWindow(GetItemHandle(id_Betrieb), True);
      EnableWindow(GetItemHandle(id_Monat), JahrCB^.GetSelIndex<>0);
      EnableWindow(GetItemHandle(id_Jahr), True);
      M:=GetMenu(hWindow);
      SetMenu(hWindow, LoadMenu(hInstance, MakeIntResource(BestellMenu)));
      DestroyMenu(M);
      EnableMenuItem(GetMenu(hWindow), idm_Ende, mf_Enabled);
      EnableMenuItem(GetMenu(hWindow), idm_Bestellen, mf_Enabled);
      SetWindowText(GetItemHandle(id_BestellungenText), 'Übersicht: Bestellungen');
      SendMessage(MainListBox^.hWindow, lb_SetTabStops, SizeOf(TabsContents) Div 2, LongInt(@TabsContents));
      Mode:=AMode;
    end else
    if (AMode=bd_Edit) or (AMode=bd_Change) then
    begin
      ActOSNr:=SelectOrdersatz;
      if ActOSNr>0 then
      begin
        if ActBestellung<>nil then
          A:=ActBestellung^.BetriebNr
        else
          A:=ActBetriebNr;
        ActOrdersatz:=LoadOrdersatz(ActOSNr, A);
        if ActOrdersatz<>nil then
        begin
          if AMode=bd_Change then
            TransformActBestellung;
          SetWindowPos(hWindow, 0, 0, 0, NormalX, BigY, swp_NoZOrder or swp_NoMove);
          EnableWindow(GetItemHandle(id_Betrieb), False);
          EnableWindow(GetItemHandle(id_Monat), False);
          EnableWindow(GetItemHandle(id_Jahr), False);
          M:=GetMenu(hWindow);
          SetMenu(hWindow, LoadMenu(hInstance, MakeIntResource(BestellMenu_Edit)));
          DestroyMenu(M);
          if ActBestellung=nil then
            SetWindowText(GetItemHandle(id_BestellungenText), 'Neue Bestellung')
          else
            SetWindowText(GetItemHandle(id_BestellungenText), ActBestellung^.GetTitle(acS));
          SendMessage(MainListBox^.hWindow, lb_SetTabStops, SizeOf(TabsOS) Div 2, LongInt(@TabsOS));
          Mode:=AMode;
          SetInputIdx(-2);
        end;
      end;
    end else
    if AMode=bd_View then
    begin
      Line:=MainListBox^.GetSelIndex;
      if (ActContents<>nil) and (Line>=0) then
      begin
        ActBestellungIdx:=PBestellungIdx(ActContents^.At(Line));
        ActBestellung:=LoadBestellung(ActBestellungIdx);
        if ActBestellung<>nil then
        begin
          M:=GetMenu(hWindow);
          SetMenu(hWindow, LoadMenu(hInstance, MakeIntResource(BestellMenu_View)));
          EnableWindow(GetItemHandle(id_Betrieb), False);
          EnableWindow(GetItemHandle(id_Monat), False);
          EnableWindow(GetItemHandle(id_Jahr), False);
          DestroyMenu(M);
          SendMessage(MainListBox^.hWindow, lb_SetTabStops, (SizeOf(TabsOS) Div 2)-1, LongInt(@TabsOS[2]));
          with MainListBox^ do
          begin
            SetWindowText(GetItemHandle(id_BestellungenText), ActBestellung^.GetTitle(acS));
            ClearList;
            for i:=0 to ActBestellung^.Count-1 do
            begin
              PBestellArtikel(ActBestellung^.At(i))^.GetString(acS);
              AddString(acS);
            end;
          end;
          Mode:=AMode;
        end;
      end;
    end;
    InvalidateRect(hWindow, nil, True);
    Update;
  end;

  procedure TBestellDlg.TransformActBestellung;
  var
    i, j: Integer;
    B: PBestellArtikel;
    O: POSItem;

    function Fits(O: POSItem): Boolean; far;
    begin
      Fits:=(O<>nil) and (TypeOf(O^)=TypeOf(TOSItem)) and (O^.ArtikelEKNr=B^.ArtikelEKNr);
    end;

  begin
    i:=0;
    while i<ActBestellung^.Count do
    begin
      B:=PBestellArtikel(ActBestellung^.At(i));
      O:=ActOrdersatz^.FirstThat(@Fits);
      if O<>nil then
      begin
        O^.Count:=B^.Count;
        ActBestellung^.AtFree(i);
      end else
        inc(i);              
    end;
    if ActBestellung^.Count>0 then
      MessageBox(hMainWindow, 'Nicht alle Artikel wurden in diesem Ordersatz wiedergefunden.', 'Achtung',
        MB_ICONEXCLAMATION or MB_OK);
  end;

  procedure TBestellDlg.Update;
  var
    Y, M, Year, Month: Word;
    i: Integer;
    Contents: PBestellungContents;
    acS: array[0..100] of Char;
    Line: Integer;
  begin
    if Mode=bd_Contents then
    begin
      Y:=JahrCB^.GetSelIndex+1993;
      M:=MonatCB^.GetSelIndex;
      if ActContents<>nil then Dispose(ActContents, Done);
      New(ActContents, Init);
      for Year:=1994 to 2000 do
        for Month:=1 to 12 do
          if (Y=1993) or ((Year=Y) and (M=0)) or ((Year=Y) and (Month=M)) then
          begin
            Contents:=GetContents(Month, Year);
            if Contents<>nil then
            begin
              for i:=0 to Contents^.Count-1 do
                if (ActBetriebNr=-1) or (PBestellungIdx(Contents^.At(i))^.BetriebNr=ActBetriebNr) then
                  ActContents^.Insert(Contents^.At(i));
              Contents^.DeleteAll;
              Dispose(Contents, Done);
            end;
          end;
      EnableMenuItem(GetMenu(hWindow), idm_Bestellen, Byte(ActBetriebNr=-1));
      SetMenu(hWindow, GetMenu(hWindow));
      UpdateWindow(hWindow);
      with MainListBox^ do
      begin
        ClearList;
        if ActContents<>nil then
        for i:=0 to ActContents^.Count-1 do
        with PBestellungIdx(ActContents^.At(i))^ do
        begin
          Time.GetString(acS, True);
          StrCat(StrCat(acS, #9), Betrieb);
          AddString(acS);
        end;
        SendMessage(MainListBox^.hWindow, lb_SetTopIndex, ActContents^.Count-1, 0);
      end;
    end else
    if (Mode=bd_Edit) or (Mode=bd_Change) then
    begin
      with MainListBox^ do
      begin
        ClearList;
        Line:=0;
        for i:=0 to ActOrdersatz^.Count-1 do
        begin
          ActOrdersatz^.GetStr(i, acS, @Line);
          AddString(acS);
        end;
      end;
    end;
    if (MainListBox^.GetCount=0) and (Mode=bd_Contents) then
    begin
      ShowWindow(GetItemHandle(51), sw_Show);
      ShowWindow(GetItemHandle(id_Bestellungen), sw_Hide);
    end else
    begin
      ShowWindow(GetItemHandle(51), sw_Hide);
      ShowWindow(GetItemHandle(id_Bestellungen), sw_Show);
    end;
  end;

  procedure TBestellDlg.SetInputIdx(Index: Integer);
  var
    ArtikelEK: PArtikelEKRec;
    Item: POSItem;
    acS: array[0..5] of Char;
    State: Boolean;
  begin
    State:=False;
    if (Index>=0) and (Index<ActOrdersatz^.Count) and (Not ActOrdersatz^.IsGroup(Index)) then
    begin
      MainListBox^.SetSelIndex(Index);
      Item:=POSItem(ActOrdersatz^.At(Index));
      if Item<>nil then
      begin
        ArtikelEK:=PArtikelEKRec(EKDB^.GetRecNr(Item^.ArtikelEKNr));
        if ArtikelEK<>nil then
        begin        
          InputIdx:=Index;
          InputMode:=1;
          SetWindowText(GetItemHandle(id_InputText), '&Anzahl:');
          PlaySnd('Anzahl');
          if Item^.Count>0 then
            Str(Item^.Count, acS)
          else
            StrCopy(acS, '1');
          InputED^.SetText(acS);
          InputED^.SetSelection(0, -1);
          SetFocus(InputED^.hWindow);
          State:=True;
        end;
      end;
    end;
    if not State then
    begin
      if Index<>-2 then PlaySndFehler;
      SetInputCnt(-1);
    end;
  end;

  procedure TBestellDlg.SetInputCnt(Count: Integer);
  var
    Item: POSItem;
    acS: array[0..100] of Char;
  begin
    if (Count>=0) and (InputIdx>=0) and (InputIdx<ActOrdersatz^.Count) then
    begin
      Item:=POSItem(ActOrdersatz^.At(InputIdx));
      if Item<>nil then
      begin
        Item^.Count:=Count;
        MainListBox^.DeleteString(InputIdx);
        ActOrdersatz^.GetStr(InputIdx, acS, nil);
        MainListBox^.InsertString(acS, InputIdx);
      end;
    end;
    SetWindowText(GetItemHandle(id_InputText), '&Nummer:');
    PlaySnd('Nummer');
    InputMode:=0;
    InputED^.SetText('');
    SetFocus(InputED^.hWindow);                                
  end;

  function TBestellDlg.GetClassName: PChar;
  begin
    GetClassName:='bordlgWAWIS:Bestellung';
  end;

  procedure TBestellDlg.GetWindowClass(var AWndClass: TWndClass);
  begin
    TDlgWindow.GetWindowClass(AWndClass);
    AWndClass.hIcon:=LoadIcon(hInstance, MakeIntResource(MainIcon));
  end;

  procedure TBestellDlg.WMSize;
  begin
    if not GlbBestellung then
    begin
      if Msg.wParam=SizeIconic then
        ShowWindow(OldMainWindow^.hWindow, sw_Hide)
      else if Msg.wParam=SizeNormal then
        ShowWindow(OldMainWindow^.hWindow, sw_Show);
    end;
    DefWndProc(Msg);
  end;

  procedure TBestellDlg.WMClose;
  begin
    if Mode<>bd_Contents then Cancel(Msg);
    if Mode=bd_Contents then CloseWindow;
  end;

  procedure TBestellDlg.IDBestellungen;
  var i: Integer;
  begin
    if Mode=bd_Contents then
    begin
      if Msg.lParamHi=lbn_DblClk then
        SetMode(bd_View);
    end else
    if (Mode=bd_Edit) or (Mode=bd_Change) then
    begin
      if Msg.lParamHi=lbn_SelChange then
      begin
        i:=MainListBox^.GetSelIndex;
        SetInputIdx(i);
      end;
    end;
  end;

  procedure TBestellDlg.IDBetriebe;
  begin
    if Msg.lParamHi=cbn_SelChange then
    begin
      if BetriebeCB^.GetSelIndex>0 then
        ActBetriebNr:=LongInt(BetriebeColl.At(BetriebeCB^.GetSelIndex-1))
      else
        ActBetriebNr:=-1;
      Update;
    end;
  end;

  procedure TBestellDlg.IDMonat;
  begin
    if Msg.lParamHi=cbn_SelChange then Update;
  end;

  procedure TBestellDlg.IDJahr;
  begin
    if Msg.lParamHi=cbn_SelChange then
    begin
      if JahrCB^.GetSelIndex=0 then
      begin
        MonatCB^.SetSelIndex(0);
        EnableWindow(GetItemHandle(id_Monat), False);
      end else
        EnableWindow(GetItemHandle(id_Monat), True);
      Update;
    end;
  end;

  procedure TBestellDlg.Ok;
  var
    acS: array[0..10] of Char;
    N, C: Integer;
  begin
    if (Mode=bd_Edit) or (Mode=bd_Change) then
    begin
      InputED^.GetText(acS, SizeOf(acS));
      Val(acS, N, C);
      if (C=0) and (N>=0) then
      begin
        if (InputMode=0) and (N>0) then
          SetInputIdx(ActOrdersatz^.GetIndex(N))
        else
          SetInputCnt(N);
      end else
      begin
        MessageBeep(0);
        InputED^.SetText('');
      end;
    end;
  end;

  procedure TBestellDlg.Save;
  var
    A: PBestellArtikel;

    procedure DoCopy(P: POSItem); far;
    var
      BA: PBestellArtikel;
    begin
      if (P<>nil) and (TypeOf(P^)=TypeOf(TOSItem)) then
        if P^.Count>0 then
        begin
          New(BA, Init(P^.ArtikelEKNr, P^.Count));
          if BA<>nil then
            ActBestellung^.Insert(BA)
          else
            MessageBox(hWindow, 'Einer der Artikel wurde während der Bestellung'+
              ' im Netz gelöscht !', Title, mb_IconExclamation or mb_Ok);
        end;
    end;

  begin
    if (Mode=bd_Edit) or ((Mode=bd_Change) and
      (MessageBox(hWindow, 'Änderungen speichern ?', Title, mb_IconQuestion or mb_YesNo)=id_Yes)) then
    begin
      if Mode=bd_Edit then
        New(ActBestellung, Init(LongInt(BetriebeColl.At(BetriebeCB^.GetSelIndex-1))))
      else
        DeleteBestellung(ActBestellungIdx);
      ActOrdersatz^.ForEach(@DoCopy);
      if ActBestellung^.Count=0 then
      begin
        MessageBox(hWindow, 'Es wurde nichts bestellt !', Title,
          mb_IconInformation or mb_Ok);
        Dispose(ActBestellung, Done);
        ActBestellung:=nil;
        SetMode(bd_Contents);
      end else
      if SaveBestellung(ActBestellung) then
      begin                
        if MessageBox(hWindow, 'Bestellung gleich faxen/drucken?', Title,
          mb_IconQuestion or mb_YesNo)=id_Yes then
          PrintBestellung(ActBestellung);
        Dispose(ActBestellung, Done);
        ActBestellung:=nil;
        SetMode(bd_Contents);
      end;
    end;
  end;

  procedure TBestellDlg.Cancel;
  var C: LongInt;
    procedure DoCount(P: POSItem); far;
    begin
      if (P<>nil) and (TypeOf(P^)=TypeOf(TOSItem)) then
        Inc(C, P^.Count);
    end;
  begin
    if Mode=bd_Edit then
    begin
      C:=0;
      ActOrdersatz^.ForEach(@DoCount);
      if (C=0) or (MessageBox(hWindow, 'Diese Bestellung verwerfen ?', Title, mb_IconQuestion
        or mb_YesNo or mb_DefButton2)=id_Yes) then
        SetMode(bd_Contents);
    end else
    if Mode=bd_Change then
    begin
      if MessageBox(hWindow, 'Änderungen verwerfen ?', Title,
        mb_IconQuestion or mb_YesNo or mb_DefButton2)=id_Yes then
      begin
        Dispose(ActBestellung, Done);
        ActBestellung:=nil;
        SetMode(bd_Contents);
      end;
    end else
    if Mode=bd_View then
      SetMode(bd_Contents);
  end;

  procedure TBestellDlg.Extra;
  var
    OS: POrdersatz;
    Item: POSItem;
  begin
    if AddExtra(ActBetriebNr) then
    begin
      OS:=LoadOrdersatz(-1, ActBetriebNr);
      if OS<>nil then
      begin
        if not ActOrdersatz^.HasExtras then
          ActOrdersatz^.InsertGroup(ActOrdersatz^.Count, New(POSGroup, Init('Extras')));
        Item:=POSItem(OS^.At(OS^.Count-1));
        ActOrdersatz^.InsertItem(ActOrdersatz^.Count, New(POSItem, Init(Item^.ArtikelEKNr)), 1);
        Dispose(OS, Done);
        Update;
        SetInputIdx(ActOrdersatz^.Count-1);
      end;
    end;
  end;

  procedure TBestellDlg.IDMViewBestellung;
  begin
    if (Mode=bd_Contents) and (MainListBox^.GetSelIndex>=0) then
      SetMode(bd_View)
    else
      MessageBeep(0);
  end;

  procedure TBestellDlg.IDMEditBestellung;
  begin
    if (Mode=bd_View) then SetMode(bd_Change);
  end;

  procedure TBestellDlg.IDMAddBestellung;
  begin
    
  end;

  procedure TBestellDlg.IDMPrint;
  var
    B: PBestellung;
    Line: Integer;
  begin
    Line:=MainListBox^.GetSelIndex;
    if (ActContents<>nil) and (Line>=0) then
    begin
      B:=LoadBestellung(PBestellungIdx(ActContents^.At(Line)));
      PrintBestellung(B);
      Dispose(B, Done);
    end else
      MessageBeep(0);
  end;

  procedure TBestellDlg.IDMDeleteBestellung;
  begin
    if (Mode=bd_Contents) and (MainListBox^.GetSelIndex>=0) then
    begin
      if MessageBox(hMainWindow, 'Diese Bestellung wirklich löschen??', Title,
        mb_IconQuestion or mb_YesNo or mb_DefButton2)=id_Yes then
      begin
        DeleteBestellung(PBestellungIdx(ActContents^.At(MainListBox^.GetSelIndex)));
        Update;
      end;
    end;
  end;

  procedure TBestellDlg.IDMBestellen;
  begin
    SetMode(bd_Edit);
  end;

  procedure TBestellDlg.IDMSaveBestellung;
  begin
    Save(Msg);
  end;

  procedure TBestellDlg.IDMEnde;
  begin
    if Mode=bd_Contents then
      CloseWindow
    else
      Cancel(Msg);
  end;

  procedure TBestellDlg.IDMInfo;
  begin
    Application^.ExecDialog(New(PInfoDlg, Init));
  end;

  procedure Bestellung;
  begin
    Application^.MakeWindow(New(PBestellDlg, Init));
  end;

  const
    RBestellung: TStreamRec= (
      ObjType: 1600;
      VmtLink: Ofs(TypeOf(TBestellung)^);
      Load: @TBestellung.Load;
      Store: @TBestellung.Store
    );
    RBestellArtikel: TStreamRec= (
      ObjType: 1601;
      VmtLink: Ofs(TypeOf(TBestellArtikel)^);
      Load: @TBestellArtikel.Load;
      Store: @TBestellArtikel.Store
    );
    RBestellungIdx: TStreamRec= (
      ObjType: 1602;
      VmtLink: Ofs(TypeOf(TBestellungIdx)^);
      Load: @TBestellungIdx.Load;
      Store: @TBestellungIdx.Store
    );
    RBestellungContents: TStreamRec= (
      ObjType: 1603;
      VmtLink: Ofs(TypeOf(TBestellungContents)^);
      Load: @TBestellungContents.Load;
      Store: @TBestellungContents.Store
    );

  procedure RegisterBestellung; 
  begin
    RegisterType(RBestellung);
    RegisterType(RBestellArtikel);
    RegisterType(RBestellungIdx);
    RegisterType(RBestellungContents);
  end;

begin
  RegisterBestellung;
end.
