unit DlgObj;
interface
  uses Objects, OWindows, ODialogs, WinTypes, WinProcs, BarCodes;

  type
    TValueKind= (kByte, kInteger, kSingle);

    PValueEdit= ^TValueEdit;
    TValueEdit= object(TEdit)
      Kind: TValueKind;
      constructor InitResource(AParent: PWindowsObject; ResourceID: Word; AKind: TValueKind);
      function Transfer(DataPtr: Pointer; TransferFlag: Word): Word; virtual;
      function CanClose: Boolean; virtual;
    end;

    PStdButton= ^TStdButton;
    TStdButton= object(TButton)
      function GetClassName: PChar; virtual;
    end;

    PBGroupBox= ^TBGroupBox;
    TBGroupBox= object(TGroupBox)
      function GetClassName: PChar; virtual;
    end;

  procedure ExchangeChar(S: PChar; C, X: Char);

implementation
  const
    Sizes: array[kByte..kSingle] of Byte= (SizeOf(Byte), SizeOf(Integer), SizeOf(Single));

  function TStdButton.GetClassName: PChar;
  begin
    GetClassName:='Button';
  end;

  function TBGroupBox.GetClassName: PChar;
  begin
    GetClassName:='BorShade';
  end;

  procedure ExchangeChar(S: PChar; C, X: Char);
  begin
    while S^<>#0 do
    begin
      if S^=C then S^:=X;
      Inc(S);
    end;
  end;

  constructor TValueEdit.InitResource;
  begin
    TEdit.InitResource(AParent, ResourceID, 20);
    Kind:=AKind;
  end;

  function TValueEdit.Transfer;
  var
    acS: array[0..20] of Char;
    C: Integer;
  begin
    Transfer:=Sizes[Kind];
    case TransferFlag of
      tf_GetData:
        begin
          GetText(acS, 20);
          if acS[0]=#0 then
          begin
            acS[0]:='0';
            acS[1]:=#0;
          end else
            ExchangeChar(acS, ',', '.');
          case Kind of
            kByte: Val(acS, Byte(DataPtr^), C);
            kInteger: Val(acS, Integer(DataPtr^), C);
            kSingle: Val(acS, Single(DataPtr^), C);
          end;
        end;
      tf_SetData:
        begin
          case Kind of
            kByte: Str(Byte(DataPtr^), acS);
            kInteger: Str(Integer(DataPtr^), acS);
            kSingle: Str(Single(DataPtr^):0:2, acS);
          end;
          ExchangeChar(acS, '.', ',');
          SetText(acS);
        end;
    end;          
  end;

  function TValueEdit.CanClose: Boolean;
  var
    acS: array[0..20] of Char;
    I, C: Integer; B: Byte; S: Single; 
  begin
    CanClose:=False;
    if not TEdit.CanClose then Exit;
    GetText(acS, 20);
    if acS[0]<>#0 then
    begin
      ExchangeChar(acS, ',', '.');
      case Kind of
        kByte: Val(acS, B, C);
        kInteger: Val(acS, I, C);
         kSingle: Val(acS, S, C);
      end;
    end else
      C:=0;
    if C<>0 then
    begin
      SetFocus(hWindow);
      SetSelection(0, 255);
      MessageBeep(0);
    end else
      CanClose:=True;
  end;

end.
