"""Builds submission/Divvy_A3_Project_Poster.pptx — one A3 portrait page
(297 × 420 mm). Exported to Divvy_A3_Project_Poster.pdf with LibreOffice.

Run:  python build_poster.py
"""
import os
from pptx import Presentation
from pptx.util import Mm
from divvy_brand import *  # noqa: F401,F403

OUT = os.path.join(os.path.dirname(HERE), "Divvy_A3_Project_Poster.pptx")
W, H = 297 / 25.4, 420 / 25.4   # 11.693 × 16.535 in
M = 0.6                          # 15 mm safe print margin for all content

STUDENT = "Krish Dwivedi"
PROGRAMME = "BSc Computer Science"
INSTITUTE = "UIT, Karnavati University"
COURSE = "Mobile Application Development"

prs = Presentation()
prs.slide_width = Mm(297)
prs.slide_height = Mm(420)
prs.core_properties.title = "Divvy — A3 project poster"
prs.core_properties.author = STUDENT
s = prs.slides.add_slide(prs.slide_layouts[6])
s.background.fill.solid()
s.background.fill.fore_color.rgb = rgb(BG)
MOCK = lambda n: asset("mockups", f"phone_{n}.png")  # noqa: E731
RATIO = 836 / 1844
CW = W - 2 * M


def section(x, y, num, title, dark=False, w=6):
    text(s, x, y, w, 0.4, [[(f"{num}  ", {"color": INDIGO_LT if dark else INDIGO, "size": 14}), (title, {})]],
         size=19, font=HEAD, color=SLATE100 if dark else INK, anchor="m")


# ================================================================ HERO ====
HERO_H = 6.76
rect(s, 0, 0, W, HERO_H, fill=INK, name="Hero background")
logo(s, M, 0.6, d=0.44, on_dark=True, word_size=27)
text(s, W - M - 5.5, 0.55, 5.5, 0.6, [[(INSTITUTE, {"font": HEAD, "color": SLATE100})],
                                     [(f"{PROGRAMME}  ·  {COURSE}", {})]], size=11.5, color=SLATE300, align="r", line=1.15)
text(s, M, 1.38, 9, 0.28, f"{COURSE.upper()}  ·  PROJECT", size=11.5, color=INDIGO_LT, font=HEAD, spacing=1.8)
text(s, M, 1.55, CW, 0.95, [[("Split the bill. ", {}), ("Fairly.", {"color": INDIGO_LT})]], size=56, color=SLATE100, font=HEAD)
text(s, M, 2.57, CW, 0.4, "Divvy — intelligent, receipt-based bill splitting for iPhone and Android",
     size=18, color=SLATE100, font=HEAD)
text(s, M, 2.94, CW, 0.32, "Photograph a receipt, add the people, and see exactly what everyone owes — to the paisa.",
     size=13.5, color=SLATE300)
phones = [
    ("12_home_after", "Dashboard", False, 2.46),
    ("concept_scan_review", "Receipt scanning", True, 2.7),
    ("09_summary_top", "Bill summary", False, 2.94),
    ("08_people", "Participants", False, 2.7),
    ("14_home_history", "Bill history", False, 2.46),
]
widths = [h * RATIO for *_, h in phones]
gap = (CW - sum(widths)) / 4
x = M
base = 6.22
for (mk, label, concept, h), w in zip(phones, widths):
    picture(s, MOCK(mk), x, base - h, h=h, name=label)
    text(s, x - 0.35, base + 0.07, w + 0.7, 0.22, label, size=10.5, font=HEAD, color=SLATE100, align="c")
    text(s, x - 0.35, base + 0.28, w + 0.7, 0.18, "CONCEPT DESIGN" if concept else "APP SCREENSHOT", size=8,
         font=HEAD, color=INDIGO_LT if concept else SLATE500, align="c", spacing=1.0)
    x += w + gap

# ===================================================== PROBLEM | SOLUTION ====
top = HERO_H + 0.28
colw = (CW - 0.3) / 2
R1H = 2.42
section(M, top, "01", "The problem")
probs = [
    ("calc", "Totals worked out by hand, at the table"),
    ("allocate", "Equal splits ignore who ordered what"),
    ("percent", "GST on the service charge is guessed"),
    ("scale", "Rounding each share creates or loses paise"),
]
py = top + 0.52
for key, line in probs:
    icon_tile(s, key, M, py, 0.34, fill="E3E7EF", color="ink", circle=True)
    text(s, M + 0.48, py, colw - 0.5, 0.34, line, size=12, color=INK, anchor="m")
    py += 0.37
rect(s, M, top + R1H - 0.42, colw, 0.42, fill=RED_TINT, radius=0.08)
text(s, M + 0.16, top + R1H - 0.42, colw - 0.3, 0.42, [[("By hand  ", {"font": HEAD, "color": RED}),
                                                      ("₹1,025.33 ÷ 3 → 3 × ₹341.78 = ₹1,025.34", {"color": INK})]],
     size=11.5, anchor="m")
sx = M + colw + 0.3
rect(s, sx, top, colw, R1H, fill=INK, radius=0.14)
text(s, sx + 0.28, top + 0.14, colw - 0.5, 0.4, [[("02  ", {"color": INDIGO_LT, "size": 14}), ("Receipt-first solution", {})]],
     size=19, font=HEAD, color=SLATE100, anchor="m")
text(s, sx + 0.28, top + 0.6, colw - 0.56, 0.6,
     "Photograph the bill. Divvy reads it, you confirm it and assign items; service and GST are shared in proportion.",
     size=11, color=SLATE300, line=1.1)
for i, (nm, amt) in enumerate([("Aarav", "₹349.15"), ("Priya", "₹349.12"), ("Zoya", "₹327.06")]):
    yy = top + 1.1 + i * 0.32
    avatar(s, nm, sx + 0.28, yy, 0.27)
    text(s, sx + 0.66, yy, 1.5, 0.27, nm, size=11.5, color=SLATE100, anchor="m")
    text(s, sx + colw - 1.68, yy, 1.4, 0.27, amt, size=11.5, color=SLATE100, font=HEAD, anchor="m", align="r")
rect(s, sx + 0.28, top + 2.08, colw - 0.56, 0.01, fill=NAVY600)
text(s, sx + 0.28, top + 2.1, colw - 0.56, 0.28, [[("Σ ₹1,025.33", {"font": HEAD, "color": MINT}),
                                                ("  exactly the bill", {"color": SLATE300})]], size=11.5, anchor="m")

# ============================================================ WORKFLOW ====
wy = top + R1H + 0.25
section(M, wy, "03", "Application workflow")
leg_x = W - M - 2.75
status_dot(s, leg_x, wy + 0.14, True)
text(s, leg_x + 0.19, wy + 0.07, 1.1, 0.26, "Implemented", size=10, color=TEXT2, anchor="m")
status_dot(s, leg_x + 1.33, wy + 0.14, False)
text(s, leg_x + 1.52, wy + 0.07, 1.3, 0.26, "Final release", size=10, color=TEXT2, anchor="m")
flow = [("camera", "Capture / Upload", True), ("scan", "OCR", False), ("review", "Review", False),
        ("users", "Add people", True), ("allocate", "Split", True), ("receipt", "Summary", True)]
fw = CW / 6
d = 0.66
fy = wy + 0.52
for i, (key, lab, done) in enumerate(flow):
    cx = M + i * fw + fw / 2
    if i < 5:
        arrow(s, cx + d / 2 + 0.08, fy + d / 2, cx + fw - d / 2 - 0.08, fy + d / 2, color=NAVY500, width=1.5)
    oval(s, cx - d / 2, fy, d, d, fill=INDIGO if done else CARD, line=None if done else INDIGO, lw=1.75)
    icon(s, key, cx - 0.16, fy + d / 2 - 0.16, 0.32, "white" if done else "indigo")
    text(s, cx - fw / 2, fy + d + 0.07, fw, 0.25, lab, size=11.5, font=HEAD, align="c")

# ============================================ ARCHITECTURE | TECH STACK ====
ay = fy + d + 0.42
aw = 6.3
section(M, ay, "04", "System architecture")
cy0 = ay + 0.46
CH = 2.0
rect(s, M, cy0, aw, CH, fill="E8EBF2", radius=0.14)
ui = rect(s, M + 0.18, cy0 + 0.12, aw - 0.36, 0.4, fill=INK, radius=0.08)
shape_text(ui, [[("Expo Router screens", {"font": HEAD}), ("  ·  design system  ·  on device, no backend", {"color": SLATE300, "size": 9.5})]],
           size=11, color=SLATE100)
bx = [("Camera & gallery", "expo-image-picker", True, False),
      ("OCR", "ML Kit + parser", False, False),
      ("Bill state", "reducer + context", True, False),
      ("Engine", "pure TypeScript", True, True)]
bw = (aw - 0.36 - 3 * 0.2) / 4
by = cy0 + 0.72
cent = []
for i, (h1, h2, done, core) in enumerate(bx):
    x0 = M + 0.18 + i * (bw + 0.2)
    rect(s, x0, by, bw, 0.58, fill=INDIGO if core else CARD, line=None if core else (INK if done else INDIGO),
         lw=1.25, radius=0.08, dash=not done)
    text(s, x0 + 0.04, by + 0.07, bw - 0.08, 0.26, h1, size=10.5, font=HEAD, align="c", color=CARD if core else INK)
    text(s, x0 + 0.04, by + 0.33, bw - 0.08, 0.24, h2, size=9, align="c", color=INDIGO_TINT if core else TEXT2)
    cent.append(x0 + bw / 2)
    if i < 3:
        arrow(s, x0 + bw + 0.02, by + 0.29, x0 + bw + 0.18, by + 0.29, color=INK, width=1.25, dash=(i == 0))
arrow(s, cent[2], cy0 + 0.53, cent[2], by - 0.02, color=INK, width=1.25)
arrow(s, cent[3], by - 0.02, cent[3], cy0 + 0.53, color=INK, width=1.25)
bb = by + 0.76
for xc, h1, h2, done in [(cent[2], "Bill history", "SQLite", False), (cent[3], "Summary · Share", "share sheet", True)]:
    rect(s, xc - bw / 2 + 0.02, bb, bw - 0.04, 0.46, fill=CARD, line=INK if done else INDIGO, lw=1.25, radius=0.08, dash=not done)
    text(s, xc - bw / 2 - 0.06, bb + 0.03, bw + 0.12, 0.24, h1, size=10, font=HEAD, align="c")
    text(s, xc - bw / 2 - 0.06, bb + 0.24, bw + 0.12, 0.2, h2, size=8.5, align="c", color=TEXT2)
arrow(s, cent[2], by + 0.6, cent[2], bb - 0.02, color=INK, width=1.25, dash=True, both=True)
arrow(s, cent[3], by + 0.6, cent[3], bb - 0.02, color=INK, width=1.25)
text(s, M + 0.2, bb + 0.02, 2.4, 0.46, [[("Solid", {"font": HEAD}), ("  implemented", {})],
                                       [("Dashed", {"font": HEAD, "color": INDIGO}), ("  final release", {})]],
     size=9.5, color=TEXT2, line=1.05)

tx = M + aw + 0.3
tw2 = W - M - tx
section(tx, ay, "05", "Technology stack", w=tw2)
stack = [("React Native 0.88", True), ("Expo SDK 58", True), ("TypeScript", True), ("Expo Router", True),
         ("expo-image-picker", True), ("React 19", True), ("Jest · 274 tests", True), ("ESLint · Prettier", True),
         ("ML Kit OCR", False), ("SQLite", False)]
pwid = (tw2 - 0.14) / 2
ph = 0.33
pgap = (CH - 5 * ph) / 4
for i, (lab, done) in enumerate(stack):
    r, c = divmod(i, 2)
    x0, y0 = tx + c * (pwid + 0.14), cy0 + r * (ph + pgap)
    p = rect(s, x0, y0, pwid, ph, fill=INK if done else CARD, line=None if done else INDIGO, lw=1.25, radius=0.165, dash=not done)
    shape_text(p, lab, size=10, font=HEAD, color=SLATE100 if done else INDIGO, margin=0.03)

# ====================================================== FEATURES / USP ====
uy = cy0 + CH + 0.25
section(M, uy, "06", "Features and USP")
usps = [("receipt", "Receipt-first", "Photo starts the bill"),
        ("zap", "Less typing", "OCR pre-fills items"),
        ("eye", "Transparent", "Every share explained"),
        ("rupee", "Exact money", "Σ shares = total"),
        ("percent", "Indian bills", "GST on service charge"),
        ("lock", "Private", "On device, no account")]
tw = (CW - 5 * 0.12) / 6
th = 0.78
for i, (key, h1, h2) in enumerate(usps):
    x0, y0 = M + i * (tw + 0.12), uy + 0.44
    rect(s, x0, y0, tw, th, fill=CARD, line=LINE, radius=0.1)
    icon_tile(s, key, x0 + 0.1, y0 + 0.1, 0.32)
    text(s, x0 + 0.5, y0 + 0.1, tw - 0.55, 0.32, h1, size=11, font=HEAD, anchor="m")
    text(s, x0 + 0.1, y0 + 0.48, tw - 0.16, 0.24, h2, size=9.5, color=TEXT2, anchor="m")

# ============================================================== FOOTER ====
fy0 = uy + 0.44 + th + 0.3
rect(s, 0, fy0, W, H - fy0, fill=INK, name="Footer background")
text(s, M, fy0 + 0.2, 6.3, 0.55,
     [[("Conclusion  ", {"font": HEAD, "color": INDIGO_LT}),
       ("Divvy makes splitting a bill fast, fair and verifiable: a receipt-first workflow on a money engine that is exact by construction.", {})]],
     size=12, color=SLATE100, line=1.15)
logo(s, W - M - 4.05, fy0 + 0.3, d=0.24, on_dark=True, word=False)
text(s, W - M - 3.3, fy0 + 0.2, 3.3, 0.5, [[(STUDENT, {"font": HEAD, "color": SLATE100, "size": 12})],
                                          [(f"{PROGRAMME}  ·  {INSTITUTE}", {})]], size=10, color=SLATE300, align="r", line=1.1)

notes(s, "A3 portrait poster, 297 × 420 mm. Phones are real app screenshots except the one marked Concept design. "
         "All money figures come from the project's calculation engine.")
prs.save(OUT)
print("saved", OUT, "| footer top", round(fy0, 2), "| page height", round(H, 3), "| footer height", round(H - fy0, 2))
