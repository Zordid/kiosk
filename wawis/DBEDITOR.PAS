Unit DBEditor;
Interface
  Uses
    Objects, OWindows,
    WinTypes, WinProcs, Strings,
    Globals, ListWin, DBServer, Dialogs;

  Type
    TDBEditor= Object(TListViewer)
      DB: PDatabase;
      FocusedNr: LongInt;
      DeleteQuery: Word;
      SortDialog: Word;
      DefaultSort: Integer;
      ClipboardFormat: THandle;
      Constructor Init(AParent: PWindowsObject; ADB: PDatabase);
      Destructor Done; virtual;
      Procedure SetupWindow; virtual;
      Procedure SetFocused(F: Integer); virtual;
      Function GetData(Line: Integer): Pointer; virtual;
      Function EditItem(Data: Pointer): Boolean; virtual;
      Procedure WMInitMenu(Var Msg: TMessage); virtual wm_First+wm_InitMenu;
      Procedure WMLButtonDblClk(Var Msg: TMessage); virtual wm_First+wm_LButtonDblClk;
      Procedure WMDBMessage(Var Msg: TMessage); virtual wm_First+wm_DBMessage;
      Procedure IDMUpdate(Var Msg: TMessage); virtual cm_First+idm_Update;
      Procedure IDMInsert(Var Msg: TMessage); virtual cm_First+idm_Insert;
      Procedure IDMDelete(Var Msg: TMessage); virtual cm_First+idm_Delete;
      Procedure IDMSorting(Var Msg: TMessage); virtual cm_First+idm_Sorting;
      Procedure IDMCopy(Var Msg: TMessage); virtual cm_First+idm_Copy;
     private
      Procedure ClipCopy;
    End;

Implementation

{
** == TDBEditor (Object) ==
**
** database editor object
**
}
  Constructor TDBEditor.Init(AParent: PWindowsObject; ADB: PDatabase);
  Begin
    TListViewer.Init(AParent);
    DB:=ADB;
    FocusedNr:=-1;
    DeleteQuery:=0;
    SortDialog:=0;
    DefaultSort:=1;
    ClipboardFormat:=0;
  End;

  Destructor TDBEditor.Done;
  Begin
    DB^.Unregister(hWindow);
    TListViewer.Done;
  End;

  Procedure TDBEditor.SetupWindow;
  Begin
    DB^.Register(hWindow, DefaultSort);
    Range.Y:=DB^.NumRecs(hWindow);
    TListViewer.SetupWindow;
  End;

  Function TDBEditor.GetData(Line: Integer): Pointer;
  Begin
    GetData:=DB^.GetRec(hWindow, Line);
  End;

  Procedure TDBEditor.SetFocused(F: Integer);
  Var Nr: ^LongInt;
  Begin
    TListViewer.SetFocused(F);
    Pointer(Nr):=GetData(F);
    If Nr<>nil Then FocusedNr:=Nr^ Else FocusedNr:=-1;
  End;

  Function TDBEditor.EditItem(Data: Pointer): Boolean;
  Begin
    Abstract;
  End;

  Procedure TDBEditor.WMInitMenu(Var Msg: TMessage);
  Begin
    if Range.Y>0 then
      EnableMenuItem(hMainMenu, IDM_SELECTALL, MF_ENABLED);
    if (GetFocused<>-1) or (Selected.Count>0) then
      EnableMenuItem(hMainMenu, IDM_COPY, MF_ENABLED);
    EnableMenuItem(hMainMenu, idm_Export, MF_ENABLED);
  End;

  Procedure TDBEditor.WMLButtonDblClk(Var Msg: TMessage);
  Begin
    TListViewer.WMLButtonDblClk(Msg);
    If Msg.lParamLo>XOffset Then IDMUpdate(Msg);
  End;

  Procedure TDBEditor.WMDBMessage(Var Msg: TMessage);
  Var
    Action: Word;
    Reorder, Reread: Boolean;
    I: Integer;
    R: PLongInt;
  Begin
    Action:=Msg.wParam And (Not db_Reorder+db_Reread);
    Reorder:=(Msg.wParam And db_Reorder)<>0;
    Reread:=(Msg.wParam And db_Reread)<>0;
    if Reread then Selected.DeleteAll;
    Case Action Of
      db_Updated:
        Begin
          If Reorder Then
          Begin
            SetFocused(DB^.IndexOf(hWindow, FocusedNr));
            ViewFocused;
            Selected.DeleteAll;
          End;
          RefreshLines;
        End;
      db_Inserted:
        Begin
          Range.Y:=DB^.NumRecs(hWindow);
          SetScrollBars;
          Selected.InsertLine(DB^.IndexOf(hWindow, DB^.LastNr));
          RefreshLines;
        End;
      db_PreDel: Selected.DeleteLine(DB^.IndexOf(hWindow, DB^.LastNr));
      db_Deleted:
        Begin
          Range.Y:=DB^.NumRecs(hWindow);
          SetScrollBars;
          If FocusedNr<>DB^.LastNr Then
            SetFocused(DB^.IndexOf(hWindow, FocusedNr))
          Else
            If GetFocused>=Range.Y Then SetFocused(Range.Y-1);
          ViewFocused;
          RefreshLines;
        End;
    End;
  End;

  Procedure TDBEditor.IDMUpdate(Var Msg: TMessage);
  Var
    Rec, Backup: Pointer;
  Begin
    If GetFocused=-1 Then Exit;
    Backup:=DB^.LockRec(hWindow, GetFocused);
    If Backup<>nil Then
    Begin
      GetMem(Rec, DB^.DataSize);
      Move(Backup^, Rec^, DB^.DataSize);
      If EditItem(Rec) And (Not CompareData(Rec^, Backup^, DB^.DataSize)) Then
        DB^.UpdateRec(hWindow, GetFocused, Rec^);
      DB^.UnlockRec(hWindow);
      FreeMem(Rec, DB^.DataSize);
    End;
  End;

  Procedure TDBEditor.IDMInsert(Var Msg: TMessage);
  Var Rec: Pointer;
  Begin
    GetMem(Rec, DB^.DataSize);
    FillChar(Rec^, DB^.DataSize, 0);
    If EditItem(Rec) Then
    Begin
      DB^.InsertRec(Rec^);
      SetFocused(DB^.IndexOf(hWindow, PLongInt(Rec)^));
      If ViewFocused Then RefreshLines;
    End;
    FreeMem(Rec, DB^.DataSize);
  End;

  Procedure TDBEditor.IDMDelete(Var Msg: TMessage);
  Var
    D: PDeleteDlg;
    Cancel, All: Boolean;
    i: Integer;

    function DoDelete(Line: Integer): Boolean;
    var
      ok: Boolean;
      Cmd: Integer;
      P: Pointer;
      acS: array[0..100] of Char;
    begin
      DoDelete:=False;
      if Cancel then Exit;
      if not All then
      begin
        P:=DB^.GetRec(hWindow, Line);
        if P=nil then Exit;
        Inc(LongInt(P), 4);
        wvsprintf(acS, GetResString(DeleteQuery), P);
        New(D, Init(acS, Selected.Count>0));
        Cmd:=Application^.ExecDialog(D);
        ok:=(Cmd=ID_YES) or (Cmd=ID_ALL);
        All:=Cmd=ID_ALL;
        Cancel:=Cmd=ID_CANCEL;
      end;
      if ok then
      begin
        DB^.DeleteRec(hWindow, Line);
        DoDelete:=True;
      end;
    end;

  Begin
    if (GetFocused=-1) and (Selected.Count=0) then Exit;
    Cancel:=False;
    All:=False;
    if Selected.Count>0 then
    begin
      i:=0;
      while i<Selected.Count do
        if not DoDelete(Integer(Selected.At(i))) then Inc(i);
    end else
      DoDelete(GetFocused);
  End;

  Procedure TDBEditor.IDMSorting(Var Msg: TMessage);
  Var
    Dlg: PSortDlg;
    S: Integer;
  Begin
    If SortDialog=0 Then Exit;
    New(Dlg, Init(@Self, nil, MakeIntResource(SortDialog)));
    S:=DB^.GetSortKey(hWindow);
    Dlg^.Keypath:=@S;
    If (Application^.ExecDialog(Dlg)=ID_OK) And (S<>DB^.GetSortKey(hWindow)) Then
    Begin
      UpdateWindow(hMainWindow);
      DB^.Unregister(hWindow);
      Selected.DeleteAll;
      DB^.Register(hWindow, S);
      If FocusedNr<>-1 Then
      Begin
        SetFocused(DB^.IndexOf(hWindow, FocusedNr));
        ViewFocused;
      End;
      InvalidateRect(hWindow, nil, False);
    End;
  End;

  Procedure TDBEditor.IDMCopy(Var Msg: TMessage);
  Begin
    SetCursor(LoadCursor(0, IDC_WAIT));
    ClipCopy;
    {
    MakeExportColl(Buf, False, False, #9);
    Buf2ClipBoard(False, Buf);
    Buf.Done;
    }
    SetCursor(LoadCursor(0, IDC_ARROW));
  End;

  Procedure TDBEditor.ClipCopy;
  Var
    GlbMem: THandle;
    GlbPtr: Pointer;
    Count: Integer;

    procedure DoCopy(pL: Pointer); far;
    var
      Line: Integer absolute pL;
      Rec: PLongInt;
    begin
      Rec:=DB^.GetRec(hWindow, Line);
      if Rec=nil then Exit;
      Move(Rec^, GlbPtr^, SizeOf(LongInt));
      Inc(LongInt(GlbPtr), SizeOf(LongInt));
    end;

  Begin
    If (ClipboardFormat=0) Or ((Selected.Count=0) And (FocusedNr=-1)) Then Exit;
    Count:=Selected.Count;
    If Count=0 Then Count:=1;
    GlbMem:=GlobalAlloc(gmem_Moveable, Count*4+2);
    If GlbMem<>0 Then
    Begin
      GlbPtr:=GlobalLock(GlbMem);
      If GlbPtr<>nil Then
      Begin
        Move(Count, GlbPtr^, SizeOf(Count));
        Inc(LongInt(GlbPtr), SizeOf(Count)); 
        if Selected.Count>0 then
          Selected.ForEach(@DoCopy)
        else
          Move(FocusedNr, GlbPtr^, SizeOf(LongInt));
        GlobalUnlock(GlbMem);
        If OpenClipboard(hMainWindow) Then
        Begin
          EmptyClipboard;
          SetClipboardData(ClipboardFormat, GlbMem);
          CloseClipboard;
        End Else
          GlobalFree(GlbMem);
      End Else
        GlobalFree(GlbMem);
    End;
  End;

End.