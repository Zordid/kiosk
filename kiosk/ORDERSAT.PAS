{$I KIOSKCO.PAS}
Unit Ordersatz;
Interface
  Uses
    Objects, Drivers, Views, Dialogs, MsgBox, App,
    StrObj, StrUtl, DosTools, Printer,
    Drucker, KioskCmds, KioskRez;

  Type
    PGruppe= ^TGruppe;
    TGruppe= Object(TObject)
      Name: TStr;
      Size: Word;
      From, UpTo: Word;
      Constructor Init;
      Destructor Done; virtual;
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function Edit: Word;
    End;

    POrdersatz= ^TOrdersatz;

    PGruppenColl= ^TGruppenColl;
    TGruppenColl= Object(TCollection)
      LastItem: Word;
      Constructor Init;
      Constructor Load(Var S: TStream);
      Procedure Recalc;
      Procedure SearchGruppe(P: Word; Var I: Integer);
      Function Edit(AnOS: POrdersatz): Boolean;
      Procedure Print;
    End;

    PListe= ^TListe;
    TListe= Array[1..1000] Of LongInt;

    TOrdersatz= Object(TObject)
      FName: PString;
      WGruppen: PGruppenColl;
      Liste: PListe;
      Constructor Init;
      Destructor Done; virtual;
      Constructor Load(Var S: TStream);
      Procedure Store(Var S: TStream);
      Function InsertItem(P: Word; DataRef: LongInt): Boolean;
      Procedure DeleteItem(P: Word);
      Function Items: Word;
    End;

    PGruppenViewer= ^TGruppenViewer;
    TGruppenViewer= Object(TListViewer)
      Procedure FocusItem(Item: Integer); virtual;
      Function GetText(Item, MaxLen: Integer): String; virtual;
    End;

    PGruppenDialog= ^TGruppenDialog;
    TGruppenDialog= Object(TDialog)
      OS: POrdersatz;
      Modified: Boolean;
      Procedure HandleEvent(Var Event: TEvent); virtual;
    End;

  Const
    RGruppe: TStreamRec= (
      ObjType: 2006;
      VmtLink: Ofs(TypeOf(TGruppe)^);
      Load: @TGruppe.Load;
      Store: @TGruppe.Store
    );
    RGruppenColl: TStreamRec= (
      ObjType: 2007;
      VmtLink: Ofs(TypeOf(TGruppenColl)^);
      Load: @TGruppenColl.Load;
      Store: @TGruppenColl.Store
    );
    ROrdersatz: TStreamRec= (
      ObjType: 2008;
      VmtLink: Ofs(TypeOf(TOrdersatz)^);
      Load: @TOrdersatz.Load;
      Store: @TOrdersatz.Store
    );
    RGruppenViewer: TStreamRec= (
      ObjType: 3004;
      VmtLink: Ofs(TypeOf(TGruppenViewer)^);
      Load: @TGruppenViewer.Load;
      Store: @TGruppenViewer.Store
    );
    RGruppenDialog: TStreamRec= (
      ObjType: 3005;
      VmtLink: Ofs(TypeOf(TGruppenDialog)^);
      Load: @TGruppenDialog.Load;
      Store: @TGruppenDialog.Store
    );

Implementation

{== TGruppe ===============================================================}

  Constructor TGruppe.Init;
  Begin
    TObject.Init;
    Name.Init('');
  End;

  Function TGruppe.Edit: Word;
  Var
    Dlg: PDialog;
    Cmd: Word;
    Data: Record
      Name: String[30];
      Size: LongInt;
    End;
  Begin
    Data.Name:=Name.GetStr;
    Data.Size:=Size;
    Dlg:=PDialog(GetRez('GruppeDlg'));
    Dlg^.SetData(Data);
    Cmd:=DeskTop^.ExecView(Dlg);
    If Cmd=cmOK Then
    Begin
      Dlg^.GetData(Data);
      StrUprG(Data.Name);
      Name.SetStr(Data.Name);
      Size:=Data.Size;
    End;
    Dispose(Dlg, Done);
    Edit:=Cmd;
  End;

  Destructor TGruppe.Done;
  Begin
    Name.Done;
    TObject.Done;
  End;

  Constructor TGruppe.Load(Var S: TStream);
  Begin
    Name.Load(S);
    S.Read(Size, SizeOf(Size));
  End;

  Procedure TGruppe.Store(Var S: TStream);
  Begin
    Name.Store(S);
    S.Write(Size, SizeOf(Size));
  End;

{== TGruppenColl ==========================================================}

  Constructor TGruppenColl.Init;
  Begin
    TCollection.Init(20, 5);
  End;

  Constructor TGruppenColl.Load(Var S: TStream);
  Begin
    TCollection.Load(S);
    Recalc;
  End;

  Procedure TGruppenColl.Recalc;
  Var
    P, I: Integer;
    G: PGruppe;
  Begin
    P:=1;
    I:=0;
    While I<Count Do
    Begin
      G:=PGruppe(At(I));
      G^.From:=P;
      Inc(P, G^.Size);
      G^.UpTo:=P-1;
      Inc(I);
    End;
    LastItem:=P-1;
  End;

  Procedure TGruppenColl.SearchGruppe(P: Word; Var I: Integer);
  Begin
    I:=Count-1;
    While (I>=0) And (PGruppe(At(I))^.From>P) Do Dec(I);
  End;

  Function TGruppenColl.Edit(AnOS: POrdersatz): Boolean;
  Var
    Dlg: PGruppenDialog;
  Begin
    Dlg:=PGruppenDialog(GetRez('GruppenDlg'));
    Dlg^.OS:=AnOS;
    PGruppenViewer(Dlg^.Current)^.SetRange(Count+1);
    PGruppenViewer(Dlg^.Current)^.FocusItem(0);
    DeskTop^.ExecView(Dlg);
    Edit:=Dlg^.Modified;
    Dispose(Dlg, Done);
  End;

  Procedure TGruppenColl.Print;
  Var I: Integer;
  Begin
    If Count>0 Then
    Begin
      If MessageBox('Die Warengruppen drucken ?', nil, mfConfirmation+mfYesNoCancel)=cmYes Then
      Begin
        If Not InitPrinter(0) Then Exit;
        Writeln(Lst, WideOn+ThickOn, ' Warengruppenliste', ThickOff);
        Writeln(Lst, '-------------------', WideOff);
        Write(Lst, #27'D'#35#47#0);
        For I:=0 To Count-1 Do With PGruppe(At(I))^ Do
        Begin
          Write(Lst, I+1:2, ' ', Name.GetStr, #9);
          Write(Lst, From:4, ' - ', UpTo, #9);
          Writeln(Lst, '(', Size, ')');
        End;
      End;
    End Else
      MessageBox('Die Warengruppenliste ist leer.', nil, mfInformation+mfOkButton);
  End;

{== TGruppenViewer ========================================================}

  Function TGruppenViewer.GetText(Item, MaxLen: Integer): String;
  Var
    GC: PGruppenColl;
    G: PGruppe;
    S: String;
    R: Array[0..2] Of LongInt;
  Begin
    GC:=PGruppenDialog(Owner)^.OS^.WGruppen;
    If Item<GC^.Count Then 
    Begin
      G:=PGruppe(GC^.At(Item));
      PString(R[0]):=G^.Name.P;
      R[1]:=G^.From;
      R[2]:=G^.UpTo;
      FormatStr(S, '%-20s %3d-%4d', R);
      If Length(S)>MaxLen Then S[0]:=Char(MaxLen);
      GetText:=S;
    End Else
      GetText:='';
  End;

  Procedure TGruppenViewer.FocusItem(Item: Integer);
  Begin
    TListViewer.FocusItem(Item);
    If Item<PGruppenDialog(Owner)^.OS^.WGruppen^.Count Then
      EnableCommands([cmEdit, cmDelete])
    Else
      DisableCommands([cmEdit, cmDelete]);
  End;

{== TGruppenDialog ========================================================}

  Procedure TGruppenDialog.HandleEvent(Var Event: TEvent);
  Var
    Viewer: PGruppenViewer;
    Gruppen: PGruppenColl;

    Procedure Ins;
    Var G, L: PGruppe;
    Begin
      G:=New(PGruppe, Init);
      If G^.Edit=cmOK Then
      Begin
        If G^.Size+OS^.Items>1000 Then
        Begin
          MessageBox('Die Anzahl der Artikel würde 1000 überschreiten !', nil,
            mfInformation+mfOkButton);
          Dispose(G, Done);
          Exit;
        End;
        If Viewer^.Focused<Gruppen^.Count Then
        Begin
          L:=PGruppe(Gruppen^.At(Viewer^.Focused));
          Move(OS^.Liste^[L^.From], OS^.Liste^[L^.From+G^.Size],
             (OS^.Items-L^.From+1)*SizeOf(LongInt));
        End;
        Gruppen^.AtInsert(Viewer^.Focused, G);
        Gruppen^.Recalc;
        FillChar(OS^.Liste^[G^.From], G^.Size*SizeOf(LongInt), 0);
        Modified:=True;
      End Else
        Dispose(G, Done);
    End;

    Procedure Edit;
    Var
      G: PGruppe;
      OldSize: Word;
      I, A: Integer;
    Begin
      G:=PGruppe(Gruppen^.At(Viewer^.Focused));
      OldSize:=G^.Size;
      If (G^.Edit=cmOK) And (G^.Size<>OldSize) Then
      Begin
        Modified:=True;
        If (OS^.Items-OldSize)+G^.Size>1000 Then
        Begin
          MessageBox('Die Anzahl der Artikel würde 1000 überschreiten !', nil,
            mfInformation+mfOKButton);
          G^.Size:=OldSize;
          Exit;
        End;
        If G^.Size>OldSize Then
        Begin
          If Viewer^.Focused<Gruppen^.Count Then
            Move(OS^.Liste^[G^.UpTo+1], OS^.Liste^[G^.UpTo+(G^.Size-OldSize+1)],
              (OS^.Items-G^.UpTo)*SizeOf(LongInt));
          FillChar(OS^.Liste^[G^.UpTo+1], (G^.Size-OldSize)*SizeOf(LongInt), 0);
        End Else
        Begin
          I:=G^.UpTo;
          A:=G^.From+G^.Size-1;
          While I>A Do
          Begin
            If OS^.Liste^[I]<>0 Then
            Begin
              If MessageBox('Verkleinerung würde einige Artikel löschen. Fortfahren ?', nil,
                mfConfirmation+mfYesNoCancel)<>cmYes Then
              Begin
                G^.Size:=OldSize;
                Exit;
              End Else
                I:=A;
            End Else Dec(I);
          End;
          If Viewer^.Focused<Gruppen^.Count Then
            Move(OS^.Liste^[G^.UpTo+1], OS^.Liste^[G^.UpTo+1-(OldSize-G^.Size)],
              (OS^.Items-G^.UpTo)*SizeOf(LongInt));
        End;
      End;
    End;

    Procedure Del;
    Var G: PGruppe;
    Begin
      G:=PGruppe(Gruppen^.At(Viewer^.Focused));
      If MessageBox('Die Gruppe %s mitsamt den Artikeln entfernen ?',
        @G^.Name.P, mfConfirmation+mfYesNoCancel)=cmYes Then
      Begin
        If Viewer^.Focused<Gruppen^.Count Then
          Move(OS^.Liste^[G^.UpTo+1], OS^.Liste^[G^.From],
            (OS^.Items-G^.UpTo)*SizeOf(LongInt));
        Gruppen^.AtFree(Viewer^.Focused);
        Modified:=True;
      End;
    End;

  Begin
    TDialog.HandleEvent(Event);
    If (Event.What=evCommand) Then
    Begin
      PView(Viewer):=Last;
      While TypeOf(Viewer^)<>TypeOf(TGruppenViewer) Do PView(Viewer):=Viewer^.Next;
      Gruppen:=OS^.WGruppen;
      Case Event.Command Of
        cmInsert: Ins;
        cmDelete: Del;
        cmEdit: If Viewer^.Focused<Gruppen^.Count Then Edit;
        cmPrintGruppen: Gruppen^.Print;
        Else Exit;
      End;
      Gruppen^.Recalc;
      With Viewer^ Do
      Begin
        SetRange(Gruppen^.Count+1);
        FocusItem(Viewer^.Focused);
        Draw;
        Select;
      End;
      Message(DeskTop, evBroadcast, cmOSChanged, nil);
      ClearEvent(Event);
    End;
  End;

{== TOrdersatz ============================================================}

  Constructor TOrdersatz.Init;
  Begin
    TObject.Init;
    New(WGruppen, Init);
    New(Liste);
    FillChar(Liste^, SizeOf(TListe), 0);
  End;

  Destructor TOrdersatz.Done;
  Begin
    Dispose(Liste);
    Dispose(WGruppen, Done);
  End;

  Constructor TOrdersatz.Load(Var S: TStream);
  Begin
    WGruppen:=PGruppenColl(S.Get);
    New(Liste);
    S.Read(Liste^, SizeOf(TListe));
  End;

  Procedure TOrdersatz.Store(Var S: TStream);
  Begin
    S.Put(WGruppen);
    S.Write(Liste^, SizeOf(TListe));
  End;

  Function TOrdersatz.Items: Word;
  Begin
    Items:=WGruppen^.LastItem;
  End;

  Function TOrdersatz.InsertItem(P: Word; DataRef: LongInt): Boolean;
  Var
    NextGroup, Search: Word;
    I: Integer;
  Begin
    Search:=1;
    While (Search<Items) And (Liste^[Search]<>DataRef) Do Inc(Search);
    If (Search<Items) And (MessageBox('Artikel schon im Ordersatz vorhanden. '+
      'Trotzdem einfügen?', nil, mfConfirmation+mfYesNoCancel)<>cmYes) Then
    Begin
      InsertItem:=False;
      Exit;
    End Else
      InsertItem:=True;
    Search:=P;
    WGruppen^.SearchGruppe(P, I);
    NextGroup:=PGruppe(WGruppen^.At(I))^.UpTo+1;
    While (Search<NextGroup) And (Liste^[Search]<>0) Do Inc(Search);
    If Search<NextGroup Then
      Move(Liste^[P], Liste^[P+1], (Search-P)*SizeOf(LongInt))
    Else
    Begin
      If (Items<1000) Then
      Begin
        Move(Liste^[P], Liste^[P+1], (Items-P+1)*SizeOf(LongInt));
        Inc(PGruppe(WGruppen^.At(I))^.Size);
        WGruppen^.Recalc;
      End Else
      Begin
        MessageBox('Kann Gruppe nicht mehr vergrößern.', nil, mfInformation+mfOKButton);
        Exit;
      End;
    End;
    Liste^[P]:=DataRef;
  End;

  Procedure TOrdersatz.DeleteItem(P: Word);
  Var
    NextGroup, Search: Word;
    I: Integer;
  Begin
    Search:=P;
    WGruppen^.SearchGruppe(P, I);
    NextGroup:=PGruppe(WGruppen^.At(I))^.UpTo+1;
    If Liste^[P]<>0 Then
    Begin
      While (Search<NextGroup) And (Liste^[Search]<>0) Do Inc(Search);
      Move(Liste^[P+1], Liste^[P], (Search-P-1)*SizeOf(LongInt));
      Liste^[Search-1]:=0;
    End Else
    Begin
      While (Search<NextGroup) And (Liste^[Search]=0) Do Inc(Search);
      If Search<NextGroup Then
        Move(Liste^[Search], Liste^[Search-1], (NextGroup-Search)*SizeOf(LongInt));
      Liste^[NextGroup-1]:=0;
    End;
  End;

Begin
  RegisterType(RGruppe);
  RegisterType(RGruppenColl);
  RegisterType(ROrdersatz);
  RegisterType(RGruppenViewer);
  RegisterType(RGruppenDialog);
End.