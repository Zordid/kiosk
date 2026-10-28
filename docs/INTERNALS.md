# Internals

How Kiosk and WAWIS work inside, what had to be reconstructed in 2026 to
build and run them again, and how the tools in this repository fit
together. The story and the version history are in the [README](../README.md).

- [Kiosk (DOS)](#kiosk-dos)
- [WAWIS (Windows 3.1)](#wawis-windows-31)
- [Tools](#tools)
- [Public data](#public-data)
- [Known problems](#known-problems)

## Kiosk (DOS)

### Build

- Turbo Pascal 6.0 with Turbo Vision 1.0. `tools/build-tp6.sh TAG OUTDIR`
  builds a tagged version in DOSBox-X with `TPC /M`; the sources are
  converted back to code page 437 first.
- Two programs: `MAKEREZ.EXE` writes the resource file `KIOSK.REZ` (menus,
  status line, dialogs as Turbo Vision streams); `KIOSK.EXE` reads it.
- Borland's demo units `Calc` and `Gadgets` (TP 6.0 `TVDEMOS`) are needed
  and not included.
- `kiosk/FIELDS.PAS` (from 1.2B on) is Borland's Turbo Vision forms demo
  unit with a stub `TRealInputLine` added.

### Reconstructed units (`lib/`)

The shared library Kiosk and Power-Choice used is lost. What the
reconstructions are based on:

| Unit | Evidence | Notes |
|---|---|---|
| `StrObj` | `TOrderItem` writes `SizeOf(record) − SizeOf(PString)` bytes before `Remark.Store`, and the 1992 order files show a constant word there: `TStr` is a `TObject` (VMT word + `P: PString`). Power-Choice puts `PStr` into collections. | `Store` = `WriteStr`; object ID 1000 (Power-Choice `OBJID.TXT`) |
| `DateUtl` | Order files: date = day, month, year; time = hour, minute, second (16-bit words). `OSINDEX.ACT` stores a `TDate` with ID 1001 = 25.11.1993. Dialog field `String[8]`. | `GetStrDate` = `DD.MM.YY`; `TTime` is 3 words, not 4 |
| `StrUtl` | Call sites in Kiosk and Power-Choice (`StrCat(S, T, Max)`, `ChrPosL(S, C, Start)`, `StrUprG`, …) | bodies new |
| `DosTools` | `FileExists`, `FileDelete`, `FileRename`, `FileName` | bodies new |
| `StackDmp`, `StreamEr` | only named in uses clauses | stand-ins: write the runtime error to `KIOSK.ERR`, print stream errors |
| `v1.0/Fields` | 1.0/1.2 call `TDateInputLine.Init(R, True)`, `TIntInputLine.Init(R, Len, Min, Max)`, `TRealInputLine.Init(R, Len, Dec, Min, Max)`; 1.2B aliases `PIntInputLine = PNumInputLine` | the Boolean of `TDateInputLine` and the object IDs 10060–10063 are guesses |
| `v1.0/HeapView`, `ClkView` | 1.0 uses `PHeapView`/`PClockView` | descendants of TP 6.0's `Gadgets` views |

1.0 and 1.2 build with `DATAFILE.PAS` from 1.2B, whose interface matches
their calls.

### Data

- Master data (`ARTIKEL.DAT`, `KUNDEN.DAT`, `LIEFER.DAT`): fixed-size
  records via `DATAFILE.PAS`; record 0 holds the record size and a list of
  free records.
- Indexes in memory: a sorted collection of key + record number, saved as
  a stream (`*.IDX`), rebuilt from the data file when damaged; `/A`
  compacts the article file.
- Orders (`ORDnnnn.ACT`), current orders (`ORDINDEX.ACT`), active order sets
  (`OSINDEX.ACT`), order sets: Turbo Vision streams.
- Customer record `TKundenRec`: Status (LongInt), Name[35], Vorname[20],
  Strasse[60], Ort[60], Telefon[30], 5 × (wholesaler, customer number) —
  254 bytes.
- Printing: Epson ESC/P to LPT1, one page per wholesaler with the kiosk's
  customer number there.

## WAWIS (Windows 3.1)

### Build

- Borland Pascal 7.0 with ObjectWindows. `tools/build-wawis.sh TAG OUTDIR`
  takes `BPC.EXE`, the DPMI runtime, `TPW.TPL`, the OWL units and the
  Windows 3.1 units from the eleven BP 7.0 install disk images
  (`BP7_DISKS`) and compiles with `BPC /CW /$N+` (8087 mode was a global
  IDE option in 1995). No source changes are needed.
- `MDITOOLS.PAS` (toolbar and status line for MDI windows) and
  `WAITDLG.PAS` (progress dialog) are mine, from my unit folder of 1995;
  `CTL3D.PAS` is from c't 11/94.
- `BTPWIN.PAS`/`BTRIEVE.INC`: my Windows version of BTP 2.0
  (John C. Leon, 1993), calling `WBTRCALL.DLL` instead of int 7Bh.
- `UTILS/CONVERT.PAS` needs `WObjects` (Turbo Pascal for Windows 1.x) and
  is not built.

### Running

WAWIS imports `KERNEL USER GDI KEYBOARD MMSYSTEM COMMDLG BWCC WIN87EM
WBTRCALL`. What it needs besides Windows 3.1:

- **`BWCC.DLL` of 1995** (Borland C++ 4.x era). The dialogs use the class
  `BorDlg_Gray`; the 1992 `BWCC.DLL` on the BP 7.0 disks lacks it, and the
  start dialog then fails with OWL's "Error code = -1".
- `CTL3D.DLL` (optional, loaded dynamically).
- **Btrieve.** The original Btrieve for Windows runtime has not been found.
  `lib/wawis/WBTRCALL.PAS` is a requester written in 2026: it forwards
  every call to **Btrieve 5.10a for DOS** (`BTRIEVE.EXE`, Novell 1990),
  loaded before Windows — the way Novell's own small requester DLL worked.
  - Per call it copies position block (128 bytes), key (255 bytes as BTP
    passes it, but never past the end of the caller's segment) and data
    into a buffer below 1 MB (`GlobalDosAlloc`), fills the parameter block
    exactly like Novell's `TUR5BTRV.PAS` (data, position, FCB+38, function,
    key, key length 255, key number, status, interface id `'va'`) and
    issues int 7Bh in real mode via DPMI (int 31h, 0300h).
  - BTP's extended operations (36–38, Get Next Extended …) ask for as many
    records as fit into 64 KB; Btrieve 5.10a answers status 22. The bridge
    restores the descriptor and buffers (the failed call overwrites them)
    and asks for N/2, N/4, … records with a matching buffer length. WAWIS
    reads on until status 9 anyway.
  - Btrieve 5.10a must run without EMS, or it fails under Windows with
    status 57.
  - Get Version (26): BTP passes a data length of 0, but Btrieve writes
    5 bytes (version, revision, product letter) anyway; the bridge copies
    them back, and WAWIS's info box shows "5.10N".
  - If `C:\AUTO\BTRV.LOG` exists, every call is logged (operation, key
    number, status, length, key text; extended descriptors in hex).
- `WAWIS.INI` is read from the Windows directory: paths for program, data,
  order sets and orders; user settings; fax device; sounds. The archived
  one is my development copy (`Debug=1` shows "(debug mode)" in the status
  line and allows a second instance).
- Sound: WAWIS plays its prompts with `sndPlaySound` (keys `Nummer`,
  `Anzahl`, `Fehler`, `Start`, `Stop` in `[Sounds]`; empty in the archived
  INI, so the voice was off on my development machine). `NUMMER.WAV`,
  `ANZAHL.WAV` and `HALT.WAV` are 8-bit mono at 44.1 kHz, too fast for the
  Sound Blaster 1.5 driver of Windows 3.1 (`SNDBLST2.DRV`, at most about
  22 kHz): it refuses them without a message. Copies at 22,050 Hz play.
- Printing: "Drucken" uses the section `[Printer]`, "Faxen" the section
  `[Fax]` (in 1995 an Olivetti JP 350S, a 300 dpi inkjet; there is no
  `[Printer]` section in the archived INI). Both take `device=name,driver,port`
  and optionally `FontName`, `FontSize` (in device pixels), `Zeilen`
  (lines per page), `Oben`, `Links`, and `BarCodePos`, `BarCodeModul`,
  `BarCodeHöhe` for the EAN-13 barcodes (drawn by `BARCODES.PAS`),
  all in device pixels. For DOSBox-X's Epson printer emulation (180 dpi)
  these work: Epson LQ-850 (`EPSON24.DRV` from the Windows disks),
  `FontName=Courier New`, `FontSize=30`, `Zeilen=60`, `BarCodePos=745`,
  `BarCodeModul=2`, `BarCodeHöhe=45`.

### Data

- Tables are Btrieve 5.x files (page size 1024, no `FC` signature):
  `ARTIKEL.WD` (55-byte records, 5 keys, some segmented), `LIEFER.WD`
  (237 bytes, 2 keys), `BETRIEBE.WD`, `EKLISTE.WD`, `GLOBALS.WD`.
  A data page has a 6-byte header and records of physical length
  record length + 8.
- `TBetriebRec` (outlets, 232 bytes): Nr, Name[41], 3 address lines[41],
  Telefon[31], Telefax[31], Kind — zero-terminated strings.
- `DBSERVER.PAS` reads a table into a memory buffer (Get First, then Get
  Next Extended), keeps up to five sort orders, and sends `wm_DBMessage`
  to every registered window on insert, update and delete.
- Orders (`BESTELL/*.WB`) and order sets (`OS/*`) are OWL streams with
  word-length strings.
- Multi-user: records are locked while edited; status 84 gets a retry
  dialog.

## Tools

| Tool | Purpose |
|---|---|
| `tools/build-tp6.sh` | build Kiosk (TP 6.0) |
| `tools/build-wawis.sh` | build WAWIS and the Btrieve bridge (BP 7.0 disk images) |
| `tools/fat12.py` | extract files from floppy images without mounting |
| `tools/run-kiosk.py`, `tools/pick-screens.py` | scripted Kiosk runs in DOSBox-X, screenshots from the text screen |
| `tools/record-kiosk.sh` | the Kiosk tour as an animated GIF (text-screen dumps, Power-Choice's `gif.py`) |
| `tools/frames2gif.py` | an animated GIF from a list of screenshots with display times (the WAWIS recording) |
| `tools/make-demo.sh`, `tools/make-bundle.py` | the js-dos bundle of the browser demo (`docs/play`) |
| `tools/win16/KEYAGENT.PAS`, `KEYHOOK.PAS` | Windows 3.1 agent that plays keyboard and mouse commands from `C:\AUTO\IN.TXT` (journal playback hook in the DLL) |
| `tools/make-public-data.py` | pseudonymised copy of the business data |
| `tools/make-sounds.py` | new start and end sounds for WAWIS (FM synthesis) |
| `tools/social-preview.py` | the GitHub social preview (`docs/social-preview.png`), drawn as a Kiosk text screen |
| `tools/rebuild-btrieve.py` | rebuild the pseudonymised Btrieve tables with `BUTIL` |

The DOSBox-X machine used for WAWIS (486DX2-66, 8 MB, Tseng ET4000 at
1024×768×256, Windows for Workgroups 3.11, Btrieve 5.10a) is private,
because it contains Windows; the agent and the scripts above are what it
is driven with. Lessons from setting it up:

- Windows' own SVGA driver (`SVGA256.DRV`, 1993) knows chipsets, not VESA:
  it works with DOSBox-X's `svga_et4000`, not with `svga_s3`.
- `cycles=max` makes Windows hang at start now and then; a fixed 120,000
  cycles is reliable.
- DOSBox-X's `AUTOTYPE` does not reach Windows programs (and waits at most
  30 s); hence the agent.
- DOSBox-X loads a `dosbox-x.conf` from the current directory; mount the
  drive with `-nocachedir` so files written from outside are seen.
- The clock: `date 08/07/1995` in `AUTOEXEC` (DOSBox-X wants
  `MM/DD/YYYY`; dashes are silently ignored) sets the date Windows and
  WAWIS see.
- Printing: `parallel1=printer` with a `[printer]` section (A4: width 83,
  height 117, 180 dpi, `printoutput=png`) turns LPT1 into an Epson
  ESC/P2 printer whose pages come out as PNG files. It needs TrueType
  files for its built-in fonts (`courier.ttf`, `roman.ttf`,
  `sansserif.ttf` in `fontpath`).

## Public data

The data files in the commits Kiosk 1.2C and WAWIS 1.1 are this public
copy; the originals are kept privately, together with WAWIS's original
start and end sounds. The `wawis/INTRO.WAV` and `wawis/TERMINAT.WAV` of
the present-day commit are new, computed by `tools/make-sounds.py`.

`tools/make-public-data.py PRIVATE OUT` keeps every file's size and
layout: outlets and customers get pseudonyms (kiosk goods as surnames,
a first name with the same initial: "Kandis, Kai"; the same real surname
always gets the same pseudonym, never a longer one, never a name that
occurs in the data), streets become empty, and customers' phone and
fax numbers become numbers that cannot exist: the area code stays, the
rest starts with 0, which the Bundesnetzagentur never assigns after an
area code, and the other digits are made up (wholesalers' numbers become
empty), strings in streams are padded (never shortened), and every
original value is searched for again at the end. Patching a Btrieve file
byte by byte breaks its index pages, though (WAWIS stops with status 2),
so `tools/rebuild-btrieve.py PRIVATE OUT BTRIEVE` then rebuilds every
changed table with Btrieve itself: `BUTIL -SAVE` lists the live records of
the original, each record's pseudonymised version is taken from the same
place in the public copy, and `BUTIL -CLONE` and `-LOAD` make a fresh
table from them. Deleted records and old index pages are gone afterwards;
every text in the rebuilt table must also occur in the public copy.

## Known problems

- Kiosk (original bug): a letter typed into an empty master-data list
  stops the program with runtime error 213 (`STAMM.PAS` reads the focused
  item of an empty collection).
- BTP sizes extended reads for 64 KB results in a 32 KB buffer (see the
  Btrieve bridge).
