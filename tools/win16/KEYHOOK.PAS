{ KEYHOOK - journal playback of keyboard and mouse events for Windows 3.1.   }
{                                                                            }
{ Written in 2026 for KEYAGENT.EXE, to drive Windows programs in an          }
{ emulator. Windows wants system-wide hooks in a DLL, so the event queue    }
{ and the hook procedure live here.                                          }

library KeyHook;

uses WinTypes, WinProcs, Win31;

const
  MaxEvents = 2000;

type
  TEvent = record
    Msg, ParamL, ParamH: Word;
    Delay: Word;                       { ms before this event }
  end;

  { EVENTMSG of Windows 3.1 journal hooks }
  PJournalMsg = ^TJournalMsg;
  TJournalMsg = record
    Message, ParamL, ParamH: Word;
    Time: LongInt;
  end;

var
  Events: array[0..MaxEvents - 1] of TEvent;
  Count, Current: Integer;
  Due: LongInt;
  DueSet: Boolean;
  Hook: HHook;
  Playing: Boolean;

function PlaybackProc(Code: Integer; wParam: Word; lParam: LongInt): LongInt; export;
var
  E: PJournalMsg;
  Now: LongInt;
begin
  PlaybackProc := 0;
  if Code < 0 then
  begin
    PlaybackProc := CallNextHookEx(Hook, Code, wParam, lParam);
    Exit;
  end;
  case Code of
    hc_GetNext:
      begin
        E := PJournalMsg(lParam);
        Now := GetTickCount;
        if not DueSet then
        begin
          Due := Now + Events[Current].Delay;
          DueSet := True;
        end;
        E^.Message := Events[Current].Msg;
        E^.ParamL := Events[Current].ParamL;
        E^.ParamH := Events[Current].ParamH;
        E^.Time := Now;
        if Due > Now then PlaybackProc := Due - Now;
      end;
    hc_Skip:
      begin
        Inc(Current);
        DueSet := False;
        if Current >= Count then
        begin
          UnhookWindowsHookEx(Hook);
          Playing := False;
        end;
      end;
  end;
end;

{ Queue one event; returns False when the queue is full or playing. }
function AddEvent(Msg, ParamL, ParamH, Delay: Word): Boolean; export;
begin
  AddEvent := False;
  if Playing or (Count >= MaxEvents) then Exit;
  Events[Count].Msg := Msg;
  Events[Count].ParamL := ParamL;
  Events[Count].ParamH := ParamH;
  Events[Count].Delay := Delay;
  Inc(Count);
  AddEvent := True;
end;

procedure ClearEvents; export;
begin
  if not Playing then Count := 0;
end;

{ Start playing the queued events. }
function StartPlayback: Boolean; export;
begin
  StartPlayback := False;
  if Playing or (Count = 0) then Exit;
  Current := 0;
  DueSet := False;
  Playing := True;
  Hook := SetWindowsHookEx(wh_JournalPlayback, PlaybackProc, HInstance, 0);
  if Hook = 0 then Playing := False;
  StartPlayback := Playing;
end;

{ Current event and number of events, for diagnostics. }
function Progress: LongInt; export;
begin
  Progress := LongInt(Current) shl 16 or Word(Count);
end;

function IsPlaying: Boolean; export;
begin
  IsPlaying := Playing;
end;

exports
  PlaybackProc,
  AddEvent,
  ClearEvents,
  StartPlayback,
  IsPlaying,
  Progress;

begin
  Count := 0;
  Playing := False;
end.
