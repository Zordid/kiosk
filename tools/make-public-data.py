"""Make a public copy of the Kiosk and WAWIS data without personal data.

usage: python3 -I tools/make-public-data.py PRIVATE OUT [--report]

  PRIVATE  the original files in the repository's layout (kiosk/TEST,
           wawis/DATEN, wawis/BESTELL, wawis/OS, ...), kept outside the
           repository; may contain redact.txt with further literal strings
           (one per line) to be overwritten with x of the same length
  OUT      new directory for the public copy, in the same layout
  --report print every replacement (contains the private data: don't
           save the output in the repository)

Every file keeps its size and layout, so the programs can still read it.

1. Outlets of WAWIS (wawis/DATEN/BETRIEBE.WD) are rewritten record by
   record: a person's name becomes a funny one ("Brause, Berta": kiosk
   goods as surnames, a first name with the same initial; a town or a
   customer number after it stays), the contact line too, street becomes
   empty, phone and fax get numbers that cannot exist (see FakePhones),
   postcode and town stay. Each field is cleared up
   to its end, including leftovers of older entries behind the zero byte.
2. Customers in Kiosk's order files get funny names too, an empty street
   and a fake phone number.
3. Wholesalers (LIEFER.DAT, LIEFER.WD): names stay, streets become empty,
   phone and fax numbers fake ones as above; in Kiosk's LIEFER.DAT a
   four-digit postcode gets the W- or O- prefix of 1990-1993.
4. All these values (of three characters or more) are then replaced
   wherever else they occur as a whole field (Btrieve index pages, orders,
   order sets), with the same length:
   length-prefixed strings are padded with spaces, zero-terminated ones
   with zeros.
5. In the files that hold personal data, any surname that is still left
   (in leftovers, index pages, or texts) is overwritten with x, and so are
   phone numbers.
6. Files listed in EXCLUDE are not copied.

At the end, every original value and name is searched for again in all
files, and phone numbers in the personal files; anything found is listed
and the exit code is 1.

Btrieve keeps copies of key values in its index pages; they are changed
too, which breaks the Btrieve files. tools/rebuild-btrieve.py rebuilds
them afterwards with Btrieve itself.
"""
import random, re, shutil, sys
from pathlib import Path

EXCLUDE = {'wawis/INTRO.WAV', 'wawis/TERMINAT.WAV', 'redact.txt'}
OUTLETS = 'wawis/DATEN/BETRIEBE.WD'
WHOLESALERS = {'kiosk/TEST/LIEFER.DAT', 'wawis/DATEN/LIEFER.WD'}
KIOSK_WHOLESALERS = 'kiosk/TEST/LIEFER.DAT'
LFR_REC = 234            # TLieferantenRec: Status, Nr, Name[35], Short[5], Strasse, Ort[60], Telefon, Telefax[30]
PERSONAL = re.compile(r'wawis/DATEN/BETRIEBE\.WD|wawis/BESTELL/|kiosk/TEST/(KUNDEN|ORD|OS)')
CUSTOMERS = re.compile(r'kiosk/TEST/(KUNDEN\.DAT|ORD.*\.ACT|ORDINDEX\.ACT)$')
GENERIC = {'kiosk', 'imbiss', 'imbiß', 'quickbox', 'gmbh', 'tankstelle', 'bahnhof', 'markt'}

PHONE = re.compile(r'^[\d\s()/+\-.]*\d[\d\s()/+\-.]*$')
PHONE_IN_TEXT = re.compile(rb'\(?0\d{2,5}\)? ?[-/] ?\d{3,}|\(0\d{2,5}\)\d{4,}|\b\d{3,5} - \d{3,}')
POSTCODE_TOWN = re.compile(r'^(?:[OW]-)?\d{4,5} \D')
STREET = re.compile(r'(?i)(str\.|straße|strasse|weg\b|platz|allee|gasse|ring\b|damm|siedlung|chaussee)|^\D+ \d+\s*[a-z]?$')
PERSON = re.compile(r',|&|\bGbR\b')
PERSON_NAME = re.compile(r"^[^\W\d_][^\W\d_'-]+, [A-ZÄÖÜ][^\W\d_]+|^[^\W\d_]+ & [^\W\d_]+.*\bGbR\b")


def codepage(rel):
    return 'cp437' if rel.startswith('kiosk/') else 'cp1252'


def printable(bs, cp):
    try:
        s = bs.decode(cp)
    except UnicodeDecodeError:
        return None
    return s if all(c.isprintable() for c in s) else None


def c_strings(b, cp):
    for m in re.finditer(rb'[\x20-\x7e\xc0-\xfe]{3,}(?=\x00)', b):
        s = printable(m.group(), cp)
        if s:
            yield s


def pascal_strings(b, cp, width=1):
    """Strings with a length byte (Turbo Pascal) or a length word (WAWIS's streams)."""
    for i in range(len(b) - 2 - width):
        n = b[i] if width == 1 else b[i] | b[i + 1] << 8
        if 3 <= n <= 120 and i + width + n <= len(b):
            s = printable(b[i + width:i + width + n], cp)
            if s and s.strip() == s:
                yield s


def is_phone(s):
    return bool(PHONE.match(s)) and sum(c.isdigit() for c in s) >= 5


class FakePhones:
    """A real number -> a number that cannot exist: the area code stays (it
    only names the town), the subscriber number starts with 0, which the
    Bundesnetzagentur never assigns after an area code, and the other digits
    are made up (counter-seeded, never derived from the real digits).
    Same length and layout as the original."""
    def __init__(self):
        self.fakes = {}

    def __call__(self, s):
        if s not in self.fakes:
            m = re.match(r'(\s*\(?0\d{2,5}\)?\s*[-/]?\s*)(\d.*)$', s)
            head, tail = m.groups() if m else ('', s)
            rnd = random.Random(len(self.fakes) + 1993)
            out, first = [], True
            for c in tail:
                out.append(('0' if first else str(rnd.randrange(10))) if c.isdigit() else c)
                first &= not c.isdigit()
            self.fakes[s] = head + ''.join(out)
        return self.fakes[s]

    def covers(self, found):
        return any(found in f.encode('ascii', 'replace') for f in self.fakes.values())


def is_street(s):
    return not POSTCODE_TOWN.match(s) and bool(STREET.search(s))


def words(s, n=4):
    return {w for w in re.findall(r'[^\W\d_]{%d,}' % n, s) if w.lower() not in GENERIC}


# Pseudonyms: kiosk goods as surnames, old-fashioned first names that start
# with the same letter ("Brause, Berta"). Never longer than the original.
SURNAMES = """
    Eis Tee Rum Keks Senf Limo Sekt Grog Mett Brot Salz Zimt Reis Nuss Bier
    Saft Hefe Kakao Mokka Lolli Toast Quark Wurst Sahne Bowle Torte Milch
    Feige Möhre Gurke Flips Chips Mampf Brühe Sülze Sirup Brause Waffel Brezel
    Bonbon Kandis Pommes Nougat Punsch Zucker Muffin Krümel Brösel Kuchen
    Semmel Knödel Puffer Toffee Kruste Rosine Dattel Graupe Happen Lakritz
    Knusper Knabber Krokant Praline Sprudel Pfeffer Krapfen Bulette Schmalz
    Strudel Kringel Zwiebel Pudding Gummibär Puffreis Zwieback Marzipan
    Karamell Kaugummi Rollmops Mohrrübe Bockwurst Senfgurke Bratwurst
    Leberkäse Lebkuchen Weingummi Mausespeck Salzstange Schaumkuss Frikadelle
    Currywurst Brausestab Butterkeks Erdnussflip Zuckerwatte Kaffeesahne
    Pfefferminz Kokosflocke Waffelbruch Kirschlolli Bienenstich Spekulatius
    Liebesperle Brausepulver Schokoriegel Gummibärchen Mettbrötchen
    Kirschkuchen Kartoffelchip Wackelpudding Karamellbonbon Mandelhörnchen
    Streuselkuchen Lakritzschnecke Puddingschnecke""".split()
FIRST_NAMES = """
    Bea Bodo Benno Berta Bruno Bernd Beate Bärbel Bettina Kai Kurt Karl Käthe
    Konrad Karin Kunigunde Lea Lutz Lore Lotte Lothar Liesel Leopold Mia Max
    Moni Manni Margot Mechthild Pit Paul Paula Petra Peter Philippa Quirin
    Sepp Susi Siggi Sabine Sieglinde Tom Toni Tina Theo Trude Thekla Willi
    Wilma Werner Waltraud Zita Zenzi Gert Grete Gisela Gustav Egon Erna Eva
    Elfriede Rudi Rosi Rolf Renate Heinz Hilde Horst Hubert Fritz Frieda Ferdi
    Mausi Nelly Nobbi Norbert Otto Olga Edeltraud Dieter Dörte Conny Carla
    Ida Ina Inge Udo Ute Uwe""".split()
KEEP = {'gbr', 'gmbh', 'ohg', 'kg', 'und', 'nr', 'u'}


class FunnyNames:
    """Same surname -> same pseudonym, however the name is written; first
    names follow the initial of the person's new surname."""
    def __init__(self, avoid):
        self.avoid = {w.lower() for w in avoid}
        self.surnames, self.first, self.used = {}, {}, set()

    def surname(self, w):
        if w.lower() not in self.surnames:
            free = [s for s in SURNAMES if s.lower() not in self.avoid and s not in self.used]
            fits = sorted((s for s in free if len(s) <= len(w)), key=len, reverse=True)
            pick = fits[0] if fits else free[0]           # the longest that fits
            self.surnames[w.lower()] = pick[:len(w)]
            self.used.add(pick)
        return self.surnames[w.lower()]

    def first_name(self, w, initial, taken):
        key = (w.lower(), initial)
        if key not in self.first:
            ok = [f for f in FIRST_NAMES if len(f) <= len(w) and f.lower() not in self.avoid]
            same = [f for f in ok if f[0] == initial]
            pool = [f for f in same if f not in taken] or same or ok or [initial[:len(w)]]
            self.first[key] = pool[len(self.first) % len(pool)]
        return self.first[key]

    def person(self, name):
        """'Surname, Firstname', 'A & B GbR, Firstname', 'A-B, C/ D-E', ..."""
        out, initial, comma = [], 'B', False
        for tok in re.split(r'([^\W\d_]+)', name):
            if not tok or not tok[0].isalpha() or tok.lower() in KEEP or tok.lower() in GENERIC:
                comma |= ',' in tok
                out.append(tok)
            elif not comma:
                out.append(self.surname(tok))
                initial = out[-1][0]
            else:
                out.append(self.first_name(tok, initial, out))
        return ''.join(out)

    def words(self):
        return set(self.surnames.values()) | set(self.first.values())


def outlet_records(b):
    """WAWIS's TBetriebRec: Nr, Name[41], Anschrift[3][41], Telefon[31], Telefax[31], Kind.

    BETRIEBE.WD is a Btrieve file: the file header gives the page size
    (offset 8) and the physical record length (offset 24); a data page has a
    6-byte header followed by the records. Yields (offset, fields) for every
    record position of every data page; fields is None for a position that
    holds no live record (a deleted one, with its old data still in it),
    else [(slot offset, slot size, text), ...], text ending at the first
    zero byte (anything after it in the slot is a leftover)."""
    page = int.from_bytes(b[8:10], 'little')
    reclen = int.from_bytes(b[24:26], 'little')
    slots = ((4, 41), (45, 41), (86, 41), (127, 41), (168, 31), (199, 31))

    def parse(p):
        vals = []
        for off, size in slots:
            field = b[p + off:p + off + size]
            end = field.find(0)
            s = printable(field[:end], 'cp1252') if end >= 0 else None
            if s is None:
                return None
            vals.append((p + off, size, s))
        return vals if len(vals[0][2]) >= 3 and vals[0][2][0].isalpha() else None

    for base in range(page, len(b), page):
        positions = range(base + 6, base + page - reclen + 1, reclen)
        records = [(p, parse(p)) for p in positions]
        if any(v for _, v in records):          # a data page
            yield from records


def customer_records(b):
    """Kiosk's TKundenRec: Name[35], Vorname[20], Strasse[60], Ort[60], Telefon[30]."""
    fields = ((0, 35), (36, 20), (57, 60), (118, 60), (179, 30))
    for p in range(len(b) - 210):
        vals = []
        for off, mx in fields:
            n = b[p + off]
            s = printable(b[p + off + 1:p + off + 1 + n], 'cp437') if n <= mx else None
            if s is None:
                break
            vals.append(s)
        else:
            name, vorname, strasse, ort, telefon = vals
            if (re.fullmatch(r"[^\W\d_][^\W\d_ .'-]*(?:[ .'-]+[^\W\d_]+)*", name) and POSTCODE_TOWN.match(ort)
                    and (not telefon or is_phone(telefon)) and (not strasse or is_street(strasse))):
                yield vals


def fit(b, pos, old, new):
    """Write new over old at pos if old is a whole field there.

    The length never changes: strings in streams are followed directly by
    the next data, so a length-prefixed string is padded with spaces and a
    zero-terminated one with zeros."""
    new = new[:len(old)]
    end = pos + len(old)
    if pos > 0 and b[pos - 1] == len(old) or \
            pos > 1 and b[pos - 2:pos] == len(old).to_bytes(2, 'little'):
        b[pos:end] = new.ljust(len(old), b' ')
    elif (pos == 0 or b[pos - 1] in (0, 0xFF)) and (end == len(b) or b[end] == 0):
        b[pos:end] = new + bytes(len(old) - len(new))
    else:
        return False
    return True


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    report = '--report' in sys.argv
    src, dest = Path(args[0]), Path(args[1])
    if dest.exists():
        sys.exit(f'{dest} exists')
    files = sorted(p.relative_to(src).as_posix() for p in src.rglob('*')
                   if p.is_file() and p.name != '.DS_Store')
    data = {r: bytearray((src / r).read_bytes()) for r in files if r not in EXCLUDE}
    log = (lambda *a: print(*a)) if report else (lambda *a: None)

    towns = set()
    for r, b in data.items():
        for s in c_strings(b, codepage(r)):
            if POSTCODE_TOWN.match(s):
                towns.add(s.split(' ', 1)[1].strip())
    towns_by_length = sorted(towns, key=len, reverse=True)

    mapping, parts, names = {}, {}, set()      # value -> public value; name -> pseudonym

    # real names, which must never come out as pseudonyms
    real = set()
    if OUTLETS in data:
        for _, vals in outlet_records(data[OUTLETS]):
            for _, _, s in (vals or [])[:2]:
                real |= set(re.findall(r'[^\W\d_]+', s))
    for r, b in data.items():
        if CUSTOMERS.match(r):
            for name, vorname, *_ in customer_records(b):
                real |= set(re.findall(r'[^\W\d_]+', name + ' ' + vorname))
    funny = FunnyNames(real)
    phones = FakePhones()

    # 1. outlets, record by record

    def pseudonym(s):
        cut = len(s)
        m = re.search(r'\s+Nr\.?\s*\d+$', s)
        if m:
            cut = m.start()
        for t in towns_by_length:
            if s[:cut].endswith(' ' + t):
                cut -= len(t) + 1
        name = s[:cut].rstrip(' ,/')
        parts[name] = funny.person(name)
        names.update(words(name))
        return parts[name] + s[len(name):]

    if OUTLETS in data:
        b = data[OUTLETS]
        for p, vals in outlet_records(b):
            if vals is None:                    # deleted record: keep only its first 4 bytes
                b[p + 4:p + 230] = bytes(226)
                log(f'{OUTLETS} @{p}: cleared')
                continue
            new = []
            for i, (off, size, s) in enumerate(vals):
                if i == 0:
                    v = pseudonym(s) if PERSON.search(s) else s
                elif i == 1:
                    v = s if not s or re.match(r'(?i)(kiosk|quickbox|imbi)', s) or s.strip() in towns else pseudonym(s)
                elif i in (2, 3):
                    v = s if POSTCODE_TOWN.match(s.strip()) or s.strip() in towns else ''
                else:                                   # phone and fax
                    v = phones(s) if is_phone(s) else ''
                if s and v != s and not s.startswith('\xff'):
                    mapping.setdefault(s, v)
                enc = v.encode('cp1252')[:size - 1]
                b[off:off + size] = enc + bytes(size - len(enc))
                new.append(v)
            log(f'{OUTLETS} @{p}: {[x[2] for x in vals]} -> {new}')

    # 2. Kiosk's customers
    for r, b in data.items():
        if CUSTOMERS.match(r):
            for name, vorname, strasse, ort, telefon in customer_records(b):
                new_name, _, new_vorname = funny.person(f'{name}, {vorname}').partition(', ')
                new_name, new_vorname = new_name.ljust(len(name)), new_vorname.ljust(len(vorname))
                names.update(words(name, 3) | words(vorname, 3))
                mapping.setdefault(name, new_name)
                if vorname:
                    mapping.setdefault(vorname, new_vorname)
                    mapping.setdefault('.' + name + '\0' + vorname, '.' + new_name + '\0' + new_vorname)
                if strasse:
                    mapping[strasse] = ''
                if telefon:
                    mapping[telefon] = phones(telefon)

    # 3. wholesalers
    for r in sorted(WHOLESALERS & data.keys()):
        cp = codepage(r)
        for s in sorted(set(c_strings(data[r], cp)) | set(pascal_strings(data[r], cp))):
            s = s.lstrip('\xff')
            if is_phone(s):
                mapping[s] = phones(s)
            elif is_street(s):
                mapping[s] = ''

    # article names, which must never be taken for people
    products = set()
    for r, b in data.items():
        if re.search(r'ARTIKEL|EKLISTE', r):
            products |= set(c_strings(b, codepage(r))) | set(pascal_strings(b, codepage(r)))

    # the outlets in WAWIS's orders, maybe with another town after the name
    for r, b in data.items():
        if r.startswith('wawis/') and r != OUTLETS:
            for s in sorted(set(pascal_strings(b, 'cp1252', 2)) | set(c_strings(b, 'cp1252'))):
                for name in sorted(parts, key=len, reverse=True):
                    if s == name or s.startswith(name + ' ') or s.startswith(name + ','):
                        mapping.setdefault(s, parts[name] + s[len(name):])
                        break
                else:
                    if PERSONAL.match(r) and PERSON_NAME.match(s) and s not in products:   # an outlet no longer in BETRIEBE.WD
                        mapping.setdefault(s, pseudonym(s))

    names -= {w for t in towns for w in words(t)}
    literals = []
    if (src / 'redact.txt').exists():
        literals = [l for l in (src / 'redact.txt').read_text().splitlines() if l.strip()]

    # 4. replace everywhere, 5. scrub what is left in the personal files
    count = 0
    for r, b in data.items():
        cps = [codepage(r)] if re.search(r'\.(DAT|IDX|ACT|ORD|WD|WB|OS|OSA|OSX|OSL)$', r) else ['cp1252', 'utf-8']
        for cp in cps:
            for old, new in sorted(mapping.items(), key=lambda kv: -len(kv[0])):
                if len(old.strip()) < 3:        # a stray letter in a record, not worth a search
                    continue
                ob, nb = old.encode(cp, 'replace'), new.encode(cp, 'replace')
                pos = b.find(ob)
                while pos >= 0:
                    if fit(b, pos, ob, nb):
                        count += 1
                        log(f'{r}: {old!r} -> {new!r}')
                    pos = b.find(ob, pos + 1)
            for lit in literals:
                ob = lit.encode(cp, 'replace')
                for m in list(re.finditer(re.escape(ob), b)):
                    b[m.start():m.end()] = b'x' * len(ob)
                    count += 1
            if PERSONAL.match(r):
                for w in names:
                    for m in list(re.finditer(rb'(?<![^\W\d_])' + re.escape(w.encode(cp, 'replace'))
                                              + rb'(?![^\W\d_])', b)):
                        b[m.start():m.end()] = b'x' * (m.end() - m.start())
                        count += 1
                        log(f'{r}: scrubbed {w!r}')
                for m in list(PHONE_IN_TEXT.finditer(b)):
                    if phones.covers(m.group()):
                        continue
                    b[m.start():m.end()] = b'x' * (m.end() - m.start())
                    count += 1
                    log(f'{r}: scrubbed phone {m.group()!r}')

    # the index pages of the outlet file hold copies and fragments of keys;
    # everything there that is not public already becomes x
    if OUTLETS in data:
        b = data[OUTLETS]
        page = int.from_bytes(b[8:10], 'little')
        data_pages = {p // page for p, _ in outlet_records(b)}
        public = {v for v in mapping.values() if v} | towns | funny.words() | {'Quickbox', 'Kiosk', 'GmbH', 'Franchising'}
        for base in range(page, len(b), page):
            if base // page in data_pages:
                continue
            for m in list(re.finditer(rb'[\x20-\x7e\xc0-\xfe]{2,}', b[base:base + page])):
                s = m.group().decode('cp1252').strip()
                if s and not POSTCODE_TOWN.match(s) and not any(w.strip(',&/') in public for w in [s] + s.split()):
                    i = base + m.start()
                    b[i:i + len(m.group())] = re.sub(rb'[^\W\d_]', b'x', m.group())
                    log(f'{OUTLETS} index page: scrubbed {s!r}')

    # Kiosk's wholesalers (1992/93): a four-digit postcode gets the W- or O-
    # of the time (until July 1993), O- if the phone has an eastern area code
    if KIOSK_WHOLESALERS in data:
        b = data[KIOSK_WHOLESALERS]
        for p in range(LFR_REC, len(b) - LFR_REC + 1, LFR_REC):
            ort, tel = p + 111, p + 172
            s = b[ort + 1:ort + 1 + b[ort]].decode('cp437')
            if re.match(r'\d{4} ', s) and b[ort] <= 58:
                east = b[tel + 1:tel + 1 + b[tel]].lstrip().startswith(b'03')
                new = ('O-' if east else 'W-') + s
                b[ort:ort + 61] = bytes([len(new)]) + new.encode('cp437') + bytes(60 - len(new))
                log(f'{KIOSK_WHOLESALERS} @{p}: {s!r} -> {new!r}')

    for r, b in data.items():
        (dest / r).parent.mkdir(parents=True, exist_ok=True)
        (dest / r).write_bytes(bytes(b))
        shutil.copystat(src / r, dest / r)

    # check
    left = set()
    probes = {o for o, n in mapping.items() if o.strip() != n.strip() and len(o) >= 4 and '\0' not in o}
    probes |= names | set(literals)
    for r, b in data.items():
        for p in probes:
            for cp in ('cp437', 'cp1252'):
                if re.search(rb'(?<![^\W\d_])' + re.escape(p.encode(cp, 'replace')) + rb'(?![^\W\d_])', b) \
                        and (PERSONAL.match(r) or p not in names):
                    left.add((r, p))
        if PERSONAL.match(r) and any(not phones.covers(m.group()) for m in PHONE_IN_TEXT.finditer(b)):
            left.add((r, 'phone number'))
    print(f'{len(data)} files written, {len(files) - len(data)} left out, {len(mapping)} values, '
          f'{len(names)} names, {count} replacements, {len(left)} left over')
    for r, p in sorted(left):
        print(f'  LEFT: {r}: {p!r}' if report else f'  LEFT: {r}')
    sys.exit(1 if left else 0)


if __name__ == '__main__':
    main()
