"""Draws the launcher icons and the Play Store images.

    flutter test tool/store_shots_test.dart   # real screenshots -> build/store_shots/
    python3 tool/store_graphics.py            # icons + store images

Needs the Python Playwright package and its Chromium. Text is set in the
app's own font (assets/fonts, Hind Siliguri). Writes:

    android/app/src/main/res/mipmap-*/ic_launcher*.png, launch_image.png
    store/icon-512.png, store/feature-graphic-1024x500.png, store/promo-*.png
"""
import base64
import pathlib
import sys

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / 'android/app/src/main/res'
STORE = ROOT / 'store'
SHOTS = ROOT / 'build/store_shots'
FONTS = ROOT / 'assets/fonts'

DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

FONT_CSS = ''.join(
    f"@font-face{{font-family:'Hind Siliguri';font-weight:{w};"
    f"src:url('{(FONTS / f'HindSiliguri-{n}.ttf').as_uri()}')}}"
    for n, w in (('Regular', 400), ('SemiBold', 600), ('Bold', 700))
)

# ---------------------------------------------------------------- the mark
# A map pin holding four service tiles in the app's group colours, drawn in
# a 100 x 100 box: the pin spans x 20-80 and y 10-92.
PIN = 'M50 92 C44 82 20 62 20 40 A30 30 0 1 1 80 40 C80 62 56 82 50 92 Z'
TILES = [(33, 23, '#F43F5E'), (52, 23, '#14B8A6'), (33, 42, '#0EA5E9'), (52, 42, '#F59E0B')]


def mark(shadow=True):
    tiles = ''.join(f'<rect x="{x}" y="{y}" width="15" height="15" rx="4" fill="{c}"/>' for x, y, c in TILES)
    filt = ' filter="url(#drop)"' if shadow else ''
    return (
        '<defs><linearGradient id="pinFill" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E7F7F4"/></linearGradient>'
        '<filter id="drop" x="-30%" y="-30%" width="160%" height="160%">'
        '<feDropShadow dx="0" dy="2.2" stdDeviation="2.4" flood-color="#042F2E" flood-opacity="0.35"/></filter></defs>'
        f'<path d="{PIN}" fill="url(#pinFill)"{filt}/>{tiles}'
    )


def mono_mark():
    holes = ''.join(f'<rect x="{x}" y="{y}" width="15" height="15" rx="4" fill="black"/>' for x, y, _ in TILES)
    return (
        f'<defs><mask id="m"><rect width="100" height="100" fill="white"/>{holes}</mask></defs>'
        f'<path d="{PIN}" fill="white" mask="url(#m)"/>'
    )


BG_DEFS = (
    '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
    '<stop offset="0" stop-color="#14B8A6"/><stop offset="0.55" stop-color="#0F766E"/>'
    '<stop offset="1" stop-color="#134E4A"/></linearGradient>'
)


def background(w, h):
    return (
        f'<defs>{BG_DEFS}</defs><rect width="{w}" height="{h}" fill="url(#bg)"/>'
        f'<circle cx="{w * 0.86}" cy="{h * 0.08}" r="{w * 0.44}" fill="#FFFFFF" opacity="0.10"/>'
        f'<circle cx="{w * 0.06}" cy="{h * 0.98}" r="{w * 0.30}" fill="#FFFFFF" opacity="0.06"/>'
    )


def placed(inner, size, cx, cy):
    """The 100-box mark scaled to `size` units tall, its middle at cx, cy."""
    s = size / 82  # the pin is 82 units tall
    return f'<g transform="translate({cx - 50 * s} {cy - 51 * s}) scale({s})">{inner}</g>'


def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'


# Adaptive icon layers are 108 x 108 dp; launchers show the middle 72 dp and
# may cut to a 66 dp circle, so the pin stays 56 dp tall.
FOREGROUND = svg(108, 108, placed(mark(), 56, 54, 54))
MONOCHROME = svg(108, 108, placed(mono_mark(), 56, 54, 54))
BACKGROUND = svg(108, 108, background(108, 108))
# Older phones: a rounded square with the pin, 48 x 48 dp with a 2 dp edge.
LEGACY = svg(48, 48, (
    f'<defs>{BG_DEFS}<clipPath id="r"><rect x="2" y="2" width="44" height="44" rx="10"/></clipPath></defs>'
    f'<g clip-path="url(#r)"><rect x="2" y="2" width="44" height="44" fill="url(#bg)"/>'
    '<circle cx="42" cy="5" r="20" fill="#FFFFFF" opacity="0.10"/></g>'
    + placed(mark(), 32, 24, 24.5)
))
# Play Store icon: full square, Google Play rounds the corners itself.
STORE_ICON = svg(512, 512, background(512, 512) + placed(mark(), 320, 256, 262))


def page_html(body, w, h, transparent=False, css=''):
    bg = 'transparent' if transparent else '#FFFFFF'
    return (
        f'<!doctype html><html><head><meta charset="utf-8"><style>{FONT_CSS}'
        f'html,body{{margin:0;padding:0;width:{w}px;height:{h}px;overflow:hidden;background:{bg}}}'
        f"body{{font-family:'Hind Siliguri',sans-serif}}svg{{display:block}}{css}</style></head>"
        f'<body>{body}</body></html>'
    )


class Renderer:
    def __init__(self, browser, tmp):
        self.browser = browser
        self.tmp = tmp

    def render(self, html, w, h, out, transparent=False, scale=1):
        page = self.browser.new_page(viewport={'width': w, 'height': h}, device_scale_factor=scale)
        # A file page, so the local font files load.
        f = self.tmp / 'page.html'
        f.write_text(html, encoding='utf-8')
        page.goto(f.as_uri())
        page.evaluate('document.fonts.ready')
        out.parent.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(out), omit_background=transparent)
        page.close()
        print('wrote', out.relative_to(ROOT))

    def svg_png(self, svg_text, w_dp, h_dp, factor, out, transparent=True):
        self.render(page_html(svg_text.replace('<svg ', f'<svg style="width:{w_dp}px;height:{h_dp}px" ', 1),
                              w_dp, h_dp, transparent), w_dp, h_dp, out, transparent, scale=factor)


def icons(r):
    for name, factor in DENSITIES.items():
        d = RES / f'mipmap-{name}'
        r.svg_png(FOREGROUND, 108, 108, factor, d / 'ic_launcher_foreground.png')
        r.svg_png(MONOCHROME, 108, 108, factor, d / 'ic_launcher_monochrome.png')
        r.svg_png(BACKGROUND, 108, 108, factor, d / 'ic_launcher_background.png', transparent=False)
        r.svg_png(LEGACY, 48, 48, factor, d / 'ic_launcher.png')
        # Splash on Android 11 and older: the same rounded icon, 96 dp.
        r.svg_png(LEGACY, 96, 96, factor, d / 'launch_image.png')
    r.svg_png(STORE_ICON, 512, 512, 1, STORE / 'icon-512.png', transparent=False)
    # Google Play asks for a 32-bit PNG.
    from PIL import Image
    Image.open(STORE / 'icon-512.png').convert('RGBA').save(STORE / 'icon-512.png')


def data_uri(path):
    return 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode()


def status_bar_colour(path):
    from PIL import Image
    px = Image.open(path).convert('RGB').getpixel((540, 6))
    return '#%02X%02X%02X' % px


def phone(shot, width):
    """A phone frame around a real screenshot, with a drawn status bar."""
    bar = status_bar_colour(shot)
    sb = round(width * 24 / 360)  # 24 dp status bar on a 360 dp screen
    fs = round(sb * 0.52)
    return f'''
<div class="phone" style="width:{width}px">
  <div class="screen">
    <div class="status" style="height:{sb}px;background:{bar};font-size:{fs}px">
      <span>১০:৩০</span>
      <span class="icons"><i class="sig"></i><i class="wifi"></i><i class="bat"></i></span>
    </div>
    <img src="{data_uri(shot)}" style="width:{width}px;display:block">
  </div>
</div>'''


PHONE_CSS = '''
.phone{position:absolute;padding:16px;border-radius:78px;background:linear-gradient(145deg,#1F2937,#0B1220);
  box-shadow:0 40px 90px rgba(2,20,25,.45),0 0 0 3px rgba(255,255,255,.10) inset}
.screen{border-radius:62px;overflow:hidden;background:#fff}
.status{display:flex;align-items:center;justify-content:space-between;padding:0 34px;color:#10201F;font-weight:600}
.icons{display:flex;gap:10px;align-items:center}
.icons i{display:inline-block;background:#10201F;opacity:.85}
.sig{width:20px;height:16px;clip-path:polygon(100% 0,100% 100%,0 100%)}
.wifi{width:20px;height:16px;border-radius:20px 20px 0 0;clip-path:polygon(50% 100%,0 20%,100% 20%)}
.bat{width:12px;height:20px;border-radius:3px}
'''

# (file, screenshot, background colours, headline, line below)
PROMOS = [
    ('promo-1-home', 'home', ('#14B8A6', '#0F766E', '#134E4A'),
     'জয়পুরহাটের দরকারি সব তথ্য, এক অ্যাপে',
     '১০টি ভাগে সাজানো সেবা, সবার উপরে জরুরি নম্বর'),
    ('promo-2-emergency', 'emergency', ('#FB7185', '#E11D48', '#9F1239'),
     'বিপদে এক চাপে কল',
     '৯৯৯, ফায়ার সার্ভিস, অ্যাম্বুলেন্স আর সরকারি হেল্পলাইন'),
    ('promo-3-doctors', 'doctors', ('#2DD4BF', '#0E7490', '#164E63'),
     '১২৫ জন ডাক্তার, চেম্বার ও সময়',
     'নাম, রোগ বা চেম্বার দিয়ে খুঁজুন, এসএমএসে সিরিয়াল চান'),
    ('promo-4-diagnostic', 'diagnostic', ('#5EEAD4', '#0F766E', '#115E59'),
     '৪৬টি ডায়াগনস্টিক সেন্টার',
     'উপজেলা বেছে দেখুন, ঠিকানা আর ফোন নম্বর সহ'),
    ('promo-5-train', 'train_live', ('#7DD3FC', '#0369A1', '#0C4A6E'),
     'ট্রেন এখন কোথায়?',
     'সময়সূচি থেকে আনুমানিক অবস্থান, আসলটা জানতে এক চাপে এসএমএস'),
    ('promo-6-bus', 'bus', ('#A5B4FC', '#4F46E5', '#312E81'),
     'বাসের কাউন্টার, ভাড়া ও অনলাইন টিকিট',
     'এসি বা নন-এসি কোচ বেছে দেখুন, টিকিটের সাইটে সরাসরি যান'),
]

BRAND = svg(46, 46, placed(mark(shadow=False), 44, 23, 23))


def promo(r, name, shot, colours, title, sub):
    a, b, c = colours
    body = f'''
<div class="bg" style="background:linear-gradient(160deg,{a} 0%,{b} 48%,{c} 100%)">
  <div class="blob" style="left:640px;top:-160px;width:620px;height:620px"></div>
  <div class="blob" style="left:-220px;top:1180px;width:560px;height:560px;opacity:.06"></div>
  <div class="brand">{BRAND}<span>Joypurhat</span></div>
  <div class="head"><h1>{title}</h1><p>{sub}</p></div>
  <div style="position:absolute;left:{(1080 - 732) // 2}px;top:560px">{phone(SHOTS / f'{shot}.png', 700)}</div>
</div>'''
    css = PHONE_CSS + '''
.bg{position:relative;width:1080px;height:1920px;overflow:hidden}
.blob{position:absolute;border-radius:50%;background:#fff;opacity:.10}
.brand{position:absolute;left:84px;top:84px;display:flex;align-items:center;gap:14px;color:#fff;
  font-size:38px;font-weight:600;letter-spacing:.3px}
.head{position:absolute;left:84px;right:84px;top:178px}
h1{margin:0;color:#fff;font-size:80px;line-height:1.22;font-weight:700;text-shadow:0 4px 18px rgba(0,0,0,.18)}
p{margin:22px 0 0;color:rgba(255,255,255,.92);font-size:40px;line-height:1.4;font-weight:400}
'''
    r.render(page_html(body, 1080, 1920, css=css), 1080, 1920, STORE / f'{name}.png')


def feature(r):
    chips = [('জরুরি', '#E11D48'), ('স্বাস্থ্য', '#0E7490'), ('যাতায়াত', '#0369A1'),
             ('খাবার', '#EA580C'), ('ঘোরাঘুরি', '#15803D')]
    chip_html = ''.join(
        f'<span class="chip"><i style="background:{c}"></i>{t}</span>' for t, c in chips)
    body = f'''
<div class="bg">
  <div class="blob" style="left:560px;top:-260px;width:640px;height:640px"></div>
  <div class="blob" style="left:-160px;top:300px;width:420px;height:420px;opacity:.06"></div>
  <div class="brand">{BRAND}<span>Joypurhat</span></div>
  <h1>জয়পুরহাটের দরকারি<br>সব তথ্য, এক অ্যাপে</h1>
  <p>হাসপাতাল, ডাক্তার, ট্রেন, বাস আর জরুরি নম্বর</p>
  <div class="chips">{chip_html}</div>
  <div style="position:absolute;left:690px;top:58px;transform:rotate(-6deg)">{phone(SHOTS / 'home.png', 280)}</div>
</div>'''
    css = PHONE_CSS.replace('padding:16px;border-radius:78px', 'padding:8px;border-radius:36px').replace(
        'border-radius:62px', 'border-radius:29px').replace('padding:0 34px', 'padding:0 16px').replace(
        'width:20px;height:16px', 'width:9px;height:7px').replace('width:12px;height:20px', 'width:6px;height:9px') + '''
.bg{position:relative;width:1024px;height:500px;overflow:hidden;
  background:linear-gradient(135deg,#14B8A6 0%,#0F766E 52%,#134E4A 100%)}
.blob{position:absolute;border-radius:50%;background:#fff;opacity:.10}
.brand{position:absolute;left:60px;top:52px;display:flex;align-items:center;gap:12px;color:#fff;font-size:30px;font-weight:600}
h1{position:absolute;left:60px;top:116px;margin:0;color:#fff;font-size:52px;line-height:1.25;font-weight:700}
p{position:absolute;left:60px;top:262px;margin:0;color:rgba(255,255,255,.92);font-size:26px}
.chips{position:absolute;left:60px;top:330px;width:600px;display:flex;flex-wrap:wrap;gap:10px}
.chip{display:inline-flex;align-items:center;gap:8px;background:rgba(255,255,255,.95);color:#10201F;
  border-radius:999px;padding:6px 16px 4px 12px;font-size:20px;font-weight:600}
.chip i{width:12px;height:12px;border-radius:50%;display:inline-block}
'''
    r.render(page_html(body, 1024, 500, css=css), 1024, 500, STORE / 'feature-graphic-1024x500.png')


def main():
    missing = [s for _, s, *_ in PROMOS if not (SHOTS / f'{s}.png').exists()]
    if missing:
        sys.exit('Run "flutter test tool/store_shots_test.dart" first; missing: ' + ', '.join(missing))
    tmp = ROOT / 'build/store_graphics'
    tmp.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        r = Renderer(browser, tmp)
        icons(r)
        feature(r)
        for args in PROMOS:
            promo(r, *args)
        browser.close()


if __name__ == '__main__':
    main()
