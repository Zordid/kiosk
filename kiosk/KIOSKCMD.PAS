{$I KIOSKCO.PAS}
Unit KioskCmds;
Interface
  Uses Views;

  Const
    { Commands }
    cmArtikelstamm     = 1000;
    cmKundenstamm      = 1001;
    cmLieferantenstamm = 1002;
    cmLoadOS           = 1003;
    cmNewOS            = 1004;
    cmAbout            = 1005;
    cmActiveList       = 1006;
    cmCalculator       = 1007;
    cmStammStatistiken = 1008;
    cmDruckOptOS       = 1009;
    cmDruckOptOrder    = 1010;
    cmCurrentOrderList = 1011;
    cmPrintOrder       = 1012;
    cmEditOrder        = 1013;
    cmWGruppen         = 101;
    cmStoreOS          = 102;
    cmEdit             = 103;
    cmInsert           = 104;
    cmDelete           = 105;
    cmSearch           = 106;
    cmBestellung       = 107;
    cmSaveOrder        = 108;
    cmInsSpez          = 109;
    cmDelSpez          = 110;
    cmDelAllSpez       = 111;
    cmCurrView         = 112;
    cmCurrEdit         = 113;
    cmCurrSumUp        = 114;
    cmCurrPrint        = 115;
    cmPrintOS          = 116;
    cmPrintGruppen     = 117;

    OSCmds: TCommandSet= [cmWGruppen, cmStoreOS, cmPrintOS];
    OrderCmds: TCommandSet= [cmSaveOrder, cmInsSpez, cmDelSpez, cmDelAllSpez];
    CurrentCmds: TCommandSet= [cmCurrView, cmCurrEdit, cmDelete, cmCurrPrint];

  Const
    { Broadcasts }
    cmDupKeys          = 10000;
    cmLookforStamm     = 10001;
    cmArtikelBase      = 10002;
    cmKundenBase       = 10003;
    cmLieferBase       = 10004;
    cmStammChanged     = 10005;
    cmOSChanged        = 10006;
    cmLookforOS        = 10007;
    cmLookforOrder     = 10008;
    cmLookforActiveOS  = 10009;
    cmLookforCurrList  = 10010;
    cmDeskTopInsert    = 10011;
    cmLookforOrderFile = 10012;
    cmLookforOrderFileE= 10013;

    { Help contexts }
  Const
    hcListEdit         = 1000;
    hcItem             = 1001;
    hcOSEditor         = 1002;
    hcArtikelUse       = 1003;
    hcBestellung       = 1004;
    hcCurrListDlg      = 1005;
    hcOrderViewer      = 1006;
    hcListUse          = 1007;

Implementation

End.