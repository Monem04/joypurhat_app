"""Builds assets/data/joypurhat.json for the app.

Inputs:
  proto_data.json   the clickable prototype's data (categories, forms, labels,
                    the invented samples and Bangla display text)
  data_sources/     researched data with source links (doctors, transport,
                    services, places), checked 2026-10-11, and round2/
                    (more diagnostic centres, restaurants, tourist spots,
                    parlours, messes, ticket links), checked 2026-10-12, and
                    round3/ (service, education and office listings, more
                    eateries), checked 2026-10-13; photos.json (real photos)

Run from the project root:
  python3 tool/build_data.py tool/proto_data.json data_sources assets/data/joypurhat.json

Rules kept from the prototype:
  - real data only from a named source; every item keeps its source links
  - an unknown value is left empty, never guessed
  - invented sample businesses are marked "sample": true; the app hides them
    unless AppConfig.demoMode is on
"""

import json
import os
import re
import sys

PROTO, SRC, OUT = sys.argv[1], sys.argv[2].rstrip('/') + '/', sys.argv[3]

P = json.load(open(PROTO, encoding='utf-8'))
DOC = json.load(open(SRC + 'doctors.json', encoding='utf-8'))
SVC = json.load(open(SRC + 'services.json', encoding='utf-8'))
PLC = json.load(open(SRC + 'places.json', encoding='utf-8'))
TRN = json.load(open(SRC + 'transport.json', encoding='utf-8'))
DIAG2 = json.load(open(SRC + 'round2/diagnostic_more.json', encoding='utf-8'))
FOOD = json.load(open(SRC + 'round2/food.json', encoding='utf-8'))
SPOTS = json.load(open(SRC + 'round2/spots.json', encoding='utf-8'))
PRT = json.load(open(SRC + 'round2/parlour_rent_tickets.json', encoding='utf-8'))
DIAG_CLEAN = json.load(open(SRC + 'round2/diagnostic_clean.json', encoding='utf-8'))
MONEM = json.load(open(SRC + 'monem_centre.json', encoding='utf-8'))['centre']
CHECKED = '2026-10-11'
CHECKED2 = '2026-10-12'

BN_DIGITS = '০১২৩৪৫৬৭৮৯'


def to_en(s):
    return ''.join(str(BN_DIGITS.index(c)) if c in BN_DIGITS else c for c in (s or ''))


def to_bn(s):
    return ''.join(BN_DIGITS[int(c)] if c.isdigit() and c.isascii() else c for c in str(s))


def money_bn(n):
    return to_bn('{:,}'.format(int(n)))


def is_placeholder(s):
    s = s or ''
    return '[' in s or 'XXX' in s.upper()


def clean(s):
    s = (s or '').strip()
    return '' if is_placeholder(s) else s


def norm_phone(p):
    p = to_en(p or '').strip()
    if not p or 'X' in p.upper():
        return None
    p = re.sub(r'\(\+?88\)\s*', '', p)
    p = re.sub(r'^\(0(\d+)\)\s*', r'0\1-', p)
    p = p.replace('+88-', '')
    p = re.sub(r'^\+880\s*', '0', p)
    p = re.sub(r'^\+88', '', p)
    p = p.strip()
    digits = re.sub(r'\D', '', p)
    if len(digits) < 3:
        return None
    # A mobile number whose leading 0 was lost in a spreadsheet.
    if re.fullmatch(r'1[3-9]\d{8}', p):
        return '0' + p
    return p


def uniq_phones(ps):
    out, seen = [], set()
    for p in ps or []:
        n = norm_phone(p)
        if not n:
            continue
        key = re.sub(r'\D', '', n)[-10:]
        if key in seen:
            continue
        seen.add(key)
        out.append(n)
    return out


UPAZILA_BN = {
    'Joypurhat Sadar': 'জয়পুরহাট সদর', 'Akkelpur': 'আক্কেলপুর', 'Kalai': 'কালাই',
    'Khetlal': 'ক্ষেতলাল', 'Panchbibi': 'পাঁচবিবি',
}
UPAZILA_FILTERS = ['সব'] + list(UPAZILA_BN.values())


def upz(s):
    s = (s or '').split(';')[0].strip()
    return UPAZILA_BN.get(s, '')


def name_of(x):
    return (x.get('name_bn') or '').strip() or (x.get('name_en') or '').strip()


def sub_en(x):
    """English name under a Bangla title, so a reader can check the spelling."""
    bn, en = (x.get('name_bn') or '').strip(), (x.get('name_en') or '').strip()
    return en if bn and en else ''


def src(x):
    return [u for u in (x.get('source_urls') or []) if u]


def lat_lng(x):
    try:
        return float(x.get('lat')), float(x.get('lng'))
    except (TypeError, ValueError):
        return None, None


def base_item(name, **kw):
    it = {'name': name}
    for k, v in kw.items():
        if v not in (None, '', [], {}):
            it[k] = v
    return it


# ---------------------------------------------------------------- prototype

def conv_field(f):
    if isinstance(f, str):
        return f
    out = {'key': f['k']}
    out.update(conv_field_def(f))
    return out


def conv_field_def(d):
    m = {'t': 'type', 'label': 'label', 'ph': 'hint', 'req': 'required', 'opts': 'options',
         'min': 'min', 'max': 'max', 'def': 'default', 'by': 'step', 'unit': 'unit'}
    out = {}
    for k, v in d.items():
        if k in m:
            out[m[k]] = v
    if out.get('type') == 'choice':
        out['options'] = [o[0] for o in d.get('opts', [])]
        out['descriptions'] = [o[1] if len(o) > 1 else '' for o in d.get('opts', [])]
    if d.get('when'):
        # Shown only while another field has this choice, e.g. the delivery
        # address only for home delivery.
        out['whenKey'], out['whenValue'] = d['when'][0], d['when'][1]
    if d.get('from') == 'sub':
        # Options come from the place's own service list; hidden when it has none.
        out['fromServices'] = True
    if d.get('n'):
        out['count'] = d['n']
    return out


def conv_form(f):
    if not f:
        return None
    m = {'label': 'button', 'title': 'title', 'sub': 'sub', 'intro': 'intro', 'cta': 'cta',
         'doneTitle': 'doneTitle', 'msg': 'message', 'bigLabel': 'bigLabel', 'serial': 'serial',
         'track': 'track'}
    out = {m[k]: v for k, v in f.items() if k in m}
    if f.get('banner'):
        out['bannerTitle'], out['bannerSub'] = f['banner'][0], f['banner'][1]
    out['fields'] = [conv_field(x) for x in f.get('fields', [])]
    return out


def conv_rows(rows):
    out = []
    for r in rows or []:
        if is_placeholder(r[1]):
            continue
        out.append({'label': r[0], 'value': r[1], 'icon': r[2] if len(r) > 2 else 'info'})
    return out


def conv_menu(sub):
    out = []
    for r in sub or []:
        row = {'name': r[0]}
        if len(r) > 1 and r[1] and not is_placeholder(r[1]):
            row['sub'] = r[1]
        if len(r) > 2 and r[2] and not is_placeholder(r[2]):
            row['price'] = r[2]
        if len(r) > 3:
            ph = uniq_phones([r[3]])
            if ph:
                row['phone'] = ph[0]
        out.append(row)
    return out


def conv_proto_doc(d):
    return base_item(d['n'], degrees=d.get('deg'), specialty=d.get('skill'),
                     schedule=d.get('time'), fee=d.get('fee'), days=d.get('days'))


def conv_proto_item(it, sample=False, source=None):
    name = it['n']
    if is_placeholder(name):
        return None
    out = base_item(
        name,
        sub=clean(it.get('s')),
        tag=it.get('tag'),
        address=clean(it.get('a')),
        phones=uniq_phones([it.get('ph')]),
        time=clean(it.get('time')),
        price=clean(it.get('price')),
        rows=conv_rows(it.get('rows')),
        chips=it.get('chips'),
        about=clean(it.get('about')),
        menu=conv_menu(it.get('sub')),
        menuTitle=it.get('subTitle'),
        doctors=[conv_proto_doc(d) for d in it.get('docs', [])],
        icon=it.get('icon'),
        mapQuery=it.get('mapq'),
    )
    if it.get('link') and not is_placeholder(it['link'][1]):
        out['link'] = {'label': it['link'][0], 'url': it['link'][1]}
    if it.get('map') is False:
        out['showMap'] = False
    if it.get('book'):
        out['book'] = conv_form(it['book'])
    conv_rent(it, out)
    conv_food(it, out)
    if it.get('booked'):
        # Slots already taken, per day from today (samples only).
        out['bookedSlots'] = it['booked']
    for a, b in (('art', 'art'), ('arts', 'arts'), ('upd', 'updated')):
        if it.get(a):
            out[b] = it[a]
    if sample:
        out['sample'] = True
    if source:
        out['sources'] = source
    return out


def conv_rent(it, out):
    """House and mess listings: rent, facts and which rooms or seats are free."""
    for a in ('rent', 'per', 'facts'):
        if it.get(a):
            out[a] = it[a]
    if isinstance(it.get('vac'), int) and it.get('total'):
        out['vacancy'] = {'total': it['total'], 'vacant': it['vac'], 'unit': it.get('unit') or 'রুম'}
    units = [r for r in it.get('sub') or [] if len(r) > 4]
    if units:
        out['units'] = [base_item(r[0], sub=r[1], rent=r[2], free=r[4] == 'free') for r in units]
        out.pop('menu', None)


def gradient_colours(css):
    return re.findall(r'#[0-9A-Fa-f]{6}', css or '')


def conv_food(it, out):
    """A sample restaurant's menu for the order demo."""
    if not isinstance(it.get('menu'), list) or not it['menu']:
        return
    out['foodMenu'] = [{'title': sec[0], 'items': [base_item(d[0], desc=d[1], price=d[2], art=d[3]) for d in sec[1]]}
                       for sec in it['menu']]
    if it.get('fee') is not None:
        out['deliveryFee'] = it['fee']
    if it.get('deliv'):
        out['deliveryTime'] = it['deliv']
    if gradient_colours(it.get('cover')):
        out['cover'] = gradient_colours(it['cover'])
    if it.get('pal'):
        out['palette'] = it['pal']


def conv_cat(key, c):
    out = {
        'label': c['label'], 'icon': c['icon'], 'keywords': c.get('kw', ''),
        'template': c['tpl'], 'title': c.get('title') or c['label'],
    }
    for a, b in [('unit', 'unit'), ('filters', 'filters'), ('note', 'note'), ('chipsTitle', 'chipsTitle'),
                 ('aboutTitle', 'aboutTitle'), ('subTitle', 'menuTitle'), ('subLabel', 'menuLabel'),
                 ('subBook', 'menuBook'), ('subBtn', 'menuButton'), ('itemLabel', 'itemLabel'),
                 ('card', 'card'), ('intro', 'intro'), ('tips', 'tips'), ('tipsTitle', 'tipsTitle'),
                 ('mode', 'mode')]:
        if c.get(a) not in (None, '', []):
            out[b] = c[a]
    if c.get('labels'):
        L = c['labels']
        out['labels'] = {({'a': 'address', 'ph': 'phone'}).get(k, k): v for k, v in L.items()}
    if c.get('map') is False:
        out['showMap'] = False
    for a, b in [('book', 'book'), ('order', 'order'), ('form', 'form'), ('post', 'post')]:
        if c.get(a):
            out[b] = conv_form(c[a])
    if c.get('hero'):
        h = c['hero']
        out['hero'] = {'name': h[0], 'sub': h[1], 'numbers': [h[2]]}
    if c.get('sections'):
        out['sections'] = [{'title': s['h'], 'items': [
            {'name': r[0], 'sub': r[1], 'numbers': uniq_phones([r[2]]), 'icon': r[3]}
            for r in s['items'] if not is_placeholder(r[2])]} for s in c['sections']]
    if c.get('article'):
        A = c['article']
        out['article'] = {
            'title': A['title'], 'sub': A['sub'],
            'facts': [{'label': f[0], 'value': f[1]} for f in A['facts']],
            'parts': [{'title': p[0], 'text': p[1]} for p in A['parts']],
            'groups': [{'title': g[0], 'chips': g[1]} for g in A['groups']],
            'source': A['source'],
        }
    if c.get('products'):
        out['products'] = [{'name': p[0], 'unit': p[1], 'price': p[2], 'icon': p[3], 'seller': p[4], 'sample': True}
                           for p in c['products']]
    return out


C = P['cats']
cats = {k: conv_cat(k, C[k]) for k in P['order']}

# Fully invented sample businesses: shown only in demo mode.
SAMPLE_CATS = {'homefood', 'coaching', 'tourism', 'it', 'serviceman', 'house', 'mess', 'hostel',
               'community', 'decoration', 'photo', 'parlour', 'studio', 'cook', 'wifi'}
REAL_IN_SAMPLE_CATS = {'বিটিসিএল ব্রডব্যান্ড'}


def proto_samples(k):
    """The prototype's invented entries. Where it marks samples explicitly, its
    other entries are real ones, which are built here from data_sources."""
    items = C[k].get('items', [])
    marked = any('sample' in it for it in items)
    return [it for it in items if it.get('sample') or not marked]


for k in SAMPLE_CATS:
    items = []
    for it in proto_samples(k):
        x = conv_proto_item(it, sample=it['n'] not in REAL_IN_SAMPLE_CATS)
        if x:
            items.append(x)
    cats[k]['items'] = items

# ------------------------------------------------------------ emergency calls

police = {x['kind'] + '|' + x['upazila']: x for x in SVC['police']}
by_bn = {x['name_bn']: x for x in SVC['police'] + SVC['fire'] + SVC['offices'] + SVC['ambulance']}


def call_entry(name, sub, phones, icon, x=None):
    e = {'name': name, 'sub': sub, 'numbers': uniq_phones(phones), 'icon': icon}
    if x is not None:
        e['confidence'] = x.get('confidence', '')
        e['sources'] = src(x)
        if len(e['numbers']) > 1:
            e['note'] = 'উৎস ভেদে একাধিক নম্বর পাওয়া গেছে। একটিতে না পেলে অন্যটিতে চেষ্টা করুন।'
    return e


dc = by_bn['জেলা প্রশাসকের কার্যালয়, জয়পুরহাট']
sp = by_bn['পুলিশ সুপারের কার্যালয়, জয়পুরহাট']
ctrl = by_bn['জেলা পুলিশ কন্ট্রোল রুম, জয়পুরহাট']
db = by_bn['জেলা গোয়েন্দা শাখা (ডিবি), জয়পুরহাট']
fires = [x for x in SVC['fire']]
hosp_dist = DOC['hospitals'][0]

cats['emergency']['sections'] = [
    cats['emergency']['sections'][0],
    {'title': 'জয়পুরহাট জেলা', 'items': [
        call_entry('জেলা প্রশাসকের কার্যালয়', 'জয়পুরহাট', dc['phones'], 'landmark', dc),
        call_entry('পুলিশ সুপারের কার্যালয়', 'জয়পুরহাট', sp['phones'], 'shield', sp),
        call_entry('জেলা পুলিশ কন্ট্রোল রুম', 'জয়পুরহাট', ctrl['phones'], 'shield', ctrl),
        call_entry('জেলা গোয়েন্দা শাখা (ডিবি)', 'জয়পুরহাট', db['phones'], 'shield', db),
        call_entry('জয়পুরহাট ফায়ার সার্ভিস স্টেশন', 'জয়পুরহাট সদর', fires[0]['phones'], 'flame', fires[0]),
        call_entry('জেলা সদর হাসপাতাল', 'জয়পুরহাট সদর', hosp_dist['phones'], 'hospital', hosp_dist),
    ]},
    {'title': 'থানা', 'items': [
        call_entry(x['name_bn'], upz(x['upazila']) + ', ওসি', x['phones'], 'shield', x)
        for x in SVC['police'] if x['kind'] == 'police_station']},
]

cats['fire']['sections'] = [
    cats['fire']['sections'][0],
    {'title': 'জয়পুরহাটের ফায়ার স্টেশন', 'items': [
        call_entry(x['name_bn'], upz(x['upazila']), x['phones'], 'flame', x)
        for x in fires if uniq_phones(x['phones'])]},
]
cats['fire']['note'] = 'স্টেশনের নম্বরগুলো ২০১৭ সালের তালিকা থেকে নেওয়া। না পেলে ১৬১৬৩ বা ৯৯৯ এ কল করুন।'

uhc = [h for h in DOC['hospitals'] if 'Upazila Health Complex' in h['name_en']]
cats['ambulance']['sections'] = [
    {'title': 'সরকারি', 'items': [cats['ambulance']['sections'][0]['items'][0],
                                  call_entry('জেলা সদর হাসপাতাল', 'এম্বুলেন্সের জন্য হাসপাতালে কল করুন', hosp_dist['phones'], 'ambulance', hosp_dist)]
     + [call_entry(h['name_bn'] or h['name_en'], 'এম্বুলেন্সের জন্য কল করুন', h['phones'], 'ambulance', h)
        for h in uhc if uniq_phones(h['phones'])]},
]
cats['ambulance']['note'] = 'বেসরকারি এম্বুলেন্সের যাচাই করা নম্বর এখনো পাওয়া যায়নি। জরুরি হলে ৯৯৯ এ কল করুন।'

# ------------------------------------------------------------ doctors

SPEC = [
    (('dent', 'oral'), 'দাঁত'),
    (('gyn', 'obstet'), 'গাইনি ও প্রসূতি'),
    (('neuro',), 'স্নায়ু ও ব্রেইন'),
    (('ortho', 'spine', 'bone'), 'হাড় ও জোড়া'),
    (('urolog',), 'ইউরোলজি'),
    (('nephro', 'kidney'), 'কিডনি'),
    (('cardio', 'heart'), 'হৃদরোগ'),
    (('ent',), 'নাক, কান ও গলা'),
    (('skin', 'derma'), 'চর্ম ও যৌন'),
    (('eye', 'ophthal'), 'চোখ'),
    (('psychiat',), 'মানসিক রোগ'),
    (('oncolog', 'cancer'), 'ক্যান্সার'),
    (('laparoscop', 'surg', 'burn'), 'সার্জারি'),
    (('child', 'neonat', 'newborn', 'paediatric', 'pediatric'), 'শিশু'),
    (('endocrin', 'diabet'), 'ডায়াবেটিস ও হরমোন'),
    (('pain', 'anaesth'), 'ব্যথা ও অ্যানেসথেসিয়া'),
    (('medicine', 'general practitioner'), 'মেডিসিন'),
    (('chest', 'asthma'), 'বক্ষব্যাধি'),
    (('ultraso', 'sonolog'), 'আল্ট্রাসনোগ্রাফি'),
]


def spec_group(s):
    s = (s or '').lower()
    first = re.split(r'[,;(]', s)[0]
    for text in (first, s):
        for keys, label in SPEC:
            for k in keys:
                if k == 'ent':
                    if re.search(r'\bent\b', text):
                        return label
                elif k in text:
                    return label
    return 'অন্যান্য'


DAYS = [('Saturday', 'শনিবার'), ('Sunday', 'রবিবার'), ('Monday', 'সোমবার'), ('Tuesday', 'মঙ্গলবার'),
        ('Wednesday', 'বুধবার'), ('Thursday', 'বৃহস্পতিবার'), ('Friday', 'শুক্রবার')]
SHORT = [('Sat', 'শনি'), ('Sun', 'রবি'), ('Mon', 'সোম'), ('Tue', 'মঙ্গল'), ('Wed', 'বুধ'), ('Thu', 'বৃহস্পতি'),
         ('Fri', 'শুক্র')]


def part_of_day(h):
    if h < 4:
        return 'রাত'
    if h < 6:
        return 'ভোর'
    if h < 12:
        return 'সকাল'
    if h < 15:
        return 'দুপুর'
    if h < 18:
        return 'বিকাল'
    if h < 20:
        return 'সন্ধ্যা'
    return 'রাত'


def clock_bn(h, m):
    h12 = 12 if h % 12 == 0 else h % 12
    t = to_bn(h12) + ('টা' if m == 0 else ':' + to_bn('%02d' % m))
    return part_of_day(h) + ' ' + t


def tr_sched(s):
    if not s:
        return ''
    t = re.sub(r'\s*\((?:[^()]*?(?:inhealthylife|healthcenterbd|daktarbook|epharma|per )[^()]*)\)', '', s, flags=re.I)

    def ampm(m):
        h, mi, ap = int(m.group(1)), int(m.group(2) or 0), m.group(3).upper()
        if ap == 'PM' and h != 12:
            h += 12
        if ap == 'AM' and h == 12:
            h = 0
        return clock_bn(h, mi)

    t = re.sub(r'(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])', ampm, t)
    t = re.sub(r'\bfrom ([^;,]+)', r'\1 থেকে', t)
    for a, b in DAYS:
        t = t.replace(a, b)
    for a, b in SHORT:
        t = re.sub(r'\b' + a + r'\b', b, t)
    reps = [(' - ', ' – '), ('Daily', 'প্রতিদিন'), ('Everyday', 'প্রতিদিন'), ('Every ', 'প্রতি '),
            ('all day', 'সারাদিন'), ('also morning', 'সকালেও'), (' also ', ' '), (' and ', ' ও '),
            (' & ', ' ও '), ('1st', '১ম'), ('2nd', '২য়'), ('3rd', '৩য়'), ('4th', '৪র্থ'),
            ('of each month', '(প্রতি মাসে)')]
    for a, b in reps:
        t = t.replace(a, b)
    t = t.replace('-', '–')
    if re.search(r'[A-Za-z]{2,}', t):
        return s
    return t.strip()


def fee_bn(f):
    f = (f or '').strip()
    if not f:
        return ''
    m = re.search(r'৳\s*(\d+)', to_en(f))
    if m:
        return to_bn(m.group(1)) + ' টাকা' + (' (নতুন রোগী)' if 'new' in f.lower() else '')
    return f


def conv_doctor(d):
    chambers = []
    for ch in d.get('chambers', []):
        chambers.append(base_item(
            ch.get('place_bn') or ch.get('place_en') or '',
            placeEn=ch.get('place_en'),
            address=ch.get('address'),
            upazila=upz(ch.get('upazila')),
            days=tr_sched(ch.get('days')),
            time=tr_sched(ch.get('time')),
            fee=fee_bn(ch.get('fee')),
            phones=uniq_phones(ch.get('serial_phones')),
        ))
    return base_item(
        name_of(d),
        nameEn=d.get('name_en') if d.get('name_bn') else '',
        degrees=d.get('degrees'),
        specialty=d.get('specialty'),
        group=spec_group(d.get('specialty')),
        designation=d.get('designation'),
        chambers=chambers,
        confidence=d.get('confidence'),
        sources=src(d),
    )


# Round 2: fixes from the hospital's own site, and the Graduate General
# Hospital doctors. Four of them are already listed; they get a new chamber.
GGH_URL = 'https://graduategeneralhospital.com/'
GGH_PLACE = {'place_en': 'Graduate General Hospital (Graduate Diagnostic Center)',
             'place_bn': 'গ্রাজুয়েট জেনারেল হাসপাতাল ও ডায়াগনস্টিক সেন্টার',
             'address': '(Amtoli) Main Road, Joypurhat Sadar', 'upazila': 'Joypurhat Sadar'}
DOC_FIX = {
    'Dr. ASM Golam Rabbani': {'designation': 'সহযোগী অধ্যাপক ও ইউনিট প্রধান (ইউনিট-০১), কার্ডিওলজি বিভাগ, দিনাজপুর মেডিকেল কলেজ, দিনাজপুর'},
    'Dr. Nahid Sultana': {'degrees': 'MBBS, BCS (Health), FCPS (Gynaecology & Obstetrics)',
                          'designation': 'Assistant Professor, Rajshahi Medical College & Hospital',
                          'name_bn': 'ডাঃ নাহিদ সুলতানা', 'specialty': 'Gynaecology & obstetrics'},
    'Dr. Md. Sohel Rana': {'degrees': 'MBBS, BCS (Health), MS (Ortho), MRCS (Ireland)',
                           'designation': 'Consultant Orthopaedic Specialist & Trauma Surgeon; Medical Officer (Orthopaedics), District Hospital, Joypurhat'},
    'Dr. Murshida Parvin Jolly': {'degrees': 'MBBS, BCS (Health), FCPS (Surgery)',
                                  'designation': 'Consultant (Surgery), 250 Bed Specialized General Hospital, Joypurhat'},
    'Dr. Md. Matiur Rahman': {'designation': 'Assistant Professor (Former), Department of Medicine, Sir Salimullah Medical College & Hospital, Dhaka; Consultant Cardiologist, International Cardiology Institute, United Hospital, Dhaka'},
}
for c in DIAG2['corrections']:
    for name, fix in DOC_FIX.items():
        if c['what'].startswith(name):
            fix['urls'] = c['source_urls']
for d in DOC['doctors']:
    fix = DOC_FIX.get(d['name_en'])
    if fix:
        for k, v in fix.items():
            if k == 'urls':
                d['source_urls'] = d['source_urls'] + [u for u in v if u not in d['source_urls']]
            else:
                d[k] = v
EXISTING_AT_GGH = {
    'Dr. Md. Omar Faruk (Urology)': ('name_en', 'Dr. Md. Omar Faruk'),
    'Dr. Enayetullah Nazim': ('name_bn', 'ডাঃ এনায়েতুল্লাহ নাজীম'),
    'Dr. Md. Nazrul Islam Nahid': ('name_bn', 'ডাঃ মোঃ নজরুল ইসলাম (নাহিদ)'),
    'Dr. Amit Kumar Mor': ('name_bn', 'ডাঃ অমিত কুমার মোর'),
}
ggh_names = []
for x in DIAG2['doctors_at_centres']:
    chamber = dict(GGH_PLACE, days='', time='', fee='', serial_phones=x.get('phones') or [])
    hit = EXISTING_AT_GGH.get(x['name_en'])
    if hit:
        d = next(d for d in DOC['doctors'] if d[hit[0]] == hit[1])
        d['chambers'].append(chamber)
        d['source_urls'] = d['source_urls'] + [u for u in x['source_urls'] if u not in d['source_urls']]
        ggh_names.append(d['name_en'] or d['name_bn'])
        continue
    DOC['doctors'].append({
        'name_en': x['name_en'], 'name_bn': x['name_bn'], 'degrees': x.get('degrees', ''),
        'specialty': x.get('specialty', ''), 'designation': x.get('designation', ''),
        'chambers': [chamber], 'source_urls': x['source_urls'], 'confidence': x.get('confidence', ''),
    })
    ggh_names.append(x['name_en'])

DOCTORS = [conv_doctor(d) for d in DOC['doctors']]
# Centres list their doctors by English or, for Bangla-only records, by
# Bangla name. Two Bangla names belong to two doctors each.
DOC_BY_NAME = {}
for i, d in enumerate(DOC['doctors']):
    for n in (d['name_en'], d['name_bn']):
        if n:
            DOC_BY_NAME.setdefault(n, []).append(i)


def words(s):
    return set(w for w in re.findall(r'[a-z]+', (s or '').lower()) if len(w) > 2 and w not in {
        'the', 'and', 'diagnostic', 'center', 'centre', 'hospital', 'clinic', 'joypurhat', 'consultation',
        'general', 'lab', 'health', 'care'})


def doctor_refs(names, centre_en):
    """Doctor index plus the chamber at this centre."""
    refs = []
    cw = words(centre_en)
    for n in names or []:
        found = None
        for i in DOC_BY_NAME.get(n, []):
            for ci, ch in enumerate(DOC['doctors'][i]['chambers']):
                if words(ch.get('place_en')) & cw:
                    found = (i, ci)
                    break
            if found:
                break
        if not found and DOC_BY_NAME.get(n):
            found = (DOC_BY_NAME[n][0], 0)
        if found and not any(r['doctor'] == found[0] for r in refs):
            refs.append({'doctor': found[0], 'chamber': found[1]})
    return refs


SERVICE_BN = {
    'Gynaecology': 'গাইনি', 'Neuromedicine': 'নিউরোমেডিসিন', 'Cardiology': 'হৃদরোগ', 'Neonatal & child': 'নবজাতক ও শিশু',
    'Neurosurgery': 'নিউরোসার্জারি', 'Cancer': 'ক্যান্সার', 'Mental health': 'মানসিক স্বাস্থ্য', 'Skin & sex': 'চর্ম ও যৌন',
    'Orthopaedics': 'হাড় ও জোড়া', 'Urology': 'ইউরোলজি', 'Medicine': 'মেডিসিন', 'ENT': 'নাক, কান ও গলা',
    'Diabetes': 'ডায়াবেটিস', 'General surgery': 'জেনারেল সার্জারি',
    'Skin & STD': 'চর্ম ও যৌন', 'Skin & venereal': 'চর্ম ও যৌন', 'Skin & sexual diseases': 'চর্ম ও যৌন',
    'Dermatology': 'চর্মরোগ', 'Skin': 'চর্মরোগ', 'Operation Theater': 'অপারেশন থিয়েটার',
    'Operation theatre (per DGHS registry)': 'অপারেশন থিয়েটার', 'Nephrology': 'কিডনি রোগ', 'Kidney': 'কিডনি রোগ',
    'Neurology': 'স্নায়ুরোগ', 'Rheumatology': 'বাতরোগ', 'Ambulance': 'এম্বুলেন্স', 'Ambulance (per DGHS registry)': 'এম্বুলেন্স',
    'IPD': 'ভর্তি রোগী', 'OPD': 'বহির্বিভাগ', 'Liver': 'লিভার', 'Hepatology': 'লিভার', 'Gastro-liver': 'পেট ও লিভার',
    'Gastroenterology': 'পেটের রোগ', 'Child health': 'শিশু', 'Child diseases': 'শিশু', 'Child': 'শিশু', 'Paediatrics': 'শিশু',
    'Gynae-oncology': 'গাইনি ক্যান্সার', 'Anaesthesiology': 'অ্যানেসথেসিয়া', 'Anaesthesia': 'অ্যানেসথেসিয়া',
    'Oral & maxillofacial surgery': 'মুখ ও চোয়ালের সার্জারি', 'Nutrition': 'পুষ্টি', 'Dialysis': 'ডায়ালাইসিস',
    'Eye': 'চোখ', 'Ophthalmology': 'চোখ', 'Emergency': 'জরুরি বিভাগ', 'Haematology': 'রক্তরোগ', 'Chest': 'বক্ষব্যাধি',
    'Psychiatry': 'মানসিক রোগ', 'Diagnostics': 'রোগ নির্ণয়', 'Pharmacy': 'ফার্মেসি', 'Oncology': 'ক্যান্সার',
    'Pathology': 'প্যাথলজি', 'Pathology / diagnostic tests': 'প্যাথলজি ও পরীক্ষা', 'Thoracic surgery': 'বক্ষ সার্জারি',
    'Pain management': 'ব্যথা চিকিৎসা', 'Interventional pain medicine': 'ব্যথা চিকিৎসা', 'Surgery': 'সার্জারি', 'Clinic': 'ক্লিনিক',
    'Endocrinology': 'হরমোন ও ডায়াবেটিস', 'Burn & plastic surgery': 'বার্ন ও প্লাস্টিক সার্জারি',
    'Specialist consultation (skin, child, nephrology, surgery, ultrasonology, neurosurgery, cardiology, orthopaedics, urology)':
        'বিশেষজ্ঞ ডাক্তার', 'Pain medicine': 'ব্যথা চিকিৎসা', 'Gynaecology & obstetrics': 'গাইনি ও প্রসূতি',
}


def centre_item(x, tag=None, kind='diagnostic'):
    lat, lng = lat_lng(x)
    services = list(dict.fromkeys(SERVICE_BN.get(s, s) for s in (x.get('services') or [])))
    rows = []
    if x.get('beds'):
        b = to_en(x['beds'])
        m = re.match(r'\s*(\d+)\s*$', b)
        if m:
            rows.append({'label': 'শয্যা', 'value': to_bn(m.group(1)) + 'টি', 'icon': 'bed'})
    if x.get('alias'):
        rows.append({'label': 'নিবন্ধিত নাম', 'value': x['alias'], 'icon': 'tag'})
    hours = tr_sched(x.get('hours'))
    if hours.startswith('Per doctor'):
        hours = ''
    return base_item(
        name_of(x),
        sub=sub_en(x),
        tag=tag,
        address=x.get('address'),
        phones=uniq_phones(x.get('phones')),
        time=hours,
        rows=rows,
        chips=services,
        note=x.get('note_bn'),
        website=(x.get('website') or '').strip(),
        mapQuery=(x.get('name_en') or '') + ', Joypurhat',
        lat=lat, lng=lng,
        doctorRefs=doctor_refs(x.get('doctors'), x.get('name_en')),
        confidence=x.get('confidence'),
        sources=src(x),
    )


# ------------------------------------------------------------ round 2: centres

DGHS_HOSTS = ('hris.mohfw.gov.bd', 'hrm.dghs.gov.bd')
DGHS_LIST_URL = DIAG2['corrections'][4]['source_urls'][0]


def dghs_only(urls):
    """hris.mohfw and hrm.dghs are the same registry, so they count as one source."""
    return bool(urls) and all(any(h in u for h in DGHS_HOSTS) for u in urls)


def registry_note(notes):
    m = re.search(r'next-renewal date (\d{4})-(\d{2})', notes or '')
    when = ''
    if m:
        when = 'নিবন্ধন নবায়নের তারিখ ছিল ' + MONTHS_BN[int(m.group(2)) - 1] + ' ' + to_bn(m.group(1)) + '। '
    return ('স্বাস্থ্য অধিদপ্তরের নিবন্ধন তালিকা থেকে নেওয়া। ' + when +
            'তালিকায় থাকা মানেই এখন চালু আছে এমন নয়, যাওয়ার আগে ফোন করে নিশ্চিত হোন।')


MONTHS_BN = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর',
             'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর']

# Registry addresses, written in Bangla. Village names that could not be
# spelled with confidence stay in English.
CENTRE_ADDR_BN = {
    'Al-Shifa Diagnostic Centre (Joypurhat Sadar)': 'আধুনিক জেলা হাসপাতাল মোড়, সদর রোড, জয়পুরহাট',
    'Lab Seven Diagnostic Centre': 'পুরানাপৈল বাজার, জয়পুরহাট সদর',
    'S.B Polar Diagnostic & Consultancy': 'বাজার গলি, জয়পুরহাট সদর',
    'Saz Pathological Lab': 'জামালগঞ্জ রোড, জয়পুরহাট',
    'Doctors Lab': 'আমতলী, সদর রোড, জয়পুরহাট',
    'Meditest Diagnostic & Consultancy Center': 'সি ও কলোনী, জয়পুরহাট',
    'Oxigen Diagnostic & Consultation Centre': 'আমতলী, সদর রোড, জয়পুরহাট',
    'High Care Clinic and Diagnostic Center': 'আমতলী, সদর রোড, জয়পুরহাট',
    'National General Hospital and Diagnostic Centre': 'আমতলী, সদর রোড, জয়পুরহাট',
    'Anowara Lab & Consultancy': 'সি ও কলোনী, সদর রোড, জয়পুরহাট',
    'City Diagnostic Center': 'আমতলী, সদর রোড, জয়পুরহাট',
    'Khanjanpur Mission Health Service': 'পাহাড়পুর রোড, খঞ্জনপুর, জয়পুরহাট সদর',
    'Surjer Hashi Clinic, Joypurhat': 'প্রফেসরপাড়া, জয়পুরহাট',
    'Madhainagar Health Centre, Grameen Kalyan': 'মাধাইনগর বাজার, জয়পুরহাট সদর',
    'Jamalganj Health Center, Grameen Kalyan': 'জামালপুর চারমাথা, জামালগঞ্জ, জয়পুরহাট সদর',
    'Somajder Diagnostic Centre': 'তিলকপুর, আক্কেলপুর',
    'Digital Diagnostic Center (Akkelpur)': 'হাবিবা ম্যানশন, কলেজ বাজার, মেইন রোড, আক্কেলপুর',
    'Naba-Ayat Diagnostic Centre': 'উপজেলা মুক্তিযোদ্ধা কমপ্লেক্স ভবন, সদর রোড, আক্কেলপুর',
    'The Popular Diagnostic Center, Akkelpur': 'এস কে সুপার মার্কেট (২য় তলা), আক্কেলপুর; উপজেলা স্বাস্থ্য কমপ্লেক্সের সামনে',
    'Tilokpur Health Center, Grameen Kalyan': 'তিলকপুর, আক্কেলপুর',
    'NAF Diagnostic Centre': 'হারুঞ্জা, কালাই',
    'Mollik Digital Diagnostic & Consultation Center': 'সদর রোড, কালাই',
    'Sotota Diagnostic Center': 'হাসপাতাল রোড, কালাই',
    'Khetlal Diagnostic Centre': 'ইটাখোলা রোড, ক্ষেতলাল',
    'Computer Pathology Centre': 'নাজিরপুর, মোলামগাড়ীহাট, ক্ষেতলাল',
    'Al-Taqwa Lab and Consultation Center (Khetlal)': 'ক্ষেতলাল সদর, ক্ষেতলাল',
    'Life Care Diagnostic & Diabetic Centre': 'বটতলী বাজার, ক্ষেতলাল',
    'Grameen Kalyan Bottoli Bazar Health Centre': 'বটতলী বাজার, ক্ষেতলাল',
    'Pathological Laboratory (Damdama, Panchbibi)': 'দমদমা, পাঁচবিবি',
    'Ramichha Clinic & Diagnostic Centre': 'বাজার রোড, পাঁচবিবি',
    'Shimultoli Diagnostic Centre': 'শিমুলতলী বাজার, পাঁচবিবি',
    'At-Taqwa Lab & General Hospital': 'তিনমাথা, পাঁচবিবি',
    'Surjer Hashi Clinic, Panchbibi': 'নাকুরগাছি (হিলি রোড), পাঁচবিবি',
}
CENTRE_NAME_BN = {
    'Surjer Hashi Clinic, Joypurhat': 'সূর্যের হাসি ক্লিনিক, জয়পুরহাট',
    'Surjer Hashi Clinic, Panchbibi': 'সূর্যের হাসি ক্লিনিক, পাঁচবিবি',
    'Pathological Laboratory (Damdama, Panchbibi)': 'প্যাথলজিক্যাল ল্যাবরেটরি, দমদমা',
    'Khanjanpur Mission Health Service': 'খঞ্জনপুর মিশন হেলথ সার্ভিস',
}


def centre_sub(x):
    n = x['name_en']
    if 'Grameen Kalyan' in n:
        return 'গ্রামীণ কল্যাণের স্বাস্থ্যকেন্দ্র (এনজিও)'
    if 'Surjer Hashi' in n:
        return 'সূর্যের হাসি নেটওয়ার্কের ক্লিনিক (এনজিও)'
    if 'Mission' in n:
        return 'মিশন পরিচালিত স্বাস্থ্যসেবা'
    return re.sub(r'\s*\(.*?\)', '', n)


def round2_centre(x):
    x = dict(x)
    x['name_bn'] = CENTRE_NAME_BN.get(x['name_en'], x['name_bn'])
    x['address'] = CENTRE_ADDR_BN.get(x['name_en'], re.sub(r'\s*\((?:as printed|DGHS|mailing|village)[^)]*\)', '', x['address']))
    if dghs_only(x['source_urls']):
        x['confidence'] = 'low'
    it = centre_item(x, tag=upz(x['upazila']))
    it['sub'] = centre_sub(x)
    if dghs_only(x['source_urls']):
        it['note'] = registry_note(x.get('notes'))
    it['checked'] = CHECKED2
    return it


def add_urls(x, urls):
    x['source_urls'] = (x.get('source_urls') or []) + [u for u in urls if u not in (x.get('source_urls') or [])]


# Corrections to centres and clinics already in the list.
corr = {c['what'].split(':')[0]: c for c in DIAG2['corrections']}
dc_by = {x['name_en']: x for x in DOC['diagnostic_centres']}
hosp_by = {x['name_en']: x for x in DOC['hospitals']}

x = dc_by['Al Shefa Diagnostic Centre']
x['address'] = 'Sadar Road, east of the T&T office, Khetlal'
x['phones'] = ['+৮৮০১৭৭৮-১০৪৯৮২', '01735705360']
add_urls(x, corr['Al Shefa Diagnostic Centre (Khetlal)']['source_urls'][:1])

x = dc_by['Bismilla Diagnostic Center']
x.update(name_bn='বিসমিল্লাহ ডায়াগনষ্টিক সেন্টার', upazila='Akkelpur', address='সরদার মার্কেট, আক্কেলপুর',
         phones=['01712493776'], confidence='low')
x['note_bn'] = registry_note('next-renewal date 2019-07-01')
add_urls(x, corr['Bismilla Diagnostic Center']['source_urls'])

x = dc_by['Taqwa Lab and Consultation Center']
x['phones'] = x['phones'] + ['01942420040']
x['alias'] = 'আনার কলি ল্যাব এন্ড কনসালটেশন সেন্টার'
add_urls(x, corr['Taqwa Lab and Consultation Center (Sadar)']['source_urls'])

x = dc_by['Graduate General Hospital / Graduate Diagnostic Center']
x['website'] = GGH_URL
x['address'] = 'আমতলী, মেইন রোড, জয়পুরহাট সদর'
x['phones'] = x['phones'] + ['01786-545656']
x['doctors'] = x['doctors'] + [n for n in ggh_names if n not in x['doctors']]
add_urls(x, [GGH_URL, 'https://graduategeneralhospital.com/ggh-doctors/'])

extra = corr['Extra phone numbers and emails from the DGHS registry for existing centres (registry contact mobiles, possibly owner or manager numbers)']
for name, phone, ll in [
    ('Seba Diagnostic Center', '01716057964', None),
    ('KM Lab and Consultancy', '01745178868', None),
    ('Emu Diagnostic Center', '01714547455', None),
    ('New Green Life Diagnostic Center', '01911231959', None),
    ('Fair Health Consultancy and Diagnostic Centre', '01712278227', (25.101652, 89.030382)),
    ('Joypurhat Diagnostic & Dialysis Centre', '', (25.1004866, 89.03255)),
]:
    x = dc_by[name]
    if phone:
        x['phones'] = x['phones'] + [phone]
    if ll and not x.get('lat'):
        x['lat'], x['lng'] = ll
    add_urls(x, extra['source_urls'][:1])

clinic_fix = corr['Hospitals list (outside this file\'s scope, found along the way)']
for name, phones in [('Anowara Clinic', ['01715002308']),
                     ('Bandhan Clinic & Diagnostic Centre', hosp_by['Bandhan Clinic & Diagnostic Centre']['phones'] + ['01782349275']),
                     ('Padma Clinic (& Diagnostic Center)', hosp_by['Padma Clinic (& Diagnostic Center)']['phones'] + ['01925500817'])]:
    hosp_by[name]['phones'] = phones
    add_urls(hosp_by[name], clinic_fix['source_urls'][:1])

# New centres. The ones also registered as a private hospital or clinic go to
# the hospital list; "Doctor Bari" is the centre from Monem's own app.
new_diag, new_hosp = [], []
doctor_bari = None
for x in DIAG2['diagnostic_centres']:
    if x['name_en'].startswith('Doctor Bari'):
        doctor_bari = x
        continue
    if "'Private Hospital / Clinic'" in x['notes'] and x['phones']:
        new_hosp.append(x)
    else:
        new_diag.append(x)
ggh_note = corr['Graduate General Hospital / Graduate Diagnostic Center']
for name_en, name_bn, phone in [('Emu General Hospital', 'ইমু জেনারেল হাসপাতাল', '01915461219'),
                                ('Al Modina Diagnostic Center & General Hospital',
                                 'আল মদিনা ডায়াগনস্টিক সেন্টার ও জেনারেল হাসপাতাল', '01757632971')]:
    new_hosp.append({'name_en': name_en, 'name_bn': name_bn, 'address': 'জয়পুরহাট সদর', 'upazila': 'Joypurhat Sadar',
                     'phones': [phone], 'source_urls': extra['source_urls'][:1], 'confidence': 'low', 'notes': ''})

# Bangla names and addresses for hospitals the sources gave only in English.
# Names that could not be spelled with confidence stay in English.
HOSP_BN = {
    'Joypurhat District Hospital (Adhunik Sadar / General Hospital)': (None, 'সদর রোড, জয়পুরহাট'),
    'Kalai Upazila Health Complex': (None, 'আহম্মেদাবাদ ইউনিয়ন, ওয়ার্ড ০১, কালাই'),
    'Akkelpur Upazila Health Complex': ('উপজেলা স্বাস্থ্য কমপ্লেক্স, আক্কেলপুর', 'আক্কেলপুর, জয়পুরহাট'),
    'Khetlal Upazila Health Complex': ('উপজেলা স্বাস্থ্য কমপ্লেক্স, ক্ষেতলাল', 'ক্ষেতলাল, জয়পুরহাট'),
    'Panchbibi Upazila Health Complex': ('উপজেলা স্বাস্থ্য কমপ্লেক্স, পাঁচবিবি', 'পাঁচবিবি, জয়পুরহাট'),
    'Mother & Child Welfare Centre (MCWC), Joypurhat Sadar': (None, 'জয়পুরহাট সদর'),
    'Police Hospital Joypurhat': (None, 'পুলিশ লাইন, জয়পুরহাট ৫৯০০'),
    'Modern General Hospital & Diagnostic Center': (None, 'সদর রোড (শহীদ ডাঃ আবুল কাশেম ময়দান সংলগ্ন), জয়পুরহাট ৫৯০০'),
    'The Rawshan Clinic and Diagnostic Centre': (None, 'আন্ডারগ্রাউন্ড মার্কেট, নতুনহাট, জামালগঞ্জ রোড, জয়পুরহাট'),
    'Doctors Clinic': (None, 'হাজী মাদ্রাসা রোড, জয়পুরহাট'),
    'New Doctors Clinic': ('নিউ ডক্টরস ক্লিনিক', 'হাজী মাদ্রাসা রোড, জয়পুরহাট সদর'),
    'Bandhan Clinic & Diagnostic Centre': ('বন্ধন ক্লিনিক ও ডায়াগনস্টিক সেন্টার',
                                           'পূর্ব বাজার, জয়পুরহাট সদর (আরেক উৎসে শহীদ জিয়া কলেজ রোড)'),
    'Anowara Clinic': ('আনোয়ারা ক্লিনিক', 'জয়পুরহাট সদর'),
    'Joypurhat Clinic and Nursing Home': ('জয়পুরহাট ক্লিনিক ও নার্সিং হোম', 'শহীদ জিয়া কলেজ রোড, জয়পুরহাট সদর'),
    'Satman Clinic': (None, 'শহীদ জিয়া কলেজ রোড, জয়পুরহাট সদর'),
    'Mission Hospital': ('মিশন হাসপাতাল', 'নওগাঁ-জয়পুরহাট রোড, জয়পুরহাট সদর'),
    'Marie Stopes Clinic, Joypurhat': ('মেরী স্টোপস ক্লিনিক, জয়পুরহাট', 'শহীদ জিয়া কলেজ রোড, জয়পুরহাট সদর'),
    'Patwari General Hospital': ('পাটোয়ারী জেনারেল হাসপাতাল', 'Baraigram (তালিকায় যেমন লেখা, জায়গা যাচাই হয়নি)'),
    'Major Hospital / United Health Care, Akkelpur': ('মেজর হাসপাতাল / ইউনাইটেড হেলথ কেয়ার, আক্কেলপুর',
                                                      'জয়পুরহাট রোড, আক্কেলপুর'),
}
for h in DOC['hospitals']:
    name_bn, addr = HOSP_BN.get(h['name_en'], (None, None))
    if name_bn:
        h['name_bn'] = name_bn
    if addr:
        h['address'] = addr

# Hospitals: researched list, with the prototype's verified notes for govt hospitals.
proto_h = {it['n']: it for it in C['hospital']['items']}
hosp_items = []
for h in DOC['hospitals']:
    tag = 'সরকারি' if h.get('type') == 'govt' else ('বেসরকারি' if h.get('type') == 'private' else '')
    it = centre_item(h, tag=tag, kind='hospital')
    for pn, pi in proto_h.items():
        if pi.get('tag') == 'সরকারি' and pn.split()[0] in h['name_en'] and (
                'Upazila' in pn) == ('Upazila' in h['name_en']):
            it['rows'] = it.get('rows', []) + conv_rows(pi.get('rows'))
            if pi.get('chips') and not it.get('chips'):
                it['chips'] = pi['chips']
            if pi.get('about'):
                it['about'] = pi['about']
            break
    if h['name_en'].startswith('Joypurhat District Hospital'):
        it['about'] = (it.get('about', '') + ' ' if it.get('about') else '') + \
            '২০২৬ সালের জুলাইয়ে ৪০০ শয্যায় উন্নীত হয়েছে বলে খবর আছে (ডেইলি অবজারভার, ১০ সেপ্টেম্বর ২০২৬)। বিভিন্ন তালিকায় ১৫০ বা ২৫০ শয্যা লেখা।'
    hosp_items.append(it)
for x in new_hosp:
    it = round2_centre(x)
    it['tag'] = 'বেসরকারি'
    it['icon'] = 'hospital'
    it['sub'] = 'বেসরকারি হাসপাতাল ও ক্লিনিক' if 'Mission' not in x['name_en'] and 'Surjer' not in x['name_en'] else it['sub']
    if not it.get('note'):
        it['note'] = registry_note(x.get('notes'))
    hosp_items.append(it)
cats['hospital']['items'] = hosp_items
cats['hospital']['note'] = 'ডাক্তারের নাম, দিন ও সময় অনলাইন ডিরেক্টরি থেকে নেওয়া (২০২৬)। যাওয়ার আগে ফোন করে নিশ্চিত হয়ে নিন।'

# Diagnostic: researched centres plus the centre from Monem's own app.
monem = conv_proto_item(MONEM, source=['Monem-এর অ্যাপের তথ্য'] + doctor_bari['source_urls'])
monem['tag'] = upz(doctor_bari['upazila'])
monem['phones'] = uniq_phones(doctor_bari['phones'])
monem['rows'] = [{'label': 'নিবন্ধন', 'value': 'স্বাস্থ্য অধিদপ্তরের নিবন্ধন তালিকায় আছে, ফোন নম্বর সেখান থেকে', 'icon': 'idcard'}]
monem['checked'] = CHECKED2
diag_items = [monem]
# Bangla names and addresses from the cleaned list for the two centres the
# sources gave only in English.
clean_by = {c['n']: c for c in DIAG_CLEAN['centres']}
for en, bn in [('Al Baraka Heart Centre and Diagnostic', 'আল বারাকা হার্ট সেন্টার অ্যান্ড ডায়াগনস্টিক'),
               ('Family Care Lab', 'ফ্যামিলি কেয়ার ল্যাব')]:
    dc_by[en].update(name_bn=bn, address=clean_by[bn]['a'])
diag_items += [centre_item(x, tag=upz(x.get('upazila'))) for x in DOC['diagnostic_centres']]

# Graduate's Panchbibi branch: registry contact plus the branch number the
# hospital prints; Dr. Sohel Rana's branch chamber is there.
ggh = dc_by['Graduate General Hospital / Graduate Diagnostic Center']
rana = DOC_BY_NAME['Dr. Md. Sohel Rana'][0]
branch2 = next(i for i, ch in enumerate(DOC['doctors'][rana]['chambers']) if 'Branch 2' in ch.get('place_en', ''))
diag_items.append(base_item(
    'গ্রাজুয়েট ডায়াগনস্টিকস অ্যান্ড কনসালটেন্সি, পাঁচবিবি', sub='Graduate Diagnostics & Consultancy, Panchbibi',
    tag='পাঁচবিবি', address='১ নং রেলগেট, কামদিয়া রোড, পাঁচবিবি', phones=uniq_phones(['01706-150706', '01715360903']),
    mapQuery='Graduate Diagnostics & Consultancy, Panchbibi', lat=25.187277, lng=89.019669,
    doctorRefs=[{'doctor': rana, 'chamber': branch2}], confidence='medium', checked=CHECKED2,
    sources=ggh['source_urls'][:1] + ggh_note['source_urls'][2:3]))
diag_items += [round2_centre(x) for x in new_diag]
# The cleaned list has the Bangla address for centres whose sources wrote it in English.
for it in diag_items:
    if re.search(r'[A-Za-z]', it.get('address') or '') and clean_by.get(it['name'], {}).get('a'):
        it['address'] = clean_by[it['name']]['a']
cats['diagnostic']['items'] = diag_items
cats['diagnostic']['filters'] = UPAZILA_FILTERS
cats['diagnostic']['note'] = cats['hospital']['note'] + ' উপজেলার নতুন সেন্টারগুলো স্বাস্থ্য অধিদপ্তরের নিবন্ধন তালিকা থেকে।'

DENTAL_BN = {
    'Hasan Dental Care, Joypurhat': ('হাসান ডেন্টাল কেয়ার, জয়পুরহাট', '', ''),
    'Chamber of Dr Md. Amirul Islam (oral & maxillofacial surgeon)':
        ('ডাঃ মোঃ আমিরুল ইসলামের চেম্বার', 'সদর রোড, জয়পুরহাট ৫৯০০', 'ওরাল ও ম্যাক্সিলোফেসিয়াল সার্জন'),
}
dental_items = []
for x in DOC['dental']:
    name_bn, addr, sub = DENTAL_BN.get(x['name_en'], ('', '', ''))
    x.update(name_bn=name_bn or x.get('name_bn'), address=addr or x.get('address'))
    it = centre_item(x)
    if sub:
        it['sub'] = sub
    if 'facebook.com' in it.get('website', ''):
        it['link'] = {'label': 'ফেসবুক পেজ', 'url': it.pop('website')}
    refs = doctor_refs([re.sub(r'\s*\(.*\)$', '', d) for d in x.get('dentists') or []], x['name_en'])
    if refs:
        it['doctorRefs'] = refs
    dental_items.append(it)
# Graduate General Hospital's dental department and its two dentists.
gd = next(c for c in DIAG_CLEAN['dental'] if c['n'].startswith('গ্রাজুয়েট'))
dental_items.insert(0, base_item(
    gd['n'], sub='হাসপাতালের ডেন্টাল বিভাগ', tag='জয়পুরহাট সদর', address=ggh['address'],
    phones=uniq_phones(ggh['phones']), website=GGH_URL, mapQuery=ggh['name_en'] + ', Joypurhat',
    lat=ggh.get('lat'), lng=ggh.get('lng'), chips=['দাঁত ও মুখের রোগ', 'ওরাল সার্জারি'],
    doctorRefs=doctor_refs([d['en'] for d in gd['docs']], ggh['name_en']),
    confidence='medium', checked=CHECKED2, sources=[GGH_URL, 'https://graduategeneralhospital.com/ggh-doctors/']))
cats['dental']['items'] = dental_items
cats['dental']['note'] = 'ডেন্টাল চেম্বারের যাচাই করা তথ্য খুব কম পাওয়া গেছে। আপনার চেম্বার যোগ করতে "Shop দিতে চাই" ফর্ম পূরণ করুন।'

# ------------------------------------------------------------ places

KIND_BN = [
    ('circuit house', 'সরকারি সার্কিট হাউজ'), ('guest house', 'গেস্ট হাউস'), ('resort', 'রিসোর্ট'),
    ('residential hotel', 'আবাসিক হোটেল'), ('hotel', 'হোটেল'),
    ('chinese', 'চাইনিজ রেস্টুরেন্ট'), ('fast food', 'ফাস্ট ফুড'), ('cafe', 'ক্যাফে'), ('tea', 'চায়ের দোকান'),
    ('snack', 'নাস্তার দোকান'), ('home-made', 'ঘরে তৈরি খাবার'), ('restaurant', 'রেস্টুরেন্ট'),
]


def kind_bn(k):
    k = (k or '').lower()
    for a, b in KIND_BN:
        if a in k:
            return b
    return ''


def place_item(x, tag=None, sub=None):
    lat, lng = lat_lng(x)
    about = (x.get('description_bn') or '').strip()
    return base_item(
        name_of(x),
        sub=sub if sub is not None else (kind_bn(x.get('kind')) or sub_en(x)),
        tag=tag,
        address=x.get('address') or (upz(x.get('upazila')) + ', জয়পুরহাট' if upz(x.get('upazila')) else ''),
        phones=uniq_phones(x.get('phones')),
        price=(x.get('price') or '').strip(),
        about=about,
        website=(x.get('website') or '').strip(),
        mapQuery=x.get('maps_query'),
        lat=lat, lng=lng,
        confidence=x.get('confidence'),
        sources=src(x),
        nameEn=x.get('name_en') if x.get('name_bn') else '',
    )


cats['hotel']['items'] = [place_item(x) for x in PLC['hotels']]
cats['hotel'].pop('filters', None)
cats['hotel'].pop('menuBook', None)
cats['hotel']['menuTitle'] = 'রুম ও ভাড়া'
cats['hotel']['note'] = 'হোটেলের ফোন নম্বর ২০২০–২০২২ সালের তালিকা থেকে নেওয়া। রুম বুকিংয়ের অনুরোধ এসএমএসে হোটেলে যাবে।'


# Bangla display text the prototype already wrote for the real listings
# (subtitle, address, hours), matched by phone number or name.
PROTO_REAL = {k: [it for it in C[k].get('items', []) if not it.get('sample')]
              for k in ('restaurant', 'spots', 'mess', 'parlour')}


def norm_name(n):
    n = (n or '').lower()
    for a, b in (('&', 'ও'), ('অ্যান্ড', 'ও'), ('এন্ড', 'ও'), (' and ', 'ও')):
        n = n.replace(a, b)
    return re.sub(r"[\s.,'’()\-–]+", '', n)


def phone_keys(ps):
    keys = set()
    for p in ps or []:
        d = re.sub(r'\D', '', to_en(p or ''))
        if len(d) >= 10:
            keys.add(d[-10:])
    return keys


def proto_match(k, x, *names):
    keys = phone_keys(x.get('phones'))
    wanted = {norm_name(n) for n in (x.get('name_bn'), x.get('name_en')) + names if n}
    for it in PROTO_REAL[k]:
        if (keys & phone_keys([it.get('ph')])) or norm_name(it['n']) in wanted:
            return it
    return {}


def no_sample_sentence(note):
    """Category notes are shown with demo mode off too, so a sentence about
    the samples is left out; demo mode has its own banner."""
    return ' '.join(p for p in re.split(r'(?<=।)\s+', note or '') if 'নমুনা' not in p).strip()


def hours_bn(h):
    h = re.sub(r'\s*\((?:[^()]*\.(?:one|com|bd|org))\)', '', h or '').strip()
    if not h:
        return ''
    if re.match(r'open 24 hours', h, re.I):
        return '২৪ ঘণ্টা খোলা'

    def rng(m):
        return clock_bn(int(m[1]) % 24, int(m[2])) + ' থেকে ' + clock_bn(int(m[3]) % 24, int(m[4]))

    t = re.sub(r'(\d{1,2}):(\d{2})\s*[–-]\s*(\d{1,2}):(\d{2})', rng, h)
    daily = ' daily' in t
    t = t.replace(' daily', '')
    for a, b in (('Haat days only', 'শুধু হাটের দিন'), (' and ', ' ও '), ('Fri ', 'শুক্রবার ')):
        t = t.replace(a, b)
    for a, b in DAYS:
        t = t.replace(a, b)
    t = ('প্রতিদিন ' if daily else '') + t
    t = re.sub(r'\(শুক্রবার ([^)]*)\)', r'(শুক্রবার \1)', t)
    return '' if re.search(r'[A-Za-z]{2,}', t) else t


def per_person_bn(p):
    m = re.match(r'৳\s*([\d,]+)\s*[–-]\s*([\d,]+)\s*per person', p or '')
    return 'জনপ্রতি ৳' + money_bn(m[1].replace(',', '')) + '–' + money_bn(m[2].replace(',', '')) if m else ''


REST_TAGS = [(r'sweet|mishti|\bdoi\b|dairy|bakery|dodhi', 'মিষ্টি ও দই'), (r'chinese', 'চাইনিজ'),
             (r'\bfast\b|shawarma|shwarma|snack|fuchka|street|burger|pizza', 'ফাস্ট ফুড'),
             (r'cafe|\btea\b|coffee', 'ক্যাফে'), (r'bangla|bhat|kacchi|biryani|hotel', 'বাংলা')]


def rest_tag(x):
    k = (x.get('kind') or '').lower()
    for pat, tag in REST_TAGS:
        if re.search(pat, k):
            return tag
    return ''


REST_KIND_BN = [(r'sweet|mishti', 'মিষ্টির দোকান'), (r'\bdoi\b|dodhi', 'দই ও মিষ্টি'), (r'bakery', 'বেকারি'),
                (r'kacchi', 'কাচ্চি ও বাংলা খাবার'), (r'chinese', 'চাইনিজ রেস্টুরেন্ট'),
                (r'fuchka|street', 'ফুচকা ও স্ট্রিট ফুড'), (r'\bfast\b|shawarma|shwarma', 'ফাস্ট ফুড'),
                (r'cafe|coffee', 'ক্যাফে ও রেস্টুরেন্ট'), (r'\btea\b', 'চায়ের দোকান'),
                (r'bangla|bhat|hotel', 'বাংলা খাবারের হোটেল'), (r'home', 'হোম সার্ভিস'), (r'restaurant', 'রেস্টুরেন্ট')]


def rest_kind_bn(x):
    k = (x.get('kind') or '').lower()
    for pat, label in REST_KIND_BN:
        if re.search(pat, k):
            return label
    return ''


# What the sources say about delivery, in their words.
DELIVERY_BN = {
    'Hungry Birds Restaurant': 'khozobd.com এ ডেলিভারি সুবিধার কথা লেখা আছে',
    'Kusum Kitchen': 'উৎসে অনলাইন অর্ডারের সুবিধার কথা লেখা আছে',
    'Sharma Mishtanna Bhandar': 'শুধু আগাম অর্ডার নেয় বলে উৎসে লেখা',
    'Bismillah Sweets and Dairy': 'Trip.com এ নিয়ে যাওয়ার (টেকঅ্যাওয়ে) সুবিধা লেখা আছে',
    'Bondhu Mithai': 'Trip.com এ ফুড ডেলিভারির কথা লেখা আছে',
}
# Real prices from dated sources, shown with their year.
MENU_NOTE = {
    "Azizul's Hotel (Tilakpur Haat)": 'দাম ২০২৩ সালের (প্রথম আলো, সেপ্টেম্বর ২০২৩), বদলাতে পারে। ভাতসহ কিনা লেখা নেই।',
    'Azad Hotel & Kacchi Mahal': 'দাম ২০২৪ সালের এক ভ্রমণ ব্লগে লেখা আনুমানিক হিসাব, বদলাতে পারে।',
}
REST_CONFIDENCE = {'Cafe Orange Chinese Restaurant': 'medium', 'Mina Restaurant': 'medium'}
# Addresses the prototype has no Bangla for.
REST_ADDR_BN = {
    "Nana's bar": 'কলেজ রোড, জয়পুরহাট', 'You tree House': 'জয়পুরহাট', 'S A Tandoori Tea': 'জয়পুরহাট',
    'Moumita Hotel And Restaurant': 'বঙ্গবন্ধু রোড, ইস্পাহানি চায়ের আঞ্চলিক অফিসের কাছে, জয়পুরহাট',
    'New Jannat Coffee House And Fast Food': 'বঙ্গবন্ধু রোড, ইস্পাহানি চায়ের আঞ্চলিক অফিসের কাছে, জয়পুরহাট',
    'Home Made food Joypurhat': 'স্টেশন রোড, জয়পুরহাট', 'Local Food House': 'জয়পুরহাট শহর',
    'Hemu Restaurant': 'জয়পুরহাট শহর', 'Hotel Ujan Vati': 'টাউন হল রোড, জয়পুরহাট', 'Majadul Sweet': 'থানা রোড',
    'Bismillah Sweets and Dairy': 'জয়পুরহাট', 'New Green Chili Restaurant': 'আক্কেলপুর মেইন রোড, আক্কেলপুর',
    'Fuchka Ghar': 'আক্কেলপুর মেইন রোড, আক্কেলপুর', 'Bondhu Mithai': 'মসজিদ রোড, জয়পুরহাট',
    'Shaja Tea Stall': 'হিন্দা শিমুলতলী বাজার', "Azizul's Hotel (Tilakpur Haat)": 'তিলকপুর হাট, মসজিদের সামনে, আক্কেলপুর',
    'SK Home Service': 'জয়পুরহাট', 'Amader Dokan': 'রেলস্টেশন ওভারপাস, জয়পুরহাট',
}


def restaurant_item(x):
    pm = proto_match('restaurant', x, x.get('name_bn_alt'))
    if x.get('kind_changed'):
        pm = dict(pm, s='')
    name = (x.get('name_bn') or '').strip() or pm.get('n') or x['name_en']
    if re.search('[\u0980-\u09FF]', name):
        name = name.replace(' & ', ' ও ')
    lat, lng = lat_lng(x)
    rows = []
    if DELIVERY_BN.get(x['name_en']):
        rows.append({'label': 'ডেলিভারি', 'value': DELIVERY_BN[x['name_en']], 'icon': 'bike'})
    if x.get('name_bn_alt'):
        rows.append({'label': 'অন্য নাম', 'value': x['name_bn_alt'], 'icon': 'tag'})
    it = base_item(
        name,
        sub=pm.get('s') or rest_kind_bn(x),
        tag=rest_tag(x),
        address=pm.get('a') or REST_ADDR_BN.get(x['name_en']) or x.get('address') or upz(x.get('upazila')),
        phones=uniq_phones(x.get('phones')),
        time=pm.get('time') or hours_bn(x.get('hours')),
        price=pm.get('price') or per_person_bn(x.get('price_range')),
        about=(x.get('description_bn') or '').strip(),
        rows=rows,
        mapQuery=x.get('maps_query') or (x['name_en'] + ', Joypurhat'),
        lat=lat, lng=lng,
        confidence=REST_CONFIDENCE.get(x['name_en'], x.get('confidence')),
        sources=src(x),
        nameEn=x['name_en'] if x.get('name_bn') else '',
    )
    menu = next((m for m in FOOD['menus'] if m['restaurant_name_en'] == x['name_en']), None)
    if menu:
        approx = 'approximate' in menu['notes'].lower() or 'aprox' in menu['notes'].lower()
        it['menu'] = [base_item(d['name_bn'], price=('প্রায় ' if approx else '') + '৳' + money_bn(d['price']))
                      for d in menu['items']]
        it['menuTitle'] = 'যে দাম জানা গেছে'
        it['menuNote'] = MENU_NOTE[x['name_en']]
        it['sources'] = it.get('sources', []) + [d['source_url'] for d in menu['items'] if d['source_url'] not in it.get('sources', [])][:1]
    return it


updates = {u['name_en']: u for u in FOOD['existing_restaurant_updates']}
rest_items = []
for x in PLC['restaurants']:
    x = dict(x)
    u = updates.get(x['name_en'])
    if u:
        for k in ('address', 'hours', 'kind', 'name_bn', 'name_bn_alt'):
            if u.get(k):
                x[k] = u[k]
        x['kind_changed'] = bool(u.get('kind'))
        x['phones'] = (u.get('phones') or []) + [p for p in x.get('phones') or [] if p]
        add_urls(x, u.get('source_urls') or [])
    it = restaurant_item(x)
    if u:
        it['checked'] = CHECKED2
    rest_items.append(it)
for x in FOOD['restaurants']:
    it = restaurant_item(x)
    it['checked'] = CHECKED2
    rest_items.append(it)
for it in proto_samples('restaurant'):
    if it.get('sample'):
        rest_items.append(conv_proto_item(it, sample=True))
cats['restaurant']['items'] = rest_items
cats['restaurant']['template'] = 'list'
cats['restaurant'].pop('menuTitle', None)
cats['restaurant'].pop('menuLabel', None)
cats['restaurant']['note'] = ('Foodpanda এখনো জয়পুরহাটে চালু নেই, অন্য কোনো ডেলিভারি অ্যাপও পাওয়া যায়নি (অক্টোবর ২০২৬)। '
                              'রেস্টুরেন্টের দামসহ মেনু অনলাইনে নেই, তাই আপাতত কল করে অর্ডার দিন। মালিকরা মেনু দিলে অ্যাপ থেকেই অর্ডার করা যাবে।')


def edu_tag(x):
    k = (x.get('kind') or '').lower()
    if 'madrasa' in k:
        return 'মাদ্রাসা'
    if 'college' in k or 'institute' in k:
        return 'কলেজ'
    return 'স্কুল'


def edu_sub(x):
    k = (x.get('kind') or '')
    kl = k.lower()
    parts = []
    if 'government' in kl:
        parts.append('সরকারি')
    if 'cadet' in kl:
        parts.append('ক্যাডেট কলেজ')
    elif 'kamil' in kl:
        parts.append('কামিল মাদ্রাসা')
    elif 'fazil' in kl:
        parts.append('ফাজিল মাদ্রাসা')
    elif 'alim' in kl:
        parts.append('আলিম মাদ্রাসা')
    elif 'dakhil' in kl:
        parts.append('দাখিল মাদ্রাসা')
    elif 'technical' in kl:
        parts.append('কারিগরি প্রতিষ্ঠান')
    elif 'girls' in kl and 'school' in kl:
        parts.append('বালিকা উচ্চ বিদ্যালয়')
    elif 'school' in kl:
        parts.append('উচ্চ বিদ্যালয়')
    elif 'women' in kl:
        parts.append('মহিলা কলেজ')
    elif 'college' in kl:
        parts.append('কলেজ')
    m = re.search(r'EIIN (\d+)', k)
    if m:
        parts.append('EIIN ' + m.group(1))
    return ' · '.join(parts)


edu = PLC['education']
cats['school']['items'] = [place_item(x, tag=edu_tag(x), sub=edu_sub(x)) for x in edu if edu_tag(x) != 'মাদ্রাসা']
cats['madrasa']['items'] = [place_item(x, tag=upz(x.get('upazila')), sub=edu_sub(x)) for x in edu if edu_tag(x) == 'মাদ্রাসা']
cats['madrasa']['filters'] = UPAZILA_FILTERS
cats['madrasa'].pop('book', None)
cats['school']['note'] = 'নাম ও প্রতিষ্ঠার সাল বাংলাপিডিয়া ও উইকিপিডিয়া থেকে। বেশিরভাগ প্রতিষ্ঠানের ফোন নম্বর এখনো পাওয়া যায়নি।'


def spot_item(x):
    pm = proto_match('spots', x)
    lat, lng = lat_lng(x)
    rows = []
    if (x.get('entry_bn') or '').strip():
        rows.append({'label': 'প্রবেশ', 'value': x['entry_bn'].strip(), 'icon': 'ticket'})
    near = '' if upz(x.get('upazila')) else 'জয়পুরহাটের পাশে, নওগাঁ জেলায়'
    return base_item(
        x['name_bn'],
        sub=pm.get('s'),
        tag=pm.get('tag'),
        address=pm.get('a') or x.get('address'),
        time=(x.get('hours_bn') or '').strip(),
        rows=rows,
        about=(x.get('description_bn') or '').strip(),
        howTo=(x.get('how_to_go_bn') or '').strip(),
        note=near,
        art=pm.get('art'), arts=pm.get('arts'),
        photos=x.get('photos'),
        icon='landmark',
        mapQuery=x['name_en'].split(' (')[0] + ', Joypurhat',
        lat=lat, lng=lng,
        confidence=x.get('confidence'),
        sources=src(x),
        nameEn=x['name_en'],
        checked=CHECKED2,
    )


cats['spots']['items'] = [spot_item(x) for x in SPOTS['spots']]
cats['spots']['template'] = 'list'
cats['spots']['labels'] = {'address': 'কোথায়', 'time': 'খোলা থাকে'}

# Community centres: the few real listings found.
others = {x['name_en']: x for x in PLC['other_services']}
cats['community']['items'] = [place_item(others['Shopno Chaya Community Centre'], sub='কমিউনিটি সেন্টার'),
                              place_item(others['Hoque Convention Centre'], sub='কনভেনশন হল')] + cats['community']['items']
cats['community'].pop('filters', None)

# Messes and hostels (Cybo and OpenStreetMap). No source gives rent or free
# seats, so the app says to call; the prototype's samples show vacancy.
GENDER_TAG = [('female', 'ছাত্রী'), ('girls', 'ছাত্রী'), ('male', 'ছাত্র'), ('boys', 'ছাত্র')]


def mess_tag(x):
    w = ((x.get('for') or '') + ' ' + (x.get('kind') or '')).lower()
    for k, t in GENDER_TAG:
        if k in w:
            return t
    return ''


def mess_item(x):
    pm = proto_match('mess', x)
    lat, lng = lat_lng(x)
    tag = mess_tag(x)
    sub = pm.get('s') or {'ছাত্র': 'ছাত্রদের মেস', 'ছাত্রী': 'ছাত্রীদের মেস'}.get(tag, 'মেস')
    return base_item(
        name_of(x), sub=sub, tag=tag, address=pm.get('a') or x.get('address'),
        phones=uniq_phones(x.get('phones')), mapQuery=x['name_en'] + ', Joypurhat', lat=lat, lng=lng,
        confidence=x.get('confidence'), sources=src(x), nameEn=x['name_en'] if x.get('name_bn') else '',
        checked=CHECKED2,
    )


mess_real, hostel_real = [], []
for x in PRT['mess_hostel']:
    kind = (x.get('kind') or '').lower()
    (hostel_real if 'hostel' in kind and 'mess' not in kind else mess_real).append(mess_item(x))
for it in hostel_real:
    it['sub'] = 'হোস্টেল'
cats['mess']['items'] = mess_real + cats['mess']['items']
cats['hostel']['items'] = [place_item(others['SR Hostel Joypurhat'], sub='হোস্টেল ও মেস')] + hostel_real + cats['hostel']['items']

# Beauty parlours and salons (Cybo yellow pages): names and numbers only.
def parlour_item(x):
    pm = proto_match('parlour', x)
    tag = {'ladies': 'মেয়েদের', 'men': 'ছেলেদের'}.get(x.get('for'), '')
    sub = pm.get('s') or ('সেলুন' if tag == 'ছেলেদের' else 'বিউটি পার্লার')
    address = pm.get('a') or re.sub(r'\s*\(plus code [^)]*\)', '', x.get('address') or '')
    return base_item(
        name_of(x), sub=sub, tag=tag, address=address, phones=uniq_phones(x.get('phones')),
        mapQuery=(x['name_en'] + ', Joypurhat'), icon='scissors',
        confidence=x.get('confidence'), sources=src(x), nameEn=x['name_en'] if x.get('name_bn') else '',
        checked=CHECKED2,
    )


cats['parlour']['items'] = [parlour_item(x) for x in PRT['parlours']] + cats['parlour']['items']
cats['parlour']['menuTitle'] = 'সার্ভিস ও খরচ'

for k in ('house', 'mess', 'parlour', 'spots'):
    cats[k]['note'] = no_sample_sentence(cats[k].get('note'))

# ------------------------------------------------------------ services

BRANCH_BN = {
    'Joypurhat': 'জয়পুরহাট', 'Joypurhat East': 'জয়পুরহাট পূর্ব', 'Joypurhat Corporate': 'জয়পুরহাট কর্পোরেট',
    'Hatil': 'হাতিল', 'Akkelpur': 'আক্কেলপুর', 'Kalai': 'কালাই', 'Punathat': 'পুনটহাট', 'Khetlal': 'ক্ষেতলাল',
    'Panchbibi': 'পাঁচবিবি', 'Jamalganj': 'জামালগঞ্জ', 'Tilakpur': 'তিলকপুর', 'Gopinathpur': 'গোপীনাথপুর',
    'Molamgarihat': 'মোলামগাড়ীহাট', 'Madhainagar': 'মাধাইনগর', 'Puronapail': 'পুরানাপৈল', 'Raikali': 'রায়কালী',
    'Dogachi': 'দোগাছী', 'Moslemganj': 'মোসলেমগঞ্জ', 'Battali': 'বটতলী', 'Atapur': 'আটাপুর', 'Bagzana': 'বাগজানা',
    'Chatinali': 'চাটিনালী', 'Dharanji': 'ধরঞ্জি',
}


def bank_item(x):
    m = re.search(r',\s*(.+?)\s+Branch', x['name_en'])
    branch = m.group(1) if m else ''
    bn = BRANCH_BN.get(branch, '')
    name = x['name_bn'] + (', ' + bn + ' শাখা' if bn else '')
    it = place_item(dict(x, description_bn='', name_bn=name), tag=upz(x['upazila']), sub=x['name_en'])
    rows = []
    if x.get('extra', '').startswith('Routing number'):
        rows.append({'label': 'রাউটিং নম্বর', 'value': x['extra'].split(':', 1)[1].strip(), 'icon': 'card'})
    if rows:
        it['rows'] = rows
    it['icon'] = 'landmark'
    it.pop('nameEn', None)
    return it


cats['bank']['items'] = [bank_item(x) for x in SVC['banks']]
cats['bank']['filters'] = UPAZILA_FILTERS
cats['bank']['note'] = 'শাখার নাম, ঠিকানা ও রাউটিং নম্বর banksbd.org থেকে। বেশিরভাগ শাখার ফোন নম্বর পাওয়া যায়নি। ব্যাংক খোলা থাকে রবি থেকে বৃহস্পতিবার।'


def rep_item(x):
    tag = 'সংসদ' if x['kind'] == 'member_of_parliament' else 'পৌরসভা'
    sub = {'member_of_parliament': 'সংসদ সদস্য', 'municipality_administrator': 'প্রশাসক, জয়পুরহাট পৌরসভা'}.get(x['kind'], '')
    rows = []
    if x['kind'] == 'member_of_parliament':
        seat = 'জয়পুরহাট-১ (সদর ও পাঁচবিবি)' if 'Panchbibi' in x['upazila'] else 'জয়পুরহাট-২ (আক্কেলপুর, কালাই ও ক্ষেতলাল)'
        rows.append({'label': 'নির্বাচনী এলাকা', 'value': seat, 'icon': 'map'})
        party = 'বাংলাদেশ জামায়াতে ইসলামী' if 'Jamaat' in x.get('extra', '') else ('বিএনপি' if 'BNP' in x.get('extra', '') else '')
        if party:
            rows.append({'label': 'দল', 'value': party, 'icon': 'vote'})
        rows.append({'label': 'নির্বাচন', 'value': 'ত্রয়োদশ জাতীয় সংসদ নির্বাচন, ২০২৬', 'icon': 'calendar'})
    else:
        rows.append({'label': 'দায়িত্ব', 'value': 'অতিরিক্ত জেলা প্রশাসক (সার্বিক), পৌরসভার প্রশাসক', 'icon': 'idcard'})
    it = base_item(name_of(x), sub=sub, tag=tag, rows=rows, icon='user', showMap=False,
                   confidence=x.get('confidence'), sources=src(x))
    return it


cats['representative']['items'] = [rep_item(x) for x in SVC['representatives']]
cats['representative']['filters'] = ['সব', 'সংসদ', 'পৌরসভা']
cats['representative']['note'] = 'জেলা ও উপজেলা পরিষদের বর্তমান দায়িত্বপ্রাপ্তদের নাম যাচাই করে যোগ করা হবে।'

press = by_bn['জয়পুরহাট জেলা প্রেস ক্লাব']
cats['journalist']['items'] = [base_item('জয়পুরহাট জেলা প্রেস ক্লাব', sub='জেলার সাংবাদিকদের সংগঠন', tag='প্রেসক্লাব',
                                         address=press.get('address'), icon='building', mapQuery='Joypurhat Press Club',
                                         confidence=press.get('confidence'), sources=src(press))]
cats['journalist']['filters'] = None
cats['journalist'].pop('filters')
cats['journalist']['note'] = 'সাংবাদিকদের নাম ও নম্বর তাদের অনুমতি নিয়ে যোগ করা হবে।'

news = [conv_proto_item(it) for it in C['newspaper']['items'] if not is_placeholder(it['n'])]
for x in SVC['newspapers']:
    if x['kind'] in ('daily_newspaper', 'weekly_newspaper', 'monthly_periodical'):
        n = x['name_en'].split(' (')[0]
        sub = {'daily_newspaper': 'দৈনিক', 'weekly_newspaper': 'সাপ্তাহিক', 'monthly_periodical': 'মাসিক'}[x['kind']]
        news.append(base_item(n, sub=sub + ', জয়পুরহাট থেকে প্রকাশিত', tag='স্থানীয়', icon='news', showMap=False,
                              about='বাংলাপিডিয়ার তালিকায় আছে। এখনো প্রকাশিত হয় কিনা নিশ্চিত নয়।',
                              confidence=x.get('confidence'), sources=src(x)))
cats['newspaper']['items'] = news

off = {x['name_bn']: x for x in SVC['offices']}
power = []
for it in C['power']['items']:
    x = conv_proto_item(it)
    if 'নেসকো' in it['n']:
        x['phones'] = uniq_phones(off['নেসকো, জয়পুরহাট']['phones'])
        x['rows'] = [{'label': 'অভিযোগ ও তথ্য', 'value': 'নেসকো হটলাইন ১৬৬০৩', 'icon': 'phone'}]
        x['sources'] = src(off['নেসকো, জয়পুরহাট'])
    else:
        x['note'] = 'সমিতির নিজস্ব অভিযোগ নম্বর এখনো পাওয়া যায়নি। জাতীয় বিদ্যুৎ অভিযোগ হটলাইন ১৬৯৯৯।'
        x['phones'] = uniq_phones(off['বিদ্যুৎ অভিযোগ হটলাইন']['phones'])
        x['sources'] = src(off['বিদ্যুৎ অভিযোগ হটলাইন'])
    x.pop('time', None)
    power.append(x)
cats['power']['items'] = power
cats['power'].pop('book', None)

# Upazilas: the prototype's facts, with real office contacts instead of placeholders.
uno = {upz(x['upazila']): x for x in SVC['offices'] if x['kind'] == 'uno_office'}
thana = {upz(x['upazila']): x for x in SVC['police'] if x['kind'] == 'police_station'}
fire_by = {upz(x['upazila']): x for x in fires}
uhc_by = {}
for h in uhc:
    for k in ('Akkelpur', 'Kalai', 'Khetlal', 'Panchbibi'):
        if k in h['name_en']:
            uhc_by[UPAZILA_BN[k]] = h
upz_items = []
for it in C['upazila']['items']:
    x = conv_proto_item(it)
    name = it['n']
    menu = []
    u = uno.get(name)
    if u:
        menu.append({'name': 'উপজেলা নির্বাহী অফিসারের কার্যালয়', 'url': u.get('website', '')})
    t = thana.get(name)
    if t:
        menu.append({'name': t['name_bn'], 'sub': 'ওসি', 'phone': uniq_phones(t['phones'])[0]})
    f = fire_by.get(name)
    if f and uniq_phones(f['phones']):
        menu.append({'name': f['name_bn'], 'phone': uniq_phones(f['phones'])[0]})
    h = uhc_by.get(name)
    if h and uniq_phones(h['phones']):
        menu.append({'name': h['name_bn'] or h['name_en'], 'phone': uniq_phones(h['phones'])[0]})
    if name == 'জয়পুরহাট সদর':
        menu.append({'name': 'জেলা সদর হাসপাতাল', 'phone': uniq_phones(hosp_dist['phones'])[0]})
    x['menu'] = menu
    x['menuTitle'] = 'জরুরি অফিস ও নম্বর'
    if u and u.get('website'):
        x['website'] = u['website']
    en = {'জয়পুরহাট সদর': 'Joypurhat Sadar', 'আক্কেলপুর': 'Akkelpur', 'কালাই': 'Kalai', 'ক্ষেতলাল': 'Khetlal',
          'পাঁচবিবি': 'Panchbibi'}[name]
    x['mapQuery'] = en + ' Upazila, Joypurhat'
    upz_items.append(x)
cats['upazila']['items'] = upz_items

for k in ('probashi', 'passport', 'library'):
    items = []
    for it in C[k]['items']:
        real = it.get('tag') == 'সরকারি' or (k == 'passport' and 'আঞ্চলিক' in it['n'])
        x = conv_proto_item(it, sample=not real)
        if x:
            items.append(x)
    cats[k]['items'] = items

# Shop and the shop form: the products are samples.
cats['shop']['emptyText'] = 'জয়পুরহাটের পণ্য বিক্রেতারা যুক্ত হলে এখানে দেখাবে। আপনি বিক্রি করতে চাইলে "Shop দিতে চাই" ফর্ম পূরণ করুন।'

# ------------------------------------------------------------ transport

OFF = {
    '705': None, '706': None, '757': None, '758': None, '765': 3, '766': 2, '793': None, '794': None,
    '803': 5, '804': 6, '733': 3, '734': 3, '731': 0, '732': 0, '727': 4, '728': 4, '747': 1, '748': 1,
    '797': 'conflict', '798': 'conflict', '805': 6, '806': 6,
}
# weekday numbers here: 0 Sunday ... 6 Saturday (Dart's DateTime.weekday % 7)
PLACE_BN = {
    'Dhaka (Kamalapur)': 'ঢাকা', 'Dhaka': 'ঢাকা', 'Panchagarh': 'পঞ্চগড়', 'Chilahati': 'চিলাহাটি',
    'Rajshahi': 'রাজশাহী', 'Khulna': 'খুলনা', 'Kurigram': 'কুড়িগ্রাম',
}
FARE_CLS = {'shovan': 'শোভন', 'shovan_chair': 'শোভন চেয়ার', 'first_seat': 'প্রথম সিট', 'first_berth': 'প্রথম বার্থ',
            'snigdha': 'স্নিগ্ধা', 'ac_s': 'এসি সিট', 'ac_b': 'এসি বার্থ'}


def fare_text(v):
    nums = sorted(set(int(n) for n in re.findall(r'(?<![\d.])(\d{2,4})(?![\d.])', v.split('(')[0] + ' ' + ' '.join(
        p.split('(')[0] for p in v.split('/')))))
    nums = [n for n in nums if n >= 50]
    if not nums:
        return ''
    if len(nums) == 1:
        return '৳' + money_bn(nums[0])
    return '৳' + money_bn(nums[0]) + '–' + money_bn(nums[-1])


trains = []
for x in TRN['trains']:
    if x.get('confidence') == 'low':
        continue
    runs = []
    for no, desc in x['numbers'].items():
        m = re.match(r'(.+?) to (.+)', desc)
        frm, to = (m.group(1).strip(), m.group(2).strip()) if m else ('', '')
        t = x['joypurhat_times'].get(no, {})
        off = OFF.get(no)
        runs.append(base_item(
            no,
            to=PLACE_BN.get(to, to), origin=PLACE_BN.get(frm, frm),
            arr=t.get('arr'), dep=t.get('dep'),
            offDay=off if isinstance(off, int) else None,
            offConflict=True if off == 'conflict' else None,
        ))
    fares = []
    for dest, cls in (x.get('fares_from_joypurhat') or {}).items():
        rows = [{'cls': FARE_CLS.get(k, k), 'fare': fare_text(v)} for k, v in cls.items() if fare_text(v)]
        if rows:
            fares.append({'to': PLACE_BN.get(dest, dest), 'classes': rows})
    off_note = ''
    if any(r.get('offConflict') for r in runs):
        off_note = 'সাপ্তাহিক বন্ধ মঙ্গলবার না বুধবার, উৎস ভেদে আলাদা লেখা। যাওয়ার আগে স্টেশনে বা ১৩১ নম্বরে জেনে নিন।'
    trains.append(base_item(
        x['name_bn'], nameEn=x['name_en'], runs=runs, offNote=off_note,
        termini=' – '.join(PLACE_BN.get(p.strip(), p.strip()) for p in re.sub(r'\s*\(.*?\)', '', x['termini']).split(' - ')),
        fares=fares, confidence=x.get('confidence'), sources=src(x),
    ))

buses = {}
for b in TRN['buses']:
    key = b['operator_en']
    op = buses.setdefault(key, {'name': b['operator_bn'], 'nameEn': key, 'route': 'জয়পুরহাট ⇄ ঢাকা',
                                'coaches': [], 'counters': [], 'sources': [], 'confidence': b.get('confidence')})
    detail = b.get('fare', '')
    plain = re.sub(r'\(.*?\)', '', detail)
    nums = [int(n) for n in re.findall(r'\d{3,4}', plain)]
    if b['coach'] == 'AC' and 'Non-AC' in detail:
        nums = nums[:1]
    nums = sorted(set(nums))
    fare = ''
    if nums:
        fare = '৳' + money_bn(nums[0]) + ('–' + money_bn(nums[-1]) if len(nums) > 1 else '')
    op['coaches'].append({'coach': 'এসি' if b['coach'] == 'AC' else 'নন-এসি', 'fare': fare})
    for ct in b.get('counters', []):
        place = ct['place'].split(' (')[0].split(',')[0].strip()
        place_bn = {'Joypurhat': 'জয়পুরহাট', 'Panchbibi': 'পাঁচবিবি', 'Hili': 'হিলি',
                    'Joypurhat counter': 'জয়পুরহাট'}.get(place, place)
        phones = uniq_phones(ct['phones'])
        if phones and not any(c['phones'] == phones for c in op['counters']):
            op['counters'].append({'place': place_bn + ' কাউন্টার', 'phones': phones})
    for u in src(b):
        if u not in op['sources']:
            op['sources'].append(u)
bus_list = list(buses.values())

# Operator sites that sell Joypurhat tickets online (round 2). SR Travels'
# site could not be opened, so it is not linked.
online = {o['site']: o for o in PRT['bus_online']}
tickets_bus = {t['name']: t for t in PRT['tickets']['bus']}
OPERATOR_SITE = {
    'Hanif Enterprise': ('https://www.hanif-enterprise.com/booking/bus/search?fromcity=joypurhat&tocity=dhaka',
                         tickets_bus['Shohoz']['source_urls'][3:4]),
    'Ahad Enterprise': ('https://ahadenterprise-bd.com/', online['bdtickets']['source_urls'][2:3]),
    'Shyamoli Paribahan / Shyamoli NR Travels': ('https://shyamolitickets.com/search/DHAKA/JOYPURHAT',
                                                 online['Shyamoli Paribahan (shyamolitickets.com)']['source_urls']),
}
for op in bus_list:
    site = OPERATOR_SITE.get(op['nameEn'])
    if site:
        op['website'] = site[0]
        op['sources'] += [u for u in site[1] if u not in op['sources']]
bus_online = [
    # Shohoz's own pre-filled search did not open the route, and its AC/non-AC
    # filter could not be confirmed, so the user picks the cities on the site.
    {'name': 'Shohoz', 'sub': 'সাইটে ঢাকা ও জয়পুরহাট বেছে বাস খুঁজুন; হানিফ এখানে টিকিট বিক্রি করে',
     'url': online['Shohoz']['joypurhat_url'], 'helpline': '16374', 'hours': 'সকাল ৭টা থেকে রাত ১১টা',
     'sources': [tickets_bus['Shohoz']['source_urls'][0]] + online['Shohoz']['source_urls'][2:4]},
    {'name': 'শ্যামলী টিকিট (shyamolitickets.com)',
     'sub': 'ঢাকা থেকে জয়পুরহাটের বাস খোলা থাকে; তারিখ বেছে এসি বা নন-এসি কোচ ফিল্টার করুন',
     'url': online['Shyamoli Paribahan (shyamolitickets.com)']['joypurhat_url'], 'helpline': '09644 664466',
     'hours': '২৪ ঘণ্টা', 'sources': online['Shyamoli Paribahan (shyamolitickets.com)']['source_urls']},
]

places = []
for x in TRN['places']:
    lat, lng = lat_lng(x)
    places.append(base_item(x['name_bn'], nameEn=x['name_en'], mapQuery=x['maps_query'], lat=lat, lng=lng, sources=src(x)))

rail = TRN['rail_services']
ttms = PRT['train_live'][0]
tickets_train = PRT['tickets']['train']

# Demo trips from the prototype: invented operators, shown only in demo mode.
demo_trips = []
for it in C['bus']['items'] + C['brtc']['items']:
    if not it.get('fare') and not it.get('nrows'):
        continue
    demo_trips.append(base_item(
        it['n'], coach=it.get('coach'), tag=it.get('tag'), time=it.get('time'), route=it.get('route'),
        address=it.get('a'), fare=it.get('fare'), rows=it.get('nrows', 10), hold=it.get('hold'),
        boards=it.get('boards'), stops=[{'name': s[0], 'time': s[1]} for s in it.get('stops', [])],
        live=it.get('live'), mapQuery=it.get('mapq'), brtc=True if it['n'].startswith('বিআরটিসি') else None,
        sample=True,
    ))

transport = {
    'trains': trains,
    'buses': bus_list,
    'places': places,
    'rail': {
        'ticketUrl': 'https://eticket.railway.gov.bd/',
        'appName': 'রেল সেবা',
        'appPackage': 'com.shohoz.dtrainpwa',
        'callCentre': '131',
        'smsNumber': '16318',
        'smsFormat': 'TR {number}',
        'smsNote': 'রেলের ট্রেন ট্র্যাকিং (TTMS) নির্দেশিকা অনুযায়ী ফিরতি এসএমএসে ট্রেনের অবস্থান, পরের স্টেশন ও কত দেরি জানায়। '
                   'খরচ রেলের সাইটে লেখা নেই; একটি বেসরকারি সাইট অনুযায়ী প্রায় ৪ টাকা + ভ্যাট, অপারেটর ভেদে বদলাতে পারে।',
        'ticketNote': 'রেলের নামে সোশ্যাল মিডিয়ায় বেশি দামে টিকিট বিক্রি হয়। শুধু রেলের সাইট, রেল সেবা অ্যাপ বা স্টেশনের কাউন্টার থেকে কিনুন (railway.gov.bd)।',
        'appSupport': '01313-096301',
        'sources': list(dict.fromkeys(src(rail) + ttms['source_urls'][:2] + [u for t in tickets_train for u in t['source_urls']])),
    },
    # Stations on the line through Joypurhat, north to south, with rough
    # minutes before Joypurhat for a southbound train and a point on the
    # route sketch (x, y in percent). Used only for the estimated position.
    'line': [
        {'name': 'পার্বতীপুর জংশন', 'min': 75, 'x': 26, 'y': 9},
        {'name': 'বিরামপুর', 'min': 42, 'x': 38, 'y': 30},
        {'name': 'হিলি', 'min': 24, 'x': 50, 'y': 41},
        {'name': 'পাঁচবিবি', 'min': 12, 'x': 56, 'y': 51},
        {'name': 'জয়পুরহাট', 'min': 0, 'x': 59, 'y': 61},
        {'name': 'আক্কেলপুর', 'min': -17, 'x': 53, 'y': 74},
        {'name': 'সান্তাহার জংশন', 'min': -45, 'x': 59, 'y': 88},
    ],
    'busOnline': bus_online,
    'demoTrips': demo_trips,
    'note': 'ট্রেনের সময় পশ্চিমাঞ্চল রেলের সময়সূচি নং ৫৪ (১০ মার্চ ২০২৫ থেকে) অনুযায়ী। বাসের ভাড়া ২০২৪ সালের তথ্য, বদলাতে পারে।',
}

for k in ('bus', 'train', 'brtc'):
    c = cats[k]
    c['template'] = 'transport'
    c.pop('items', None)
    c.pop('book', None)
for k in ('bus', 'train'):
    cats[k].pop('online', None)
cats['bus']['note'] = 'কাউন্টারে ফোন করে, বা নিচের অনলাইন সাইট থেকে টিকিট কাটুন। ভাড়া ২০২৪ সালের তথ্য, বদলাতে পারে।'
cats['train']['note'] = 'ট্রেনের টিকিট রেলের নিজস্ব সাইট, রেল সেবা অ্যাপ বা স্টেশনের কাউন্টারে কাটুন। ট্রেন কোথায় আছে, ১৬৩১৮ নম্বরে এসএমএস করে জানা যায়।'
cats['brtc']['note'] = 'জয়পুরহাটে বিআরটিসি কাউন্টারের যাচাই করা তথ্য এখনো পাওয়া যায়নি।'

# ------------------------------------------------------------ forms and the rest

fields = {k: conv_field_def(v) for k, v in P['fields'].items()}

notices = [
    {'id': 'update2', 'title': 'নতুন তথ্য যোগ হলো', 'date': CHECKED2,
     'body': 'পাঁচ উপজেলার আরও ২৯টি ডায়াগনস্টিক সেন্টার, গ্রাজুয়েট জেনারেল হাসপাতালের ১৬ জন ডাক্তার, ৩০টি রেস্টুরেন্ট ও মিষ্টির দোকান, '
             'দর্শনীয় স্থানের বর্ণনা ও যাওয়ার পথ, পার্লার, মেস ও অনলাইনে বাস-ট্রেনের টিকিটের লিংক যোগ হয়েছে। প্রতিটির নিচে উৎসের লিংক আছে।'},
    {'id': 'data', 'title': 'অ্যাপের তথ্য কোথা থেকে', 'date': CHECKED,
     'body': 'হাসপাতাল, ডাক্তার, ব্যাংক, শিক্ষাপ্রতিষ্ঠান, হোটেল ও যাতায়াতের তথ্য সরকারি ও বিশ্বস্ত অনলাইন উৎস থেকে নেওয়া, শেষ যাচাই ১১ ও ১২ অক্টোবর ২০২৬। প্রতিটি তথ্যের নিচে উৎসের লিংক আছে। কোনো নম্বর বা সময় ভুল পেলে "যোগাযোগ" পাতা থেকে জানান।'},
    {'id': 'hotline', 'title': 'জরুরি নম্বর', 'date': CHECKED,
     'body': 'যেকোনো জরুরি অবস্থায় ৯৯৯ এ কল করুন: পুলিশ, ফায়ার সার্ভিস ও এম্বুলেন্স, ২৪ ঘণ্টা, বিনা খরচে। স্বাস্থ্য পরামর্শের জন্য ১৬২৬৩।'},
]

# The scrolling announcement line on the home screen; colour is a group
# colour name from the app theme.
# ------------------------------------------------------------ round 3

# More real listings (checked 2026-10-13) for services that had only samples.
# Every file in data_sources/round3/ is {"items": [...]} with a "category"
# (the app's category key) per item, so local data collected later can go in
# a new file there in the same shape.
CHECKED3 = '2026-10-13'
R3_DIR = SRC + 'round3/'
R3 = []
for name in sorted(os.listdir(R3_DIR)) if os.path.isdir(R3_DIR) else []:
    if name.endswith('.json'):
        R3 += json.load(open(R3_DIR + name, encoding='utf-8')).get('items', [])
for x in R3:
    assert x.get('category') in cats, 'round3: unknown category %r for %s' % (x.get('category'), name_of(x))


def r3_map(x):
    q = (x.get('maps_query') or '').strip() or (x.get('name_en') or name_of(x))
    # A short plus code needs a town next to it.
    if not re.search(r'joypurhat|jaipurhat|panchbibi|akkelpur|kalai|khetlal|dhaka', q, re.I):
        q += ', Joypurhat'
    return q


def r3_key(n):
    return re.sub(r'(জয়পুরহাট|joypurhat)$', '', norm_name(n))


def r3_item(x, tag=None, sub=None, icon=None):
    lat, lng = lat_lng(x)
    up = upz(x.get('upazila'))
    site = (x.get('website') or '').strip()
    cap = str(x.get('capacity') or '').strip()
    return base_item(
        name_of(x), sub=sub or (x.get('kind_bn') or '').strip(), tag=tag,
        address=(x.get('address_bn') or '').strip() or (up + ', জয়পুরহাট' if up else ''),
        phones=uniq_phones(x.get('phones')), time=(x.get('hours_bn') or '').strip(),
        price=(x.get('price_info_bn') or '').strip(),
        chips=[c.strip() for c in x.get('services_bn') or [] if c.strip()],
        rows=[{'label': 'ধারণক্ষমতা', 'value': cap, 'icon': 'users'}] if cap else [],
        website=site if site.startswith(('https://', 'http://')) else '',
        mapQuery=r3_map(x),
        lat=lat, lng=lng, icon=icon,
        confidence=x.get('confidence'), sources=src(x), nameEn=sub_en(x), checked=CHECKED3,
    )


def r3_merge(k, new, first=True):
    """Puts the new real items first (or after the other real ones). An older
    real entry for the same place (same name or phone) is replaced; samples
    stay for demo mode."""
    keys = set()
    names = set()
    for it in new:
        keys |= phone_keys(it.get('phones'))
        names |= {r3_key(it['name']), r3_key(it.get('nameEn'))} - {''}
    old = [it for it in cats[k]['items']
           if it.get('sample') or not ((phone_keys(it.get('phones')) & keys)
                                       or r3_key(it['name']) in names
                                       or (it.get('nameEn') and r3_key(it['nameEn']) in names))]
    if first:
        cats[k]['items'] = new + old
    else:
        cats[k]['items'] = ([it for it in old if not it.get('sample')] + new
                            + [it for it in old if it.get('sample')])


def r3_of(cat, pred=lambda x: True):
    return [x for x in R3 if x.get('category') == cat and pred(x)]


# Community centres: halls named in news reports and yellow pages. No source
# gives capacity, AC or rent, so the AC filter only applies to the samples.
r3_merge('community', [r3_item(x) for x in r3_of('community')])

# Motorbike showrooms that also service and sell parts (Bajaj's store
# locator, bikebd.com). No plumber, electrician or AC repair was found online.
def is_phone_service(x):
    return 'xiaomi' in (x.get('name_en') or '').lower()


r3_merge('serviceman', [r3_item(x, tag='মোটরসাইকেল', icon='wrench')
                        for x in r3_of('serviceman', lambda x: not is_phone_service(x))])
if 'মোটরসাইকেল' not in cats['serviceman'].get('filters', []):
    cats['serviceman']['filters'] = ['সব', 'মোটরসাইকেল'] + cats['serviceman'].get('filters', ['সব'])[1:]
# A phone brand's service point is a repair shop: it goes with IT services.
r3_merge('it', [r3_item(x, tag='মেরামত', icon='laptop') for x in r3_of('serviceman', is_phone_service)]
         + [r3_item(x, tag='প্রশিক্ষণ', icon='laptop') for x in r3_of('it')])

# Coaching centres: Udvash-Unmesh's branch page and the Cybo directory. The
# sources do not say which classes each one teaches, so they carry no tag.
r3_merge('coaching', [r3_item(x, icon='board') for x in r3_of('coaching')])

# Libraries: the district public library (BSS news, Cybo) and local
# পাঠাগার listed on Cybo. Shishu Academy is a government body.
def library_tag(x):
    en = x.get('name_en') or ''
    return 'সরকারি' if 'Government' in en or 'Shishu Academy' in en else 'পাঠাগার'


r3_merge('library', [r3_item(x, tag=library_tag(x), icon='library') for x in r3_of('library')])

# Offices for people going abroad to work: DEMO, the TTC and the Probashi
# Kallyan Bank branch inside it.
r3_merge('probashi', [r3_item(x, tag='সরকারি', icon='landmark') for x in r3_of('probashi')])

# Internet: the one district-licensed ISP found in the ISPAB member list.
r3_merge('wifi', [r3_item(x, icon='wifi') for x in r3_of('wifi')])

# More eateries: a meal hotel in Akkelpur named in two news reports, and
# places mapped on OpenStreetMap (some around 2017, so low confidence) or
# listed by one aggregator. A tea stall seen only in a "nearby" list, with no
# map point or phone, is left out. "Moaj" keeps its English name: the
# source gives no Bangla spelling.
R3_FOOD_TAG = {'খাবার হোটেল': 'বাংলা', 'ফাস্ট ফুড': 'ফাস্ট ফুড', 'ক্যাফে': 'ক্যাফে'}


def r3_food(x):
    x = dict(x)
    if x.get('name_en') == 'Moaj':
        x['name_bn'] = ''
    kind = re.sub(r'\s*\(.*\)', '', x.get('kind_bn') or '')
    return r3_item(x, tag=R3_FOOD_TAG.get(kind), icon='utensils')


r3_merge('restaurant', [r3_food(x) for x in r3_of('restaurant', lambda x: x.get('lat') or x.get('phones')
                                                    or x.get('confidence') == 'high')], first=False)
r3_merge('hostel', [r3_item(x, tag={'male': 'ছাত্র', 'female': 'ছাত্রী'}.get(x.get('gender')), sub='হোস্টেল')
                    for x in r3_of('hostel')], first=False)
r3_merge('mess', [r3_item(x, tag={'male': 'ছাত্র', 'female': 'ছাত্রী'}.get(x.get('gender')), sub='মেস')
                  for x in r3_of('mess')], first=False)

# Any other category: a plain card, tagged when the item names one of its filters.
R3_DONE = {'community', 'serviceman', 'it', 'coaching', 'library', 'probashi', 'wifi', 'restaurant', 'hostel',
           'mess', 'brtc'}
for k in sorted({x['category'] for x in R3} - R3_DONE):
    assert cats[k]['template'] == 'list', 'round3: %s cards are not plain list cards' % k
    r3_merge(k, [r3_item(x, tag=x.get('tag') if x.get('tag') in cats[k].get('filters', []) else None)
                 for x in r3_of(k)])

# BRTC: no regular service or counter in Joypurhat, only Eid specials from Dhaka.
if r3_of('brtc'):
    cats['brtc']['note'] = ('জয়পুরহাটে বিআরটিসির নিয়মিত বাস বা কাউন্টারের খোঁজ পাওয়া যায়নি। ঈদের আগে ঢাকার '
                            'মতিঝিল বাস ডিপো থেকে ঢাকা–জয়পুরহাট ঈদ স্পেশাল বাস চলেছে (২০২৪ সালের খবর: ডেইলি স্টার '
                            'বাংলা, রাইজিংবিডি, টিবিএস)। সময় ও টিকিট ঈদের আগে সেই ডিপোতে জেনে নিন।')

ticker = [
    {'text': 'জরুরি দরকারে ৯৯৯ নম্বরে কল করুন, ২৪ ঘণ্টা খোলা', 'color': 'red'},
    {'text': 'ডাক্তারের নাম লিখে খুঁজুন, চেম্বার আর সিরিয়ালের নম্বর পেয়ে যাবেন', 'color': 'teal'},
    {'text': 'ট্রেন এখন আনুমানিক কোথায়, ট্রেনের পাতায় দেখুন', 'color': 'blue'},
    {'text': 'জেলার %sটি রেস্টুরেন্ট ও মিষ্টির দোকান এক জায়গায়, ম্যাপসহ'
             % to_bn(str(sum(1 for i in cats['restaurant']['items'] if not i.get('sample')))), 'color': 'orange'},
    {'text': 'বাসা বা মেসের রুম খালি? To-Let দিন বিনা খরচে', 'color': 'cyan'},
]

# Home screen groups: title, line under it, colour group, icon, categories.
home_sections = [
    ('জরুরি সেবা', 'বিপদে এক চাপে কল', 'red', 'alert', ['emergency', 'fire', 'ambulance', 'helpline']),
    ('স্বাস্থ্য', 'হাসপাতাল, ডাক্তার ও সিরিয়াল', 'teal', 'hospital', ['hospital', 'diagnostic', 'dental']),
    ('যাতায়াত', 'বাস ও ট্রেনের টিকিট, ট্রেনের অবস্থান', 'blue', 'bus', ['bus', 'train', 'brtc']),
    ('খাবার ও থাকা', 'রেস্টুরেন্ট, ঘরের খাবার, হোটেল', 'orange', 'utensils', ['restaurant', 'homefood', 'cook', 'hotel']),
    ('বাসা ও মেস', 'খালি রুম, ভাড়া আর To-Let', 'cyan', 'house', ['house', 'mess', 'hostel']),
    ('ঘোরাঘুরি', 'দর্শনীয় স্থান ও ইতিহাস', 'green', 'map', ['spots', 'tourism', 'history']),
    ('শিক্ষা', 'স্কুল, কলেজ, মাদ্রাসা ও কোচিং', 'indigo', 'cap', ['school', 'madrasa', 'coaching', 'library']),
    ('কেনাকাটা ও সার্ভিস', 'দোকান, মিস্ত্রি, বিদ্যুৎ ও ইন্টারনেট', 'purple', 'store',
     ['shop', 'shopreg', 'it', 'serviceman', 'power', 'wifi']),
    ('অনুষ্ঠান ও সাজ', 'কমিউনিটি সেন্টার, ডেকোরেশন, পার্লার', 'pink', 'party',
     ['community', 'decoration', 'photo', 'parlour', 'studio']),
    ('সরকারি ও তথ্য', 'অফিস, ব্যাংক, পাসপোর্ট ও সংবাদ', 'slate', 'building',
     ['upazila', 'representative', 'passport', 'probashi', 'bank', 'journalist', 'newspaper']),
]
listed = [k for *_, keys in home_sections for k in keys]
assert sorted(listed) == sorted(P['order']), set(P['order']) ^ set(listed)

# Colour group of each service tile, as in the prototype.
CAT_COLOR = {
    'red': 'emergency fire ambulance helpline', 'teal': 'hospital diagnostic dental',
    'orange': 'hotel restaurant homefood cook', 'indigo': 'school madrasa coaching library',
    'blue': 'bus train brtc', 'green': 'spots tourism history', 'purple': 'shop it shopreg',
    'slate': 'journalist newspaper representative upazila probashi passport',
    'amber': 'power wifi serviceman', 'cyan': 'house mess hostel community',
    'pink': 'decoration photo parlour studio', 'emerald': 'bank',
}
for color, keys in CAT_COLOR.items():
    for k in keys.split():
        cats[k]['color'] = color
assert all(c.get('color') for c in cats.values())

# The prototype's To-Let text promised photos and a one-tap "rented" button.
# Posts go by SMS, which carries no photos, and reach the app only with the
# next update, so the text says that instead.
POST_INTRO = ('ফর্ম জমা দিলে এসএমএসে অ্যাপের টিমের কাছে যাবে। তথ্য মিলিয়ে দেখার পর পরের আপডেটে '
              'বিজ্ঞাপন সবার কাছে দেখাবে। রুম ভাড়া হয়ে গেলে আবার জানাবেন, তালিকা থেকে সরিয়ে দেওয়া হবে।')
for k in ('house', 'mess'):
    post = cats[k]['post']
    post['intro'] = POST_INTRO
    post['bannerSub'] = post['bannerSub'].replace('ছবি ও খালি রুমের সংখ্যাসহ', 'খালি রুমের সংখ্যা ও ভাড়াসহ')
    for f in post['fields']:
        if isinstance(f, dict) and f.get('type') == 'photo':
            f['label'] = 'ছবি'

# Sites with real rent ads for Joypurhat (checked 2026-10-12). Their ads
# carry owners' private numbers, so the app links to the sites instead of
# copying the ads.
TOLET_LINKS = {x['site'].split(' ')[0]: x for x in PRT['tolet_sources']}
cats['house']['links'] = [
    {'label': 'thetolet.com', 'url': TOLET_LINKS['thetolet.com']['search_url'],
     'sub': 'জয়পুরহাটের ফ্যামিলি বাসার বিজ্ঞাপন, ৪,০০০–৭,০০০ টাকা (সর্বশেষ জুন ২০২৬)'},
    {'label': 'toletbd.app', 'url': TOLET_LINKS['toletbd.app']['search_url'],
     'sub': 'বাসা, রুম ও ব্যাচেলর সিটের বিজ্ঞাপন (বেশিরভাগ ২০২৪–২৫ সালের, পুরনো হতে পারে)'},
]
cats['mess']['links'] = [
    {'label': 'toletbd.app', 'url': TOLET_LINKS['toletbd.app']['search_url'],
     'sub': 'ব্যাচেলর রুম ও সিটের বিজ্ঞাপন (বেশিরভাগ ২০২৪–২৫ সালের, পুরনো হতে পারে)'},
]

# Real photos, once someone adds them in data_sources/photos.json:
#   {"photos": [{"category": "spots", "name": "<item name as in the app>",
#                "photos": [{"src": "assets/photos/paharpur-1.jpg", "credit": "মোনেম, নিজের তোলা"}]}]}
# A bundled photo must exist (directly inside assets/photos/); a web photo
# needs an https address. Without photos the app keeps the drawn pictures.
PHOTOS_FILE = SRC + 'photos.json'
photo_count = 0
if os.path.exists(PHOTOS_FILE):
    for e in json.load(open(PHOTOS_FILE, encoding='utf-8')).get('photos', []):
        c = cats.get(e.get('category'))
        assert c is not None, 'photos.json: unknown category %r' % e.get('category')
        match = [it for it in c.get('items', []) if it['name'] == e.get('name')]
        assert match, 'photos.json: no %s item named %r' % (e['category'], e.get('name'))
        pics = []
        for ph in e.get('photos', []):
            ph = ph if isinstance(ph, dict) else {'src': ph}
            path = ph.get('src', '')
            if path.startswith('https://'):
                pass
            else:
                assert path.startswith('assets/photos/') and path.count('/') == 2, \
                    'photos.json: put the file directly in assets/photos/ (%s)' % path
                assert os.path.exists(path), 'photos.json: file not found: %s' % path
            pics.append({k: v for k, v in (('src', path), ('credit', ph.get('credit', ''))) if v})
        match[0]['photos'] = pics
        photo_count += len(pics)

# Every real item says where it came from and how sure we are. Items that
# only came with the author's prototype name it as their source, plus their
# own website; one source, or none on the web, means low confidence.
PROTO_SOURCE = 'Monem-এর অ্যাপের তথ্য'
for c in cats.values():
    for it in c.get('items', []):
        if it.get('sample'):
            continue
        if not it.get('sources'):
            own = [u for u in ((it.get('link') or {}).get('url'), it.get('website')) if u]
            it['sources'] = [PROTO_SOURCE] + own
        if not it.get('confidence'):
            web = [u for u in it['sources'] if u.startswith('http')]
            it['confidence'] = 'medium' if len(web) >= 2 else 'low'

out = {
    'meta': {'checked': CHECKED, 'version': 2},
    'ticker': ticker,
    'homeSections': [{'title': t, 'sub': sub, 'color': color, 'icon': icon, 'keys': keys}
                     for t, sub, color, icon, keys in home_sections],
    'fields': fields,
    'docBook': conv_form(P['docBook']),
    'order': P['order'],
    'categories': cats,
    'doctors': DOCTORS,
    'transport': transport,
    'notices': notices,
}
with open(OUT, 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)

# summary
print('categories', len(cats))
for k in P['order']:
    c = cats[k]
    items = c.get('items') or []
    print('  %-14s %-8s real=%d sample=%d' % (k, c['template'], sum(1 for i in items if not i.get('sample')),
                                              sum(1 for i in items if i.get('sample'))))
print('photos', photo_count)
print('doctors', len(DOCTORS), 'trains', len(trains), 'bus operators', len(bus_list), 'demo trips', len(demo_trips))
