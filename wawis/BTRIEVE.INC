{***************************************************************************}
{* Btrieve Constants and Opcodes                                           *}
{***************************************************************************}
  Const
{      Key Attributes            Key Types          Open Modes              }
{    -------------------     ----------------     ---------------           }
     Duplicates   =   1;     BString    =  0;     Normal    =  0;
     Modifiable   =   2;     BInteger   =  1;     Accel     = -1;
     Binary       =   4;     BFloat     =  2;     ReadOnly  = -2;
     Null         =   8;     BDate      =  3;     Verify    = -3;
     Segmented    =  16;     BTime      =  4;     Exclusive = -4;
     AltCol       =  32;     BDecimal   =  5;
     Descending   =  64;     BMoney     =  6;
     Supplemental = 128;     BLogical   =  7;
     ExtType      = 256;     BNumeric   =  8;
                             BBFloat    =  9;
                             BLString   = 10;
                             BZString   = 11;
                             BUnsBinary = 14;
                             BAutoInc   = 15;

{              Btrieve Op Codes                          Misc                }
{  -----------------------------------------   --------------------------    }
   BOpen      =  0;       BAbortTran   = 21;   Zero        : integer = 0;
   BClose     =  1;       BGetPos      = 22;   NotRequired : integer = 0;
   BInsert    =  2;       BGetDir      = 23;
   BUpdate    =  3;       BStepNext    = 24;  {      Error Codes        }
   BDelete    =  4;       BStop        = 25;  {-------------------------}
   BGetEqual  =  5;       BVersion     = 26;   FileNotOpen      =  3;
   BGetNext   =  6;       BUnlock      = 27;   InvalidKeyNumber =  6;
   BGetPrev   =  7;       BReset       = 28;   DiffKeyNumber    =  7;
   BGetGr     =  8;       BSetOwner    = 29;   InvalidPosition  =  8;
   BGetGrEq   =  9;       BClrOwner    = 30;   EndofFile        =  9;
   BGetLess   = 10;       BCrSuppIdx   = 31;   FileNotFound     = 12;
   BGetLessEq = 11;       BDropSuppIdx = 32;   DataBufferLength = 22;
   BGetFirst  = 12;       BStepFirst   = 33;   RejectCount      = 60;
   BGetLast   = 13;       BStepLast    = 34;   IncorrectDesc    = 62;
   BCreate    = 14;       BStepPrev    = 35;   FilterLimit      = 64;
   BStat      = 15;       BGetNextExt  = 36;   IncorrectFldOff  = 65;
   BExtend    = 16;       BGetPrevExt  = 37;   LostPosition     = 82;
   BSetDosDir = 17;       BStepNextExt = 38;
   BGetDosDir = 18;       BStepPrevExt = 39;
   BBegTran   = 19;       BInsertExt   = 40;
   BEndTran   = 20;       BGetKey      = 50;

{  Extended Ops Comp Codes/Bias           Extended Ops Logic Constants       }
{  -----------------------------       -----------------------------------   }
   Equal      : Byte =   1;            NoFilter   : Integer = 0;
   GreaterThan: Byte =   2;            LastTerm   : Byte    = 0;
   LessThan   : Byte =   3;            NextTermAnd: Byte    = 1;
   NotEqual   : Byte =   4;            NextTermOr : Byte    = 2;
   GrOrEqual  : Byte =   5;
   LessOrEqual: Byte =   6;
   UseAltColl : Byte =  32;
   UseField   : Byte =  64;
   UseNoCase  : Byte = 128;

