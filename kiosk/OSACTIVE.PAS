{$I KIOSKCO.PAS}
Unit OSActive;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, MsgBox, StdDlg, App,
    StrObj, DateUtl, DosTools,
    KioskCmds, KioskRez, Ordersatz;

  Type
    PActiveOS= ^TActiveOS;
    TActiveOS= Object(TObject)
      Name: TStr;
      Date: PDate;
      FileNo: Word;
      Constructor Init;
      Function Edit: Word;
      Destructor Done; virtual;
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function GetFileName: String;
    End;

    PActiveOSColl= ^TActiveOSColl;
    TActiveOSColl= Object(TCollection)
      Modified: Boolean;
      Counter: Word;
      Constructor Init;
      Procedure Edit;
      Procedure Insert(Item: Pointer); virtual;
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
    End;

    PActiveOSViewer= ^TActiveOSViewer;
    TActiveOSViewer= Object(TListViewer)
      List: PCollection;
      Function DataSize: Word; virtual;
      Procedure GetData(Var Rec); virtual;
      Procedure SetData(Var Rec); virtual;
      Procedure SetRange(ARange: Integer);
      Function GetText(Item, MaxLen: Integer): String; virtual;
      Procedure SelectItem(Item: Integer); virtual;
    End;

    PActiveOSEditor= ^TActiveOSEditor;
    TActiveOSEditor= Object(TDialog)
      Viewer: PActiveOSViewer;
      Procedure HandleEvent(Var Event: TEvent); virtual;
    End;

  Const
    RActiveOS: TStreamRec= (
      ObjType: 2009;
      VmtLink: Ofs(TypeOf(TActiveOS)^);
      Load: @TActiveOS.Load;
      Store: @TActiveOS.Store
    );
    RActiveOSColl: TStreamRec= (
      ObjType: 2010;
      VmtLink: Ofs(TypeOf(TActiveOSColl)^);
      Load: @TActiveOSColl.Load;
      Store: @TActiveOSColl.Store
    );
    RActiveOSViewer: TStreamRec= (
      ObjType: 3006;
      VmtLink: Ofs(TypeOf(TActiveOSViewer)^);
      Load: @TActiveOSViewer.Load;
      Store: @TActiveOSViewer.Store
    );
    RActiveOSEditor: TStreamRec= (
      ObjType: 3007;
      VmtLink: Ofs(TypeOf(TActiveOSEditor)^);
      Load: @TActiveOSEditor.Load;
      Store: @TActiveOSEditor.Store
    );

  Procedure OpenActiveList;
  Procedure CloseActiveList;
  Procedure EditActiveList;
  Function GetActiveOS: String;

Implementation
  Var
    ActiveOSColl: PActiveOSColl;

  Type
    OSViewerRec= Record
      List: PCollection;
      F: Integer;
    End;

{== TActiveOS ==============================================================}

  Constructor TActiveOS.Init;
  Begin
    TObject.Init;
    Name.Init('');
  End;

  Function TActiveOS.Edit: Word;
  Var
    Cmd: Word;
    Dlg: PDialog;
    Data: Record
      N: String[20];
      D: PDate;
    End;
  Begin
    Cmd:=cmCancel;
    Dlg:=PDialog(GetRez('OSDlg'));
    If Dlg<>nil Then
    Begin
      Data.N:=Name.GetStr;
      Data.D:=Date;
      Dlg^.SetData(Data);
      Cmd:=DeskTop^.ExecView(Dlg);
      If Cmd=cmOk Then
      Begin
        Dlg^.GetData(Data);
        Date:=Data.D;
        Name.SetStr(Data.N);
      End;
      Dispose(Dlg, Done);
    End;
    Edit:=Cmd;
  End;

  Destructor TActiveOS.Done;
  Begin
    Name.Done;
    TObject.Done;
  End;

  Constructor TActiveOS.Load(Var S: TStream);
  Begin
    Name.Load(S);
    Date:=PDate(S.Get);
    S.Read(FileNo, SizeOf(FileNo));
  End;

  Procedure TActiveOS.Store(Var S: TStream);
  Begin
    Name.Store(S);
    S.Put(Date);
    S.Write(FileNo, SizeOf(FileNo));
  End;

  Function TActiveOS.GetFileName: String;
  Var F: String;
  Begin
    Str(LongInt(FileNo)+10000:5, F);
    Move(F[2], F[3], 4);
    F[0]:=#6; F[1]:='O'; F[2]:='S';
    F:=F+'.ACT';
    GetFileName:=F;
  End;

{== TActiveOSColl ==========================================================}

  Constructor TActiveOSColl.Init;
  Begin
    TCollection.Init(5, 5);
    Counter:=0;
    Modified:=True;
  End;

  Procedure TActiveOSColl.Insert(Item: Pointer);
  Begin
    TCollection.Insert(Item);
    PActiveOS(Item)^.FileNo:=Counter;
    Inc(Counter);
    If Counter=10000 Then Counter:=0;
  End;

  Constructor TActiveOSColl.Load(Var S: TStream);
  Begin
    TCollection.Load(S);
    S.Read(Counter, SizeOf(Counter));
    Modified:=False;
  End;

  Procedure TActiveOSColl.Store(Var S: TStream);
  Begin
    TCollection.Store(S);
    S.Write(Counter, SizeOf(Counter));
  End;

  Procedure TActiveOSColl.Edit;
  Var
    Dlg: PActiveOSEditor;
    R: OSViewerRec;
  Begin
    Dlg:=PActiveOSEditor(GetRez('ActiveOSEditor'));
    If Dlg<>nil Then
    Begin
      R.List:=@Self;
      R.F:=0;
      Dlg^.SetData(R);
      Dlg^.Viewer:=PActiveOSViewer(Dlg^.Current);
      DeskTop^.ExecView(Dlg);
    End;
  End;

{== TActiveOSViewer ========================================================}

  Procedure TActiveOSViewer.SetRange(ARange: Integer);
  Begin
    TListViewer.SetRange(ARange);
    If ARange=0 Then
      DisableCommands([cmEdit, cmDelete])
    Else
      EnableCommands([cmEdit, cmDelete]);
  End;

  Function TActiveOSViewer.DataSize: Word;
  Begin
    DataSize:=SizeOf(OSViewerRec);
  End;

  Procedure TActiveOSViewer.SetData(Var Rec);
  Begin
    List:=OSViewerRec(Rec).List;
    SetRange(List^.Count);
    FocusItem(OSViewerRec(Rec).F);
  End;

  Procedure TActiveOSViewer.GetData(Var Rec);
  Begin
    OSViewerRec(Rec).List:=List;
    OSViewerRec(Rec).F:=Focused;
  End;

  Function TActiveOSViewer.GetText(Item, MaxLen: Integer): String;
  Var
    S: String;
    I: PActiveOS;
  Begin
    I:=PActiveOS(List^.At(Item));
    FillChar(S[1], Size.X, #32);
    S:=I^.Name.GetStr;
    S[0]:=#22;
    If I^.Date<>nil Then S:=S+I^.Date^.GetStrDate;
    GetText:=S;
  End;

  Procedure TActiveOSViewer.SelectItem(Item: Integer);
  Var E: TEvent;
  Begin
    TListViewer.SelectItem(Item);
    E.What:=evKeyDown;
    E.KeyCode:=kbEnter;
    PutEvent(E);
  End;

{== TActiveOSEditor ========================================================}

  Procedure TActiveOSEditor.HandleEvent(Var Event: TEvent);

    Procedure Ins;
    Var
      OS: POrdersatz;
      Strm: PBufStream;
      IdxF: TResourceFile;
      Name: String;
      N: PActiveOS;
      D: PFileDialog;
      S: Word;
    Begin
      New(D, Init('*.ORD', 'Ordersatz wählen...', '~O~rdersätze', fdOkButton, 101));
      If DeskTop^.ExecView(Application^.ValidView(D))<>cmCancel Then
      Begin
        D^.GetFileName(Name);
        Strm:=New(PBufStream, Init(Name, stOpen, 1024));
        OS:=POrdersatz(Strm^.Get);
        S:=Strm^.Status;
        Dispose(Strm, Done);
        If (S=0) And (OS<>nil) Then
        Begin
          N:=New(PActiveOS, Init);
          If N^.Edit=cmOk Then
          Begin
            ActiveOSColl^.Insert(N);
            Viewer^.SetRange(ActiveOSColl^.Count);
            { OS kopieren }
            Strm:=New(PBufStream, Init(N^.GetFileName, stCreate, 1024));
            IdxF.Init(Strm);
            IdxF.Put(OS, 'OS');
            IdxF.Done;
            ActiveOSColl^.Modified:=True;
          End Else
            Dispose(N, Done);
        End Else
          MessageBox('Ordersatz konnte nicht geladen werden.', nil, mfError+mfOkButton);
        If OS<>nil Then Dispose(OS, Done);
      End;
      Dispose(D, Done);
    End;

    Procedure Del;
    Var
      N: PActiveOS;
      F: String;
    Begin
      N:=PActiveOS(ActiveOSColl^.At(Viewer^.Focused));
      F:=N^.GetFileName;
      If Message(DeskTop, evBroadcast, cmLookforActiveOS, @F)=nil Then
      Begin
        If MessageBox('Ordersatz aus der Liste entfernen ?', nil, mfConfirmation+mfYesNoCancel)=cmYes Then
        Begin
          FileDelete(F);
          ActiveOSColl^.AtFree(Viewer^.Focused);
          Viewer^.SetRange(ActiveOSColl^.Count);
          ActiveOSColl^.Modified:=True;
        End;
      End Else
        MessageBox('Dieser Ordersatz ist wird gerade benutzt und kann daher nicht gelöscht werden.',
          nil, mfInformation+mfOkButton);
    End;

  Begin
    TDialog.HandleEvent(Event);
    If Event.What=evCommand Then
    Begin
      Case Event.Command Of
        cmEdit: If ActiveOSColl^.Count>0 Then
          Begin
            If PActiveOS(ActiveOSColl^.At(Viewer^.Focused))^.Edit=cmOk Then
              ActiveOSColl^.Modified:=True;
          End;
        cmInsert: Ins;
        cmDelete: Del;
        Else Exit;
      End;
      Viewer^.Draw;
      ClearEvent(Event);
    End;
  End;

{== Prozeduren/Funktionen =================================================}

  Procedure OpenActiveList;
  Var Strm: TBufStream;
  Begin
    Strm.Init('OSINDEX.ACT', stOpen, 1024);
    ActiveOSColl:=PActiveOSColl(Strm.Get);
    If Strm.Status<>0 Then
    Begin
      MessageBox('Ordersatz-Aktivliste existiert nicht. Wird neu angelegt!', nil, mfWarning+mfOkButton);
      ActiveOSColl:=New(PActiveOSColl, Init);
    End;
    Strm.Done;
  End;

  Procedure CloseActiveList;
  Var Strm: TBufStream;
  Begin
    If ActiveOSColl^.Modified Then
    Begin
      Strm.Init('OSINDEX.ACT', stCreate, 1024);
      Strm.Put(ActiveOSColl);
      If Strm.Status<>0 Then
        MessageBox('Ordersatz-Aktivliste konnte nicht gesichert werden !', nil, mfError+mfOkButton);
      Strm.Done;
    End;
    Dispose(ActiveOSColl, Done);
  End;

  Procedure EditActiveList;
  Begin
    ActiveOSColl^.Edit;
  End;

  Function GetActiveOS: String;
  Var
    Dlg: PDialog;
    I: Integer;
    P: PActiveOS;
    R: OSViewerRec;
    C: PCollection;
  Begin
    GetActiveOS:='';
    New(C, Init(5, 5));
    For I:=0 To ActiveOSColl^.Count-1 Do
    Begin
      P:=PActiveOS(ActiveOSColl^.At(I));
      If (P^.Date<>nil) And (Today.DaysLeftTill(P^.Date^)<=0) Then
        C^.Insert(P);
    End;
    If C^.Count>1 Then
    Begin
      Dlg:=PDialog(GetRez('ActiveOSSelect'));
      If Dlg<>nil Then
      Begin
        R.List:=C;
        R.F:=0;
        Dlg^.SetData(R);
        If DeskTop^.ExecView(Dlg)=cmOk Then
        Begin
          Dlg^.GetData(R);
          GetActiveOS:=PActiveOS(C^.At(R.F))^.GetFileName;
        End;
        Dispose(Dlg, Done);
      End;
    End Else
    If C^.Count=1 Then
      GetActiveOS:=PActiveOS(C^.At(0))^.GetFileName
    Else
      MessageBox('Keine aktiven Ordersätze sind heute gültig.', nil, mfInformation+mfOkButton);
    C^.DeleteAll;
    Dispose(C, Done);
  End;

Begin
  RegisterType(RDate);
  RegisterType(RActiveOS);
  RegisterType(RActiveOSColl);
  RegisterType(RActiveOSViewer);
  RegisterType(RActiveOSEditor);
End.