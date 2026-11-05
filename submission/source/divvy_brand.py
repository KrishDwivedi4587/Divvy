"""Shared Divvy brand system and python-pptx drawing helpers.

Used by build_presentation.py and build_poster.py so the deck and the poster
share one palette, one type system, one icon set and one diagram style.
Colours are taken from the app's own design tokens (src/ui/theme/tokens.ts).
"""
import os
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE, MSO_CONNECTOR
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.oxml.ns import qn
from lxml import etree
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(os.path.dirname(HERE), "assets")

# ---- Palette (from src/ui/theme/tokens.ts, plus a light ramp for print) ----
INK = "0B1220"        # navy900 — app background, primary text on light
NAVY800 = "131C2E"    # raised
NAVY700 = "1B2740"    # elevated
NAVY600 = "24324F"    # overlay / border
NAVY500 = "35456A"
SLATE100 = "F5F7FA"   # text on dark
SLATE300 = "A9B4C7"
SLATE500 = "7A879E"
INDIGO = "6B4EEA"     # the single accent
INDIGO_DK = "5A3FD1"
INDIGO_LT = "9C89F5"  # accent text on dark backgrounds
INDIGO_TINT = "EDE9FD"
BG = "F4F6FA"         # light canvas (cool, not beige)
CARD = "FFFFFF"
LINE = "DDE2EB"
TEXT2 = "48546A"
MUTED = "7A859A"
MINT = "34D399"
MINT_DK = "0E9F6E"
MINT_TINT = "E3F7EF"
RED = "D9434B"
RED_TINT = "FCE9EA"
AMBER = "FBBF24"
ORANGE = "FB923C"
PEOPLE = {"Aarav": ("AA", ORANGE), "Priya": ("PR", AMBER), "Zoya": ("ZO", MINT)}

HEAD = "Segoe UI Semibold"
BODY = "Segoe UI"


def rgb(h):
    return RGBColor.from_string(h)


def asset(*p):
    return os.path.join(ASSETS, *p)


def icon_path(key, color="indigo"):
    return asset("icons", f"{key}_{color}.png")


# ---------------------------------------------------------------- text ----
def text(slide, x, y, w, h, runs, size=14, color=INK, font=BODY, bold=False,
         align="l", anchor="t", spacing=None, line=None, name=None, wrap=True,
         para_after=0):
    """Add a text box. `runs` is a str, or a list of paragraphs; each paragraph
    is a str or a list of (text, {opts}) runs. Opts: size,color,font,bold,italic,spc."""
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    if name:
        tb.name = name
    tf = tb.text_frame
    tf.word_wrap = wrap
    tf.auto_size = None
    for m in ("margin_left", "margin_right", "margin_top", "margin_bottom"):
        setattr(tf, m, 0)
    tf.vertical_anchor = {"t": MSO_ANCHOR.TOP, "m": MSO_ANCHOR.MIDDLE, "b": MSO_ANCHOR.BOTTOM}[anchor]
    paras = runs if isinstance(runs, list) else [runs]
    for i, para in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = {"l": PP_ALIGN.LEFT, "c": PP_ALIGN.CENTER, "r": PP_ALIGN.RIGHT}[align]
        if line:
            p.line_spacing = line
        if para_after:
            p.space_after = Pt(para_after)
        items = para if isinstance(para, list) else [(para, {})]
        for t, o in items:
            r = p.add_run()
            r.text = t
            f = r.font
            f.size = Pt(o.get("size", size))
            f.bold = o.get("bold", bold)
            f.italic = o.get("italic", False)
            f.name = o.get("font", font)
            f.color.rgb = rgb(o.get("color", color))
            spc = o.get("spc", spacing)
            if spc:
                r._r.get_or_add_rPr().set("spc", str(int(spc * 100)))
    return tb


def eyebrow(slide, x, y, label, color=INDIGO, w=8):
    return text(slide, x, y, w, 0.25, label.upper(), size=11, color=color, font=HEAD, spacing=1.6)


# -------------------------------------------------------------- shapes ----
def _line(shape, color, width):
    if color is None:
        shape.line.fill.background()
    else:
        shape.line.color.rgb = rgb(color)
        shape.line.width = Pt(width)


def rect(slide, x, y, w, h, fill=CARD, line=None, lw=1, radius=0.0, name=None, dash=False, shape=None):
    kind = shape or (MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE)
    s = slide.shapes.add_shape(kind, Inches(x), Inches(y), Inches(w), Inches(h))
    if radius and kind == MSO_SHAPE.ROUNDED_RECTANGLE:
        s.adjustments[0] = min(0.5, radius / min(w, h))
    if fill is None:
        s.fill.background()
    else:
        s.fill.solid()
        s.fill.fore_color.rgb = rgb(fill)
    _line(s, line, lw)
    if dash and line:
        ln = s.line._get_or_add_ln()
        d = etree.SubElement(ln, qn("a:prstDash"))
        d.set("val", "dash")
    _strip_style(s)
    if name:
        s.name = name
    s.text_frame.text = ""
    return s


def _strip_style(shape):
    """Remove the theme style reference python-pptx adds, so no theme shadow
    or effect is applied: every fill and line here is set explicitly."""
    st = shape._element.find(qn("p:style"))
    if st is not None:
        shape._element.remove(st)


def oval(slide, x, y, w, h, fill=INDIGO, line=None, lw=1, name=None, dash=False):
    return rect(slide, x, y, w, h, fill=fill, line=line, lw=lw, name=name, dash=dash, shape=MSO_SHAPE.OVAL)


def shape_text(s, runs, size=12, color=INK, font=BODY, bold=False, align="c", anchor="m", margin=0.06, line=None):
    tf = s.text_frame
    tf.word_wrap = True
    for m in ("margin_left", "margin_right", "margin_top", "margin_bottom"):
        setattr(tf, m, Inches(margin))
    tf.vertical_anchor = {"t": MSO_ANCHOR.TOP, "m": MSO_ANCHOR.MIDDLE, "b": MSO_ANCHOR.BOTTOM}[anchor]
    paras = runs if isinstance(runs, list) else [runs]
    for i, para in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = {"l": PP_ALIGN.LEFT, "c": PP_ALIGN.CENTER, "r": PP_ALIGN.RIGHT}[align]
        if line:
            p.line_spacing = line
        items = para if isinstance(para, list) else [(para, {})]
        for t, o in items:
            r = p.add_run()
            r.text = t
            r.font.size = Pt(o.get("size", size))
            r.font.bold = o.get("bold", bold)
            r.font.name = o.get("font", font)
            r.font.color.rgb = rgb(o.get("color", color))
    return s


def arrow(slide, x1, y1, x2, y2, color=INK, width=1.25, head=True, dash=False, both=False, name=None):
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    _strip_style(c)
    c.line.color.rgb = rgb(color)
    c.line.width = Pt(width)
    ln = c.line._get_or_add_ln()
    if dash:
        d = etree.SubElement(ln, qn("a:prstDash"))
        d.set("val", "dash")
    if both:
        h = etree.SubElement(ln, qn("a:headEnd"))
        h.set("type", "triangle"); h.set("w", "med"); h.set("len", "med")
    if head:
        t = etree.SubElement(ln, qn("a:tailEnd"))
        t.set("type", "triangle"); t.set("w", "med"); t.set("len", "med")
    if name:
        c.name = name
    return c


def picture(slide, path, x, y, w=None, h=None, name=None):
    with Image.open(path) as im:
        iw, ih = im.size
    if w is not None and h is None:
        h = w * ih / iw
    elif h is not None and w is None:
        w = h * iw / ih
    p = slide.shapes.add_picture(path, Inches(x), Inches(y), Inches(w), Inches(h))
    if name:
        p.name = name
    return p, w, h


def icon(slide, key, x, y, size=0.32, color="indigo"):
    return slide.shapes.add_picture(icon_path(key, color), Inches(x), Inches(y), Inches(size), Inches(size))


def icon_tile(slide, key, x, y, size=0.56, fill=INDIGO_TINT, color="indigo", radius=0.12, circle=False):
    if circle:
        oval(slide, x, y, size, size, fill=fill)
    else:
        rect(slide, x, y, size, size, fill=fill, radius=radius)
    pad = size * 0.24
    icon(slide, key, x + pad, y + pad, size - 2 * pad, color)


def logo(slide, x, y, d=0.42, on_dark=True, word=True, word_size=24, ring=None):
    """Divvy mark: two overlapping discs — a bill shared between people
    (the same construction as src/ui/BrandMark.tsx), then the wordmark."""
    first = SLATE100 if on_dark else INK
    ring = ring or (INK if on_dark else BG)
    overlap = d * 0.38
    oval(slide, x, y, d, d, fill=first, name="Logo disc 1")
    rw = d * 0.07
    oval(slide, x + d - overlap - rw, y - rw, d + 2 * rw, d + 2 * rw, fill=ring, name="Logo ring")
    oval(slide, x + d - overlap, y, d, d, fill=INDIGO, name="Logo disc 2")
    if word:
        text(slide, x + 2 * d - overlap + d * 0.42, y - d * 0.16, 3, d * 1.3, "Divvy", size=word_size,
             color=first, font=HEAD, anchor="m", name="Logo wordmark")


def avatar(slide, name, x, y, d=0.36, size=None):
    ini, col = PEOPLE[name]
    s = oval(slide, x, y, d, d, fill=col)
    shape_text(s, ini, size=size or max(8, d * 26), color=INK, font=HEAD, margin=0)
    return s


def status_dot(slide, x, y, implemented=True, d=0.13, on_dark=False):
    if implemented:
        oval(slide, x, y, d, d, fill=MINT_DK if not on_dark else MINT)
    else:
        oval(slide, x, y, d, d, fill=None, line=INDIGO if not on_dark else INDIGO_LT, lw=1.5)


def notes(slide, t):
    slide.notes_slide.notes_text_frame.text = t


# ------------------------------------------------------------ credits ----
# Name and course are confirmed. Enrollment number and the professor's name
# are left as fill-in lines: type them here and rebuild, or type over the
# underscores directly in PowerPoint.
STUDENT = "Krish Dwivedi"
PROGRAMME = "BSc Computer Science"
INSTITUTE = "UIT, Karnavati University"
COURSE = "Mobile Application Development"
ENROLLMENT = ""      # e.g. "KU2407U123"
SUBMITTED_TO = ""    # e.g. "Prof. A. Sharma"
BLANK = "_" * 22


def credit_lines(name_size=15):
    """Credit paragraphs shared by the cover, conclusion and poster."""
    return [
        [(STUDENT, {"font": HEAD, "color": None, "size": name_size})],
        [(f"{PROGRAMME}  ·  {INSTITUTE}", {})],
        [(f"{COURSE}  ·  2026", {})],
        [("Enrollment No.  ", {"font": HEAD}), (ENROLLMENT or BLANK, {})],
        [("Submitted to  ", {"font": HEAD}), (SUBMITTED_TO or BLANK, {})],
    ]


def credits(slide, x, y, w, h, on_dark=True, size=12, name_size=15, align="l", line=1.2, lines=None):
    main = SLATE100 if on_dark else INK
    sub = SLATE300 if on_dark else TEXT2
    paras = []
    for i, para in enumerate(lines or credit_lines(name_size)):
        runs = []
        for t, o in para:
            o = dict(o)
            if o.get("color", "x") is None or i == 0:
                o["color"] = main
            runs.append((t, o))
        paras.append(runs)
    return text(slide, x, y, w, h, paras, size=size, color=sub, line=line, align=align, name="Credits")
