Unit DBServer;
Interface
  Uses
    Objects, OWindows, WinTypes, WinProcs, Strings, BtpWin, WaitDlg,
    Globals;

  Const
    db_Updated  = 1;
    db_Deleted  = 2;
    db_Inserted = 3;
    db_PreDel   = 4;
    db_Reorder  = 16;
    db_Reread   = 32;

{*** general objects/records for databases ***}
  Type
    PBufferElement= ^TBufferElement;
    TBufferElement= Record
      Pos: LongInt;
      Case Byte Of
        0: (Nr: LongInt);
        1: (Data: Array[1..1024] Of Byte);
    End;

    PDBFile= ^TDBFile;
    TDBFile= Object(BFileExt)
      Name: Array[0..20] Of Char;
      KeyBuf: Array[0..255] Of Char;
      Constructor Init(FileName: PChar; OpenMode: Integer; AName: Word);
      Destructor Done; virtual;
      Function BT(OpCode, Key: Integer): Integer; virtual;
      Function BTRetry(OpCode, Key: Integer): Integer; virtual;
      Function BTExt(OpCode, Key: Integer): Integer; virtual;
    End;

    PDBBuffer= ^TDBBuffer;
    TDBBuffer= Object(TSortedCollection)
      ElementSize: Word;
      Constructor Init(ADBFile: PDBFile; Dlg: PWaitDlg);
      Procedure FreeItem(Item: Pointer); virtual;
      Function KeyOf(Item: Pointer): Pointer; virtual;
      Function Compare(Key1, Key2: Pointer): Integer; virtual;
      Function NewElement: PBufferElement;
    End;

    PDBIndex= ^TDBIndex;
    TDBIndex= Object(TCollection)
      SortKey: Integer;
      Changed, Reread: Boolean;
      Constructor Init(ADBFile: PDBFile; ASortKey: Integer);
      Procedure FreeItem(Item: Pointer); virtual;
      Procedure DeleteKey(Nr: LongInt);
      Procedure CheckKey(ADBFile: PDBFile; Nr: LongInt);
    End;

    PRegDBWin= ^TRegDBWin;
    TRegDBWin= Object(TObject)
      hWindow: THandle;
      SortKey: Integer;
    End;

{*** database object ***}        
    PDatabase= ^TDatabase;
    TDatabase= Object(TObject)
      DataSize: Word;
      LastNr: LongInt;
      Constructor Init(AFileName: PChar; AName: Word);
      Destructor Done; virtual;
      Procedure RefreshBuffer;
      Procedure Register(hWin: THandle; ASortKey: Integer);
      Procedure Unregister(hWin: THandle);
      Function GetSortKey(hWin: THandle): Integer;
      { database functions }
      Function NumRecs(hWin: THandle): Integer;
      Function GetRec(hWin: THandle; N: Integer): Pointer;
      Function CheckRec(hWin: THandle; N: Integer): Pointer;
      Function LockRec(hWin: THandle; N: Integer): Pointer;
      Function UnLockRec(hWin: THandle): Boolean;
      Function UpdateRec(hWin: THandle; N: Integer; Var Data): Boolean;
      Function InsertRec(Var Data): Boolean;
      Function DeleteRec(hWin: THandle; N: Integer): Boolean;
      Function IndexOf(hWin: THandle; RecNr: LongInt): Integer;
      Function GetRecNr(Nr: LongInt): Pointer;
      Function CheckRecNr(Nr: LongInt): Pointer;
     private
      DBFile: PDBFile;
      DBBuffer: PDBBuffer;
      DBIndex: Array[1..5] Of PDBIndex;
      DBWindows: TCollection;
      Procedure ReadBuffer;
      Function GetBufferElement(SortKey, N: Integer): PBufferElement;
      Procedure SendInfoMsg(Action: Word; RecNr: LongInt);
    End;

  procedure InitDB(Var DB: PDatabase; Name: Word; FileName: PChar);
  Procedure GetBtrieveErrorMsg(Code: Integer; Buffer: PChar; BufferMax: Integer);
  Procedure BtrieveErrorMsg(Code: Integer);

Implementation

{
** == TDatabase (Object) ==
**
** Combines TDBFile and TDBBuffer
**
}
  Constructor TDatabase.Init(AFileName: PChar; AName: Word);
  Begin
    TObject.Init;
    DBFile:=New(PDBFile, Init(AFileName, Normal, AName));
    If DBFile=nil Then Fail;
    DataSize:=DBFile^.Specs.RecLen;
    DBBuffer:=nil;
    ReadBuffer;
    If DBBuffer=nil Then Fail;
    FillChar(DBIndex, SizeOf(DBIndex), 0);
    DBWindows.Init(5, 5);
  End;

  Destructor TDatabase.Done;
  Var I: Integer;
  Begin
    DBWindows.Done;
    Dispose(DBFile, Done);
    Dispose(DBBuffer, Done);
    For I:=1 To 5 Do
      If DBIndex[I]<>nil Then Dispose(DBIndex[I], Done);
    TObject.Done;
  End;

  Procedure TDatabase.RefreshBuffer;
  Var I: Integer;
  Begin
    ReadBuffer;
    For I:=1 To 5 Do If DBIndex[I]<>nil Then With DBIndex[I]^ Do
    Begin
      DeleteAll;
      Init(DBFile, I);
      Reread:=True;
    End;
    SendInfoMsg(0, -1);
  End;

  Procedure TDatabase.Register(hWin: THandle; ASortKey: Integer);
  Var R: PRegDBWin;
  Begin
    New(R, Init);
    R^.hWindow:=hWin;
    R^.SortKey:=ASortKey;
    DBWindows.Insert(R);
    If (ASortKey>0) And (DBIndex[ASortKey]=nil) Then
      New(DBIndex[ASortKey], Init(DBFile, ASortKey));
  End;

  Procedure TDatabase.Unregister(hWin: THandle);
  Var
    R: PRegDBWin;
    S: Integer;
    Function IsWin(R: PRegDBWin): Boolean; far;
    Begin
      IsWin:=R^.hWindow=hWin;
    End;
    Function IsSortKey(R: PRegDBWin): Boolean; far;
    Begin
      IsSortKey:=R^.SortKey=S;
    End;
  Begin
    R:=DBWindows.FirstThat(@IsWin);
    If R<>nil Then
    Begin
      S:=R^.SortKey;
      DBWindows.Free(R);
      If (S>0) And (DBWindows.FirstThat(@IsSortKey)=nil) Then
      Begin
        Dispose(DBIndex[S], Done);
        DBIndex[S]:=nil;
      End;
    End;
  End;

  { database operations }
  Function TDatabase.NumRecs(hWin: THandle): Integer;
  Var S: Integer;
  Begin
    S:=GetSortKey(hWin);
    If S>0 Then
      NumRecs:=DBIndex[S]^.Count
    Else
      NumRecs:=DBBuffer^.Count;                    
  End;

  Function TDatabase.GetRec(hWin: THandle; N: Integer): Pointer;
  Var
    S: Integer;
    B: PBufferElement;
  Begin
    S:=GetSortKey(hWin);
    B:=GetBufferElement(S, N);
    If B<>nil Then
      GetRec:=@B^.Data
    Else
      GetRec:=nil;
  End;          

  Function TDatabase.CheckRec(hWin: THandle; N: Integer): Pointer;
  Var
    S: Integer;
    B: PBufferElement;
  Begin
    CheckRec:=nil;
    S:=GetSortKey(hWin);
    B:=GetBufferElement(S, N);
    If B<>nil Then
    Begin
      Move(B^.Nr, DBFile^.KeyBuf, 4);
      BStatus:=DBFile^.BT(BGetEqual, 0);
      If BStatus=0 Then
      Begin
        Move(ExtDBuffer^, B^.Data, DataSize);
        DBFile^.BTRetry(BGetPos, 0);
        Move(ExtDBuffer^, B^.Pos, 4); 
        CheckRec:=@B^.Data;
      End;
    End;
  End;

  Function TDatabase.LockRec(hWin: THandle; N: Integer): Pointer;
  Var
    S: Integer;
    B: PBufferElement;
  Begin
    LockRec:=nil;
    S:=GetSortKey(hWin);
    B:=GetBufferElement(S, N);
    If B<>nil Then
    Begin
      Move(B^.Nr, DBFile^.KeyBuf, 4);
      BStatus:=DBFile^.BTRetry(BGetEqual+200, 0);
      If BStatus=0 Then
      Begin
        Move(ExtDBuffer^, B^.Data, DataSize);
        DBFile^.BT(BGetPos, 0);
        Move(ExtDBuffer^, B^.Pos, 4);
        LockRec:=@B^.Data;
      End;
    End;
  End;

  Function TDatabase.UnlockRec(hWin: THandle): Boolean;
  Begin
    BStatus:=DBFile^.BT(BUnlock, 1);
    UnlockRec:=BStatus=0;
  End;

  Function TDatabase.UpdateRec(hWin: THandle; N: Integer; Var Data): Boolean;
  Var
    S, I: Integer;
    B: PBufferElement; 
  Begin
    UpdateRec:=False;
    S:=GetSortKey(hWin);
    B:=GetBufferElement(S, N);
    If B<>nil Then
    Begin
      Move(B^.Nr, DBFile^.KeyBuf, 4);
      BStatus:=DBFile^.BT(BGetEqual, 0);
      If BStatus=0 Then
      Begin
        Move(Data, B^.Data, DataSize);
        Move(Data, ExtDBuffer^, DataSize);
        BStatus:=DBFile^.BTRetry(BUpdate, 0);
        If BStatus=0 Then
        Begin
          For I:=1 To 5 Do If DBIndex[I]<>nil Then
            DBIndex[I]^.CheckKey(DBFile, B^.Nr);
          SendInfoMsg(db_Updated, B^.Nr);
          UpdateRec:=True;
        End;
      End;
    End;    
  End;

  Function TDatabase.DeleteRec(hWin: THandle; N: Integer): Boolean;
  Var
    S, I: Integer;
    B: PBufferElement;
  Begin
    DeleteRec:=False;
    S:=GetSortKey(hWin);
    B:=GetBufferElement(S, N);
    If B<>nil Then
    Begin
      Move(B^.Nr, DBFile^.KeyBuf, 4);
      BStatus:=DBFile^.BT(BGetEqual, 0);
      If BStatus=0 Then
      Begin
        BStatus:=DBFile^.BTRetry(BDelete, 0);
        If BStatus=0 Then
        Begin
          SendInfoMsg(db_PreDel, B^.Nr);
          DBBuffer^.Delete(B);
          For I:=1 To 5 Do If DBIndex[I]<>nil Then
            DBIndex[I]^.DeleteKey(B^.Nr);                
          SendInfoMsg(db_Deleted, B^.Nr);
          DBBuffer^.FreeItem(B);
          DeleteRec:=True;
        End;
      End;
    End;
  End;

  Function TDatabase.InsertRec(Var Data): Boolean;
  Var
    B: PBufferElement;
    I: Integer;
  Begin
    InsertRec:=False;
    Move(Data, ExtDBuffer^, DataSize);
    BStatus:=DBFile^.BTRetry(BInsert, 0);
    If BStatus=0 Then
    Begin
      Move(ExtDBuffer^, Data, DataSize);
      B:=DBBuffer^.NewElement;
      Move(ExtDBuffer^, B^.Data, DataSize);
      DBFile^.BT(BGetPos, 0);
      Move(ExtDBuffer^, B^.Pos, 4);
      DBBuffer^.Insert(B);
      For I:=1 To 5 Do If DBIndex[I]<>nil Then
        DBIndex[I]^.CheckKey(DBFile, B^.Nr);
      SendInfoMsg(db_Inserted, B^.Nr);
      InsertRec:=True;
    End;
  End;

  Function TDatabase.IndexOf(hWin: THandle; RecNr: LongInt): Integer;
  Var S, I: Integer;
  Begin
    IndexOf:=-1;
    S:=GetSortKey(hWin);
    If S>0 Then
    Begin
      IndexOf:=DBIndex[S]^.IndexOf(Pointer(RecNr));
    End Else
    Begin
      If DBBuffer^.Search(Pointer(RecNr), I) Then IndexOf:=I;
    End;
  End;

  Function TDatabase.GetRecNr(Nr: LongInt): Pointer;
  Var I: Integer;
  Begin
    If DBBuffer^.Search(Pointer(Nr), I) Then
      GetRecNr:=@PBufferElement(DBBuffer^.At(I))^.Data
    Else
      GetRecNr:=nil;
  End;

  Function TDatabase.CheckRecNr(Nr: LongInt): Pointer;
  Var
    B: PBufferElement;
    I: Integer;
  Begin
    Move(Nr, DBFile^.KeyBuf, 4);
    BStatus:=DBFile^.BT(BGetEqual, 0);
    If BStatus=0 Then
    Begin
      If Not DBBuffer^.Search(Pointer(Nr), I) Then
      Begin
        B:=DBBuffer^.NewElement;
        Move(ExtDBuffer^, B^.Data, DataSize);
        DBFile^.BTRetry(BGetPos, 0);
        Move(ExtDBuffer^, B^.Pos, 4);
        DBBuffer^.Insert(B);
      End Else
      Begin
        B:=DBBuffer^.At(I);
        Move(ExtDBuffer^, B^.Data, DataSize);
      End;     
      CheckRecNr:=@B^.Data;
    End Else
    Begin
      If DBBuffer^.Search(Pointer(Nr), I) Then
        DBBuffer^.AtDelete(I);
      CheckRecNr:=nil;
    End;
  End;

  Procedure TDatabase.ReadBuffer;
  Var
    Dlg: PWaitDlg;
  Begin
    { display dialog... }
    if GlbWaitDlg=nil then
    begin
      New(Dlg, Init(Application^.MainWindow, -1, -1, MakeIntResource(LoadingDlg)));
      Application^.MakeWindow(Dlg);
    end else
      Dlg:=GlbWaitDlg;
    If DBBuffer<>nil Then Dispose(DBBuffer, Done);
    New(DBBuffer, Init(DBFile, Dlg));
    if GlbWaitDlg=nil then Dispose(Dlg, Done);
  End;

  Function TDatabase.GetSortKey(hWin: THandle): Integer;
  Var R: PRegDBWin;
    Function IsWin(R: PRegDBWin): Boolean; far;
    Begin
      IsWin:=R^.hWindow=hWin;
    End;
  Begin
    R:=DBWindows.FirstThat(@IsWin);
    If R<>nil Then
      GetSortKey:=R^.SortKey
    Else
      GetSortKey:=0;
  End;

  Function TDatabase.GetBufferElement(SortKey, N: Integer): PBufferElement;
  Var
    I: Integer;
    Nr: LongInt;
    B: PBufferElement;
  Begin
    If SortKey>0 Then
    Begin
      If (N>=0) And (N<DBIndex[SortKey]^.Count) Then
      Begin
        Nr:=LongInt(DBIndex[SortKey]^.At(N));
        If Not DBBuffer^.Search(Pointer(Nr), I) Then
        Begin
          Move(Nr, DBFile^.KeyBuf, 4);
          BStatus:=DBFile^.BT(BGetEqual, 0);
          If BStatus=0 Then
          Begin
            B:=DBBuffer^.NewElement;
            Move(ExtDBuffer^, B^.Data, DataSize);
            DBFile^.BT(BGetPos, 0);
            Move(ExtDBuffer^, B^.Pos, 4);
            DBBuffer^.Insert(B);
            I:=DBBuffer^.IndexOf(B);
          End Else
            I:=-1;
        End;
      End Else
        I:=-1;              
    End Else
      I:=N;
    If (I>=0) And (I<DBBuffer^.Count) Then
      GetBufferElement:=PBufferElement(DBBuffer^.At(I))
    Else
      GetBufferElement:=nil;          
  End;

  Procedure TDatabase.SendInfoMsg(Action: Word; RecNr: LongInt);
  Var A: Word;
    Procedure SendMsg(DB: PRegDBWin); far;
    Begin
      A:=Action;
      if Action<>db_PreDel then
      begin
        if DBIndex[DB^.SortKey]^.Changed then A:=A Or db_Reorder;
        if DBIndex[DB^.SortKey]^.Reread then A:=A Or db_Reread;
      end;
      SendMessage(DB^.hWindow, wm_DBMessage, A, LongInt(@Self));
    End;
  Begin
    LastNr:=RecNr;
    DBWindows.ForEach(@SendMsg);
  End;

{
** == TDBIndex (Object) ==
**
** Handles different sort keys of a database
**
}
  Constructor TDBIndex.Init;
  Var
    Dlg: PWaitDlg;
    I, MaxCount, IncCount: Word;
    P: Pointer;
    acS: Array[0..80] Of Char;

    Procedure AddElement(P: Pointer);
    Var L: LongInt;
    Begin
      Inc(LongInt(P), 4);
      Move(P^, L, 4);
      Insert(Pointer(L));      
    End;

  Begin
    UpdateWindow(hMainWindow);
    TCollection.Init(100, 100);
    SortKey:=ASortKey;
    if GlbWaitDlg=nil then
    begin
      SetCursor(LoadCursor(0, IDC_WAIT));
      New(Dlg, Init(Application^.MainWindow, -1, -1, MakeIntResource(LoadingDlg)));
      Application^.MakeWindow(Dlg);
    end else
      Dlg:=GlbWaitDlg;
    P:=@ADBFile^.Name;
    wvsprintf(acS, GetResString(str_ReadingIndex), P);
    Dlg^.SetText(acS);
    Dlg^.SetPosText(GetResString(str_PleaseWait), 0, 100);
    If Count<>0 Then FreeAll;
    ADBFile^.GetStats;
    MaxCount:=ADBFile^.NumRecs;
    If MaxCount>0 Then
    Begin
      BStatus:=ADBFile^.BT(BGetFirst, SortKey);
      If BStatus=0 Then
      Begin
        Move(ExtDBuffer^.Entire[1], ExtDBuffer^.Entire[5], 4);
        AddElement(@ExtDBuffer^.Entire[1]);
      End;
      { set extractor specs }
      With ADBFile^ Do
      Begin
        Extractor.NumFields:=1;
        Extractor.NumRecords:=SizeOf(ExtDBuffer^) Div (4+6);
        ExtractorSpec^.DeleteAll;
        ExtractorSpec^.Insert(New(PExtSpec, Init(4, 0)));
      End;
      IncCount:=MaxCount Div 10;
      Inc(IncCount);
      { use extended calls to read all records }
      While BStatus=0 Do
      Begin
        BStatus:=ADBFile^.BTExt(BGetNextExt, SortKey);
        P:=@ExtDBuffer^.Repeater;
        Inc(LongInt(P), 2);
        For I:=1 To ExtDBuffer^.NumRecs Do
        Begin
          AddElement(P);
          Inc(LongInt(P), 4+6);
          If (Count Mod IncCount)=0 Then Dlg^.SetPos(Count, MaxCount);
        End;
        Dlg^.SetPos(Count, MaxCount);
      End;
      If BStatus<>9 Then
        BtrieveErrorMsg(BStatus)
      Else
        BStatus:=0;
    End Else
      BStatus:=0;
    if GlbWaitDlg=nil then
    begin
      Dispose(Dlg, Done);
      SetCursor(LoadCursor(0, IDC_ARROW));
    end;
  End;

  Procedure TDBIndex.FreeItem(Item: Pointer);
  Begin
  End;

  Procedure TDBIndex.DeleteKey(Nr: LongInt);
  Begin
    Delete(Pointer(Nr));
  End;

  Procedure TDBIndex.CheckKey(ADBFile: PDBFile; Nr: LongInt);
  Var
    Nr2: LongInt;
    I, I2: Integer;
    Procedure Position;
    Begin
      Move(Nr, ADBFile^.KeyBuf, 4);
      ADBFile^.BT(BGetEqual, 0);
      ADBFile^.BT(BGetPos, 0);
      ADBFile^.BT(BGetDir, SortKey);
    End;
  Begin
    Changed:=False;
    Reread:=False;
    I:=IndexOf(Pointer(Nr));
    Position;
    BStatus:=ADBFile^.BT(BGetPrev, SortKey);
    Move(ExtDBuffer^, Nr2, 4);
    If I<>-1 Then
    Begin
      If BStatus=0 Then
      Begin
        If (I=0) Or (Nr2<>LongInt(At(I-1))) Then
        Begin
          Delete(Pointer(Nr));
          I2:=IndexOf(Pointer(Nr2));
          If I2=-1 Then
          Begin
            Reread:=True;
            DeleteAll;
            Init(ADBFile, SortKey);
          End Else
            AtInsert(I2+1, Pointer(Nr));
          Changed:=True;
        End;
      End Else
      If BStatus=9 Then
      Begin
        If I>0 Then
        Begin
          Delete(Pointer(Nr));
          AtInsert(0, Pointer(Nr));
          Changed:=True;
        End;
      End Else
        BtrieveErrorMsg(BStatus);
    End Else
    Begin
      If BStatus=0 Then
      Begin
        I2:=IndexOf(Pointer(Nr2));
        If I2>=0 Then
          AtInsert(I2+1, Pointer(Nr))
        Else
          Init(ADBFile, SortKey);
      End Else
      If BStatus=9 Then
        AtInsert(0, Pointer(Nr))
      Else
        BtrieveErrorMsg(BStatus);
      Changed:=True;
    End;
  End;

{
** == TDBBuffer (Object) ==
**
** Handles the database's buffer
**
}
  Constructor TDBBuffer.Init(ADBFile: PDBFile; Dlg: PWaitDlg);
  Var
    I, MaxCount, IncCount: Word;
    acS: array[0..80] of Char;
    P: Pointer;

    Procedure AddElement(P: Pointer);
    Var E: PBufferElement;
    Begin
      E:=NewElement;
      Move(P^, E^, ElementSize);
      AtInsert(Count, E);
    End;
      
  Begin
    TSortedCollection.Init(100, 100);
    ElementSize:=ADBFile^.Specs.RecLen+4;
    P:=@ADBFile^.Name;
    wvsprintf(acS, GetResString(str_ReadingDB), P);
    Dlg^.SetText(acS);
    Dlg^.SetPosText(GetResString(str_PleaseWait), 0, 100);
    { prepare buffer }
    If Count<>0 Then FreeAll;
    ADBFile^.GetStats;
    MaxCount:=ADBFile^.NumRecs;
    If MaxCount>0 Then
    Begin
      { get first record from BTrieve }
      BStatus:=ADBFile^.BT(BGetFirst, 0);
      If BStatus=0 Then
      Begin
        Move(ExtDBuffer^.Entire[1], ExtDBuffer^.Entire[5], ElementSize);
        BStatus:=ADBFile^.BT(BGetPos, 0);
        AddElement(@ExtDBuffer^.Entire);
      End;
      { set extractor specs }
      With ADBFile^ Do
      Begin
        Extractor.NumFields:=1;
        Extractor.NumRecords:=SizeOf(ExtDBuffer^) Div (ElementSize+2);
        ExtractorSpec^.DeleteAll;
        ExtractorSpec^.Insert(New(PExtSpec, Init(Specs.RecLen, 0)));
      End;
      IncCount:=MaxCount Div 10;
      Inc(IncCount);
      { use extended calls to read all records }
      While BStatus=0 Do
      Begin
        BStatus:=ADBFile^.BTExt(BGetNextExt, 0);
        P:=@ExtDBuffer^.Repeater;
        Inc(LongInt(P), 2);
        For I:=1 To ExtDBuffer^.NumRecs Do
        Begin
          AddElement(P);
          Inc(LongInt(P), ElementSize+2);
          If (Count Mod IncCount)=0 Then Dlg^.SetPos(Count, MaxCount);
        End;
      End;
      Dlg^.SetPos(Count, MaxCount);
      If BStatus<>9 Then
        BtrieveErrorMsg(BStatus)
      Else
        BStatus:=0;
    End Else
      BStatus:=0;
    If BStatus<>0 Then Fail;
  End;

  Procedure TDBBuffer.FreeItem(Item: Pointer);
  Begin
    FreeMem(Item, ElementSize);
  End;

  Function TDBBuffer.KeyOf(Item: Pointer): Pointer;
  Begin
    KeyOf:=Pointer(PBufferElement(Item)^.Nr);
  End;

  Function TDBBuffer.Compare(Key1, Key2: Pointer): Integer;
  Begin
    If LongInt(Key1)<LongInt(Key2) Then Compare:=-1 Else
      If LongInt(Key1)>LongInt(Key2) Then Compare:=+1 Else
        Compare:=0;
  End;

  Function TDBBuffer.NewElement: PBufferElement;
  Var P: PBufferElement;
  Begin
    GetMem(P, ElementSize);
    NewElement:=P;
  End;

{
** == TDBFile (Object) ==
**
** retrieved from BFileExt, implements BT, BTRetry and BTExt
** methods for database handling
**
}
  Constructor TDBFile.Init(FileName: PChar; OpenMode: Integer; AName: Word);
  Begin
    BFileExt.Init(FileName, OpenMode);
    If BStatus<>0 Then Fail;
    StrCopy(Name, GetResString(AName));
  End;

  Destructor TDBFile.Done;
  Begin
    BFileExt.Close;
    BFileExt.Done;
  End;

  Function TDBFile.BT(OpCode, Key: Integer): Integer;
  Var DBL: Integer;
  Begin
    DBL:=Specs.RecLen;
    If (OpCode=BGetPos) Or (OpCode=BUnlock) Then DBL:=4;
    BT:=Btrv(OpCode, PosBlk, ExtDBuffer^.Entire, DBL, KeyBuf, Key);
  End;

  Function TDBFile.BTRetry(OpCode, Key: Integer): Integer;
  Var
    Code: Integer;
    Cancel: Boolean;
    acS: Array[0..100] Of Char;
  Begin
    Cancel:=False;
    Repeat
      Code:=BT(OpCode, Key);
      If Code<>0 Then
      Begin
        GetBtrieveErrorMsg(Code, acS, SizeOf(acS));
        If acS[0]='?' Then
        Begin
          Cancel:=MessageBox(hMainWindow, @acS[1], Title,
            MB_ICONQUESTION Or MB_RETRYCANCEL)=ID_CANCEL;
        End Else
        Begin
          Cancel:=True;
          MessageBox(hMainWindow, @acS[1], Title,
            MB_ICONHAND Or MB_OK);
        End;      
      End;
    Until (Code=0) Or Cancel;
    BTRetry:=Code;
  End;

  Function TDBFile.BTExt(OpCode, Key: Integer): Integer;
  Begin
    BStatus:=BFileExt.BtExt(OpCode, Key);
    BTExt:=Btrv(OpCode, PosBlk, ExtDBuffer^.Entire, DBufferLen, KeyBuf, Key);
  End;

{
== GetBtrieveErrorMsg (Procedure) ==
}
  Procedure GetBtrieveErrorMsg(Code: Integer; Buffer: PChar; BufferMax: Integer);
  Begin
    LoadString(hInstance, str_Btrieve+Code, Buffer, BufferMax);
    If Buffer^=#0 Then
    Begin
      LoadString(hInstance, str_Btrieve, Buffer, BufferMax);
      wvsprintf(Buffer, Buffer, Code);
    End;      
  End;

{
== BtrieveErrorMsg (Procedure) ==
}
  Procedure BtrieveErrorMsg(Code: Integer);
  Var acS: Array[0..100] Of Char;
  Begin   
    GetBtrieveErrorMsg(Code, acS, 100);
    MessageBox(hMainWindow, @acS[1], Title, MB_ICONHAND Or MB_OK);
  End;

  procedure InitDB(var DB: PDatabase; Name: Word; FileName: PChar);
  var
    acName, acError: array[0..100] of Char;
    P: PChar;
  begin
    New(DB, Init(DatapathFile(FileName), Name));
    if DB=nil then
    begin
      LoadString(hInstance, Name, acName, SizeOf(acName));
      P:=acName;
      GlbError(em_DBServerError, @P);
    end;
  end;

End.
