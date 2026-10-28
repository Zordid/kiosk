{ ClkView - clock display for Kiosk 1.0 and 1.2.                             }
{                                                                            }
{ Stand-in written in 2026: the original unit is lost. Turbo Pascal 6.0     }
{ ships the same view as TClockView in its Turbo Vision demo unit GADGETS,  }
{ which this unit passes on under the name Kiosk expects.                   }

Unit ClkView;
Interface
  Uses Gadgets;

  Type
    PClockView= ^TClockView;
    TClockView= Object(Gadgets.TClockView)
    End;

Implementation

End.
