{ KEYAGENT - plays keyboard and mouse commands from a file, for Windows 3.1. }
{                                                                            }
{ Written in 2026 to drive Windows programs in an emulator from outside.    }
{ Start it with Windows (WIN.INI load=). Every half second it looks for     }
{ C:\AUTO\IN.TXT, reads and deletes it, plays the commands through          }
{ KEYHOOK.DLL and then creates C:\AUTO\DONE.TXT. At start it creates        }
{ C:\AUTO\READY.TXT. One command per line:                                   }
{                                                                            }
{   key NAME ...       press keys: enter tab esc space bksp del ins home     }
{                      end pgup pgdn up down left right f1..f12, a letter    }
{                      or a digit; alt+X, ctrl+X, shift+X combine            }
{   text SOME TEXT     type the rest of the line                             }
{   wait MS            pause                                                 }
{   move X Y           move the mouse (screen pixels)                        }
{   click X Y          left click; dblclick X Y, rclick X Y                  }

program KeyAgent;

{$R-,I-}

uses WinTypes, WinProcs, Strings, WinDos;

const
  InFile    = 'C:\AUTO\IN.TXT';
  DoneFile  = 'C:\AUTO\DONE.TXT';
  ReadyFile = 'C:\AUTO\READY.TXT';
  KeyDelay  = 30;

function AddEvent(Msg, ParamL, ParamH, Delay: Word): Boolean; far; external 'KEYHOOK';
procedure ClearEvents; far; external 'KEYHOOK';
function StartPlayback: Boolean; far; external 'KEYHOOK';
function IsPlaying: Boolean; far; external 'KEYHOOK';
function Progress: LongInt; far; external 'KEYHOOK';

var
  Wnd: HWnd;
  Busy: Boolean;
  NextDelay: Word;

procedure Touch(Name: String);
var F: File;
begin
  Assign(F, Name);
  Rewrite(F, 1);
  if IOResult = 0 then Close(F);
end;

function Exists(Name: String): Boolean;
var F: File;
begin
  Assign(F, Name);
  Reset(F, 1);
  if IOResult = 0 then
  begin
    Close(F);
    Exists := True;
  end else
    Exists := False;
end;

procedure Ev(Msg, L, H: Word);
begin
  AddEvent(Msg, L, H, NextDelay);
  NextDelay := 0;
end;

procedure KeyEv(Down, Sys: Boolean; VK: Byte);
var Msg: Word;
begin
  if Sys then
    if Down then Msg := wm_SysKeyDown else Msg := wm_SysKeyUp
  else
    if Down then Msg := wm_KeyDown else Msg := wm_KeyUp;
  Ev(Msg, VK or (MapVirtualKey(VK, 0) shl 8), 1);
  NextDelay := KeyDelay;
end;

procedure Press(VK: Byte; Shift, Ctrl, Alt: Boolean);
begin
  if Shift then KeyEv(True, Alt, vk_Shift);
  if Ctrl then KeyEv(True, Alt, vk_Control);
  if Alt then KeyEv(True, True, vk_Menu);
  KeyEv(True, Alt and not Ctrl, VK);
  KeyEv(False, Alt and not Ctrl, VK);
  if Alt then KeyEv(False, True, vk_Menu);
  if Ctrl then KeyEv(False, Alt, vk_Control);
  if Shift then KeyEv(False, Alt, vk_Shift);
end;

function NamedKey(S: PChar): Integer;
const
  Names: array[0..20] of PChar = ('enter', 'tab', 'esc', 'space', 'bksp',
    'del', 'ins', 'home', 'end', 'pgup', 'pgdn', 'up', 'down', 'left', 'right',
    'return', 'escape', 'backspace', 'delete', 'insert', 'pause');
  Codes: array[0..20] of Byte = (vk_Return, vk_Tab, vk_Escape, vk_Space,
    vk_Back, vk_Delete, vk_Insert, vk_Home, vk_End, vk_Prior, vk_Next, vk_Up,
    vk_Down, vk_Left, vk_Right, vk_Return, vk_Escape, vk_Back, vk_Delete,
    vk_Insert, vk_Pause);
var
  I, Code: Integer;
begin
  NamedKey := -1;
  for I := 0 to 20 do
    if StrIComp(S, Names[I]) = 0 then
    begin
      NamedKey := Codes[I];
      Exit;
    end;
  if ((S[0] = 'f') or (S[0] = 'F')) and (S[1] in ['1'..'9']) then
  begin
    Val(StrPas(S + 1), I, Code);
    if (Code = 0) and (I >= 1) and (I <= 12) then NamedKey := vk_F1 + I - 1;
    Exit;
  end;
  if (S[0] <> #0) and (S[1] = #0) then
    NamedKey := Lo(VkKeyScan(Ord(S[0])));
end;

procedure DoKey(S: PChar);
var
  Shift, Ctrl, Alt: Boolean;
  P: PChar;
  VK: Integer;
begin
  Shift := False; Ctrl := False; Alt := False;
  repeat
    P := StrScan(S, '+');
    if P = nil then Break;
    P^ := #0;
    if StrIComp(S, 'alt') = 0 then Alt := True
    else if StrIComp(S, 'ctrl') = 0 then Ctrl := True
    else if StrIComp(S, 'shift') = 0 then Shift := True;
    S := P + 1;
  until False;
  VK := NamedKey(S);
  if VK >= 0 then Press(VK, Shift, Ctrl, Alt);
end;

procedure DoText(S: PChar);
var
  K: Integer;
begin
  while S^ <> #0 do
  begin
    K := VkKeyScan(Ord(S^));
    if K <> -1 then
      Press(Lo(K), Hi(K) and 1 <> 0, Hi(K) and 2 <> 0, Hi(K) and 4 <> 0);
    Inc(S);
  end;
end;

procedure Mouse(Msg: Word; X, Y: Integer);
begin
  Ev(Msg, X, Y);
  NextDelay := KeyDelay;
end;

function NextWord(var S: PChar; W: PChar): Boolean;
var I: Integer;
begin
  while S^ = ' ' do Inc(S);
  I := 0;
  while (S^ <> ' ') and (S^ <> #0) and (I < 60) do
  begin
    W[I] := S^;
    Inc(I);
    Inc(S);
  end;
  W[I] := #0;
  NextWord := I > 0;
end;

function NextInt(var S: PChar): Integer;
var
  W: array[0..63] of Char;
  I, Code: Integer;
begin
  NextWord(S, W);
  Val(StrPas(W), I, Code);
  if Code <> 0 then I := 0;
  NextInt := I;
end;

procedure DoLine(Line: PChar);
var
  W: array[0..63] of Char;
  X, Y: Integer;
begin
  if not NextWord(Line, W) then Exit;
  if StrIComp(W, 'key') = 0 then
    while NextWord(Line, W) do DoKey(W)
  else if StrIComp(W, 'text') = 0 then
  begin
    if Line^ = ' ' then Inc(Line);
    DoText(Line);
  end
  else if StrIComp(W, 'wait') = 0 then
    NextDelay := NextDelay + NextInt(Line)
  else
  begin
    X := NextInt(Line);
    Y := NextInt(Line);
    Mouse(wm_MouseMove, X, Y);
    if StrIComp(W, 'click') = 0 then
    begin
      Mouse(wm_LButtonDown, X, Y);
      Mouse(wm_LButtonUp, X, Y);
    end
    else if StrIComp(W, 'dblclick') = 0 then
    begin
      Mouse(wm_LButtonDown, X, Y);
      Mouse(wm_LButtonUp, X, Y);
      Mouse(wm_LButtonDown, X, Y);
      Mouse(wm_LButtonUp, X, Y);
    end
    else if StrIComp(W, 'rclick') = 0 then
    begin
      Mouse(wm_RButtonDown, X, Y);
      Mouse(wm_RButtonUp, X, Y);
    end;
  end;
end;

procedure LogState;
var
  F: Text;
  P: LongInt;
begin
  P := Progress;
  Assign(F, 'C:\AUTO\STATE.TXT');
  Rewrite(F);
  if IOResult = 0 then
  begin
    Writeln(F, 'event ', P shr 16, ' of ', P and $FFFF, ' playing=', IsPlaying);
    Close(F);
  end;
end;

procedure CheckInput;
var
  F: Text;
  Line: array[0..255] of Char;
  S: String;
begin
  if Busy then
  begin
    LogState;
    if not IsPlaying then
    begin
      Busy := False;
      Touch(DoneFile);
    end;
    Exit;
  end;
  if not Exists(InFile) then Exit;
  Assign(F, InFile);
  Reset(F);
  if IOResult <> 0 then Exit;
  ClearEvents;
  NextDelay := 0;
  while not Eof(F) do
  begin
    Readln(F, S);
    StrPCopy(Line, S);
    DoLine(Line);
  end;
  Close(F);
  Erase(F);
  if IOResult = 0 then;
  Busy := StartPlayback;
  if not Busy then Touch(DoneFile);
end;

function WndProc(Window: HWnd; Message, wParam: Word; lParam: LongInt): LongInt; export;
begin
  WndProc := 0;
  case Message of
    wm_Timer: CheckInput;
    wm_Destroy: PostQuitMessage(0);
  else
    WndProc := DefWindowProc(Window, Message, wParam, lParam);
  end;
end;

var
  WC: TWndClass;
  Msg: TMsg;
begin
  if HPrevInst <> 0 then Halt;
  FillChar(WC, SizeOf(WC), 0);
  WC.lpfnWndProc := @WndProc;
  WC.hInstance := HInstance;
  WC.lpszClassName := 'KeyAgent';
  RegisterClass(WC);
  Wnd := CreateWindow('KeyAgent', 'KeyAgent', 0, 0, 0, 0, 0, 0, 0, HInstance, nil);
  SetTimer(Wnd, 1, 500, nil);
  Busy := False;
  Touch(ReadyFile);
  while GetMessage(Msg, 0, 0, 0) do
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
end.
