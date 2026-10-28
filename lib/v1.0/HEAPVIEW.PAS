{ HeapView - free-memory display for Kiosk 1.0 and 1.2.                      }
{                                                                            }
{ Stand-in written in 2026: the original unit is lost. Turbo Pascal 6.0     }
{ ships the same view as THeapView in its Turbo Vision demo unit GADGETS,   }
{ which this unit passes on under the name Kiosk expects.                   }

Unit HeapView;
Interface
  Uses Gadgets;

  Type
    PHeapView= ^THeapView;
    THeapView= Object(Gadgets.THeapView)
    End;

Implementation

End.
