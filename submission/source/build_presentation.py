"""Builds submission/Divvy_Project_Presentation.pptx (15 slides, 16:9).

Run:  python build_presentation.py
Every diagram is drawn from native, editable PowerPoint shapes.
"""
import os
from pptx import Presentation
from pptx.util import Inches
from divvy_brand import *  # noqa: F401,F403

OUT = os.path.join(os.path.dirname(HERE), "Divvy_Project_Presentation.pptx")
W, H = 13.333, 7.5
M = 0.6  # side margin
TOTAL = 15

STUDENT = "Krish Dwivedi"
PROGRAMME = "BSc Computer Science"
INSTITUTE = "UIT, Karnavati University"
COURSE = "Mobile Application Development"

prs = Presentation()
prs.slide_width = Inches(W)
prs.slide_height = Inches(H)
BLANK = prs.slide_layouts[6]
prs.core_properties.title = "Divvy — Intelligent receipt-based bill splitting"
prs.core_properties.author = STUDENT
prs.core_properties.subject = f"{COURSE} project presentation"

MOCK = lambda n: asset("mockups", f"phone_{n}.png")  # noqa: E731


def new_slide(dark=False):
    s = prs.slides.add_slide(BLANK)
    s.background.fill.solid()
    s.background.fill.fore_color.rgb = rgb(INK if dark else BG)
    return s


def chrome(s, n, section, title, dark=False, lede=None):
    """Eyebrow, title, optional lede and footer — identical on every content slide."""
    eyebrow(s, M, 0.48, f"{n:02d}  ·  {section}", color=INDIGO_LT if dark else INDIGO)
    text(s, M, 0.78, W - 2 * M, 0.7, title, size=32, color=SLATE100 if dark else INK, font=HEAD, name="Title")
    if lede:
        text(s, M, 1.48, 9.6, 0.5, lede, size=15, color=SLATE300 if dark else TEXT2, line=1.1)
    fc = SLATE500 if dark else MUTED
    logo(s, M, 7.02, d=0.17, on_dark=dark, word=False, ring=INK if dark else BG)
    text(s, M + 0.42, 6.98, 6, 0.25, [[("Divvy", {"font": HEAD, "color": SLATE100 if dark else INK}),
                                      (f"   {COURSE}  ·  {INSTITUTE}", {})]], size=10, color=fc, anchor="m")
    text(s, W - M - 1.0, 6.98, 1.0, 0.25, f"{n:02d} / {TOTAL}", size=10, color=fc, align="r", anchor="m")


def legend(s, x, y, dark=False):
    c = SLATE300 if dark else TEXT2
    status_dot(s, x, y + 0.06, True, on_dark=dark)
    text(s, x + 0.2, y, 1.3, 0.25, "Implemented", size=11, color=c, anchor="m")
    status_dot(s, x + 1.45, y + 0.06, False, on_dark=dark)
    text(s, x + 1.65, y, 1.6, 0.25, "Final release", size=11, color=c, anchor="m")


def caption_tag(s, x, y, w, label, concept=False, dark=False, align="c"):
    col = (INDIGO_LT if dark else INDIGO) if concept else (SLATE500 if dark else MUTED)
    text(s, x, y, w, 0.22, label.upper(), size=9.5, color=col, font=HEAD, spacing=1.0, align=align)


# =========================================================== 1 · Cover ====
s = new_slide(dark=True)
logo(s, M, 0.62, d=0.38, on_dark=True, word_size=22)
text(s, M, 1.95, 6.3, 0.3, f"{COURSE.upper()}  ·  PROJECT", size=12, color=INDIGO_LT, font=HEAD, spacing=1.8)
text(s, M, 2.35, 6.4, 1.9, [[("Split the bill.", {})], [("Fairly.", {"color": INDIGO_LT})]],
     size=60, color=SLATE100, font=HEAD, line=0.95)
text(s, M, 4.45, 5.9, 0.4, "Divvy — intelligent, receipt-based bill splitting", size=19, color=SLATE100, font=HEAD)
text(s, M, 4.92, 5.6, 0.7, "Photograph a receipt, add the people, and see exactly what everyone owes — to the paisa.",
     size=15, color=SLATE300, line=1.15)
text(s, M, 5.82, 5.5, 0.95, [[(STUDENT, {"font": HEAD, "color": SLATE100, "size": 15})],
                                   [(f"{PROGRAMME}  ·  {INSTITUTE}", {})],
                                   [(f"{COURSE}  ·  2026", {})]], size=12, color=SLATE300, line=1.2)
picture(s, asset("brand", "sample_receipt_paper.png"), 6.85, 1.05, h=4.9, name="Sample receipt")
picture(s, MOCK("12_home_after"), 8.35, 1.55, h=5.35, name="Home screen")
picture(s, MOCK("09_summary_top"), 10.45, 0.85, h=5.85, name="Summary screen")
notes(s, "Divvy is a mobile app that splits a restaurant bill fairly and exactly. "
         "The phones show real screenshots of the running app; the receipt is a sample bill used throughout this presentation.")

# ===================================================== 2 · Introduction ====
s = new_slide()
chrome(s, 2, "Introduction", "Meet Divvy")
text(s, M, 1.62, 7.4, 1.2, "Divvy turns a photographed restaurant bill into a fair, exact split for everyone at the table.",
     size=23, color=INK, font=HEAD, line=1.08)
rows = [
    ("phone", "What it is", "A receipt-first mobile app for iPhone and Android, built with React Native and Expo."),
    ("alert", "The problem it solves", "Shared bills are split by hand: slow, error-prone and hard to verify."),
    ("users", "Who it is for", "Friends, flatmates, students and colleagues who eat out and share costs."),
    ("check", "Why it is useful", "Every share is exact, explained line by line, and computed on the device."),
]
y = 3.05
for key, head, body in rows:
    icon_tile(s, key, M, y, 0.56)
    text(s, M + 0.8, y - 0.02, 6.5, 0.3, head, size=15, font=HEAD, color=INK)
    text(s, M + 0.8, y + 0.29, 6.6, 0.5, body, size=13.5, color=TEXT2)
    y += 0.9
picture(s, MOCK("02_capture"), 9.0, 1.4, h=5.1, name="Capture screen")
caption_tag(s, 8.4, 6.55, 3.5, "App screenshot · Add your bill")
notes(s, "What Divvy is, the problem, the audience and why it is useful. The screen on the right is the real capture screen.")

# ========================================================== 3 · Problem ====
s = new_slide()
chrome(s, 3, "Problem statement", "Splitting a bill by hand is slow, unclear and often wrong")
probs = [
    ("calc", "Manual calculations", "Totals worked out on a calculator, at the table."),
    ("allocate", "Allocating items", "Equal splits ignore who actually ordered what."),
    ("percent", "Taxes and charges", "Is GST charged on the service charge? Usually guessed."),
    ("scale", "Inaccurate shares", "Rounding each share separately creates or loses paise."),
    ("history", "No record", "Once the chat moves on, nobody remembers who paid what."),
]
y = 1.75
for key, head, body in probs:
    icon_tile(s, key, M, y, 0.5, fill="E6E9F0", color="ink", circle=True)
    text(s, M + 0.72, y - 0.03, 4.9, 0.28, head, size=14.5, font=HEAD)
    text(s, M + 0.72, y + 0.25, 4.9, 0.3, body, size=12.5, color=TEXT2)
    y += 0.93
# comparison
cx, cw = 6.35, 3.05
rect(s, cx, 1.75, cw, 4.55, fill=CARD, line=LINE, radius=0.14)
text(s, cx + 0.3, 1.97, 2.5, 0.25, "BY HAND", size=10.5, font=HEAD, color=MUTED, spacing=1.4)
text(s, cx + 0.3, 2.3, 2.6, 0.4, "₹1,025.33 ÷ 3", size=22, font=HEAD)
text(s, cx + 0.3, 2.78, 2.6, 0.3, "= 341.7766…  → ₹341.78 each", size=12.5, color=TEXT2)
for i, nm in enumerate(["Aarav", "Priya", "Zoya"]):
    yy = 3.3 + i * 0.47
    avatar(s, nm, cx + 0.3, yy, 0.34)
    text(s, cx + 0.78, yy, 1.2, 0.34, nm, size=13, anchor="m")
    text(s, cx + 1.75, yy, 1.0, 0.34, "₹341.78", size=13, font=HEAD, anchor="m", align="r")
rect(s, cx + 0.3, 4.83, cw - 0.6, 0.01, fill=LINE)
text(s, cx + 0.3, 4.95, 2.6, 0.3, [[("Collected  ", {"color": TEXT2}), ("₹1,025.34", {"font": HEAD, "color": RED})]], size=13)
text(s, cx + 0.3, 5.3, 2.6, 0.75, "₹0.01 over the bill, and Zoya pays ₹14.71 for paneer she never ate.",
     size=11.5, color=RED, line=1.1)
dx = cx + cw + 0.25
rect(s, dx, 1.75, cw, 4.55, fill=INK, radius=0.14)
text(s, dx + 0.3, 1.97, 2.5, 0.25, "WITH DIVVY", size=10.5, font=HEAD, color=INDIGO_LT, spacing=1.4)
text(s, dx + 0.3, 2.3, 2.6, 0.4, "Item by item", size=22, font=HEAD, color=SLATE100)
text(s, dx + 0.3, 2.78, 2.6, 0.3, "Plus fair service charge and GST", size=12.5, color=SLATE300)
for i, (nm, amt) in enumerate([("Aarav", "₹349.15"), ("Priya", "₹349.12"), ("Zoya", "₹327.06")]):
    yy = 3.3 + i * 0.47
    avatar(s, nm, dx + 0.3, yy, 0.34)
    text(s, dx + 0.78, yy, 1.2, 0.34, nm, size=13, anchor="m", color=SLATE100)
    text(s, dx + 1.75, yy, 1.0, 0.34, amt, size=13, font=HEAD, anchor="m", align="r", color=SLATE100)
rect(s, dx + 0.3, 4.83, cw - 0.6, 0.01, fill=NAVY600)
text(s, dx + 0.3, 4.95, 2.6, 0.3, [[("Collected  ", {"color": SLATE300}), ("₹1,025.33", {"font": HEAD, "color": MINT})]], size=13)
text(s, dx + 0.3, 5.3, 2.6, 0.75, "Exactly the bill. Each person pays for what they ordered.",
     size=11.5, color=MINT, line=1.1)
text(s, cx, 6.42, 6.4, 0.3, "Same sample bill: 4 items, service charge 5%, GST 5% — 3 people.", size=10.5, color=MUTED)
notes(s, "Left: the five recurring problems. Right: the same sample bill split by hand and by Divvy. "
         "Rounding 341.7766 up for everyone collects one paisa too many; an equal split also charges Zoya for food she did not order. "
         "Divvy's figures are produced by the project's calculation engine.")

# ========================================================= 4 · Solution ====
s = new_slide()
chrome(s, 4, "Proposed solution", "A receipt-first workflow, from photo to fair share",
       lede="Divvy starts from the receipt itself. Each step hands clean, structured data to the next — and every value stays editable.")
legend(s, W - M - 3.05, 0.52)
steps = [
    ("camera", "Capture", "Photograph the bill or pick it from the gallery", True),
    ("scan", "Scan", "On-device OCR reads items, prices and charges", False),
    ("review", "Review", "Check and correct every extracted value", False),
    ("users", "People", "Add everyone sharing the bill", True),
    ("allocate", "Allocate", "Assign each item to whoever ordered it", False),
    ("calc", "Calculate", "Exact shares, including tax, tip and charges", True),
    ("history", "History", "Save, revisit and share past bills", True),
]
colw = (W - 2 * M) / 7
d = 0.92
cy = 2.55
for i, (key, head, body, done) in enumerate(steps):
    x0 = M + i * colw
    cxx = x0 + colw / 2
    if i < 6:
        arrow(s, cxx + d / 2 + 0.08, cy + d / 2, cxx + colw - d / 2 - 0.08, cy + d / 2, color=NAVY500, width=1.5)
    oval(s, cxx - d / 2, cy, d, d, fill=INDIGO if done else CARD, line=None if done else INDIGO, lw=1.75)
    icon(s, key, cxx - 0.22, cy + d / 2 - 0.22, 0.44, "white" if done else "indigo")
    text(s, x0, cy + d + 0.2, colw, 0.25, f"{i + 1:02d}", size=11, color=INDIGO, font=HEAD, align="c", spacing=1)
    text(s, x0, cy + d + 0.45, colw, 0.3, head, size=15.5, font=HEAD, align="c")
    text(s, x0 + 0.1, cy + d + 0.8, colw - 0.2, 0.7, body, size=11.5, color=TEXT2, align="c", line=1.05)
principles = [
    ("receipt", "Receipt-first", "The photo is the starting point of the bill, not an attachment."),
    ("rupee", "Exact to the paisa", "Shares always add up to the bill total — by construction."),
    ("lock", "Private by design", "Runs on the device. No account, nothing uploaded."),
]
pw = (W - 2 * M - 2 * 0.3) / 3
for i, (key, head, body) in enumerate(principles):
    x0 = M + i * (pw + 0.3)
    rect(s, x0, 5.2, pw, 1.3, fill=CARD, line=LINE, radius=0.12)
    icon_tile(s, key, x0 + 0.28, 5.45, 0.5)
    text(s, x0 + 0.98, 5.42, pw - 1.2, 0.3, head, size=14.5, font=HEAD)
    text(s, x0 + 0.98, 5.73, pw - 1.2, 0.6, body, size=12, color=TEXT2, line=1.05)
notes(s, "The seven-step workflow. Filled circles are implemented in the app today; outlined circles (scanning, reviewing extracted values "
         "and item-by-item allocation) complete the final release. The calculation engine already supports item allocation.")

# ======================================================= 5 · Overview ====
s = new_slide()
chrome(s, 5, "Application overview", "The Divvy app")
legend_y = 0.52
phones = [  # (mock, label, tag, concept, height)
    ("12_home_after", "Home dashboard", "App screenshot", False, 3.75),
    ("concept_scan_review", "Receipt scanning", "Concept design", True, 4.2),
    ("09_summary_top", "Bill summary", "App screenshot", False, 4.65),
    ("08_people", "Participants", "App screenshot", False, 4.2),
    ("14_home_history", "Bill history", "App screenshot", False, 3.75),
]
ratio = 836 / 1844
widths = [h * ratio for *_, h in phones]
gap = (W - 2 * M - sum(widths)) / 4
x = M
base = 6.2
for (mk, label, tag, concept, h), w in zip(phones, widths):
    picture(s, MOCK(mk), x, base - h, h=h, name=label)
    text(s, x - 0.2, base + 0.1, w + 0.4, 0.28, label, size=13.5, font=HEAD, align="c")
    caption_tag(s, x - 0.2, base + 0.4, w + 0.4, tag, concept=concept)
    x += w + gap
notes(s, "Four of these five screens are real screenshots of the running app (web build at iPhone size). "
         "Receipt scanning is a concept design for the final release, built from the app's own design tokens.")

# ======================================================= 6 · Features ====
s = new_slide()
chrome(s, 6, "Core features", "Everything needed to split a bill properly")
legend(s, W - M - 3.05, 0.52)
feats = [
    ("camera", "Camera capture", "Photograph a bill with the system camera", True),
    ("gallery", "Gallery upload", "Use a receipt photo you already have", True),
    ("scan", "Automatic extraction", "On-device OCR reads items, prices and totals", False),
    ("edit", "Editable bill details", "Amount, tax, tip and extra charges", True),
    ("userplus", "Participants", "Up to 8 people, each with a colour avatar", True),
    ("allocate", "Item-wise allocation", "Assign every item to whoever ordered it", False),
    ("calc", "Automatic splitting", "Exact shares, recalculated instantly", True),
    ("percent", "Tax, tip and charges", "Percent or fixed amount, applied in order", True),
    ("eye", "Individual breakdowns", "See exactly how each share is made up", True),
    ("history", "Bill history", "Recent bills on the home screen", True),
    ("share", "Share summary", "Send the split to the group as text", True),
    ("lock", "Private by design", "On device, no sign-up, nothing uploaded", True),
]
cols, gx, gy = 4, 0.25, 0.22
tw = (W - 2 * M - (cols - 1) * gx)
tw /= cols
th = 1.52
for i, (key, head, body, done) in enumerate(feats):
    r, c = divmod(i, cols)
    x0, y0 = M + c * (tw + gx), 1.68 + r * (th + gy)
    rect(s, x0, y0, tw, th, fill=CARD, line=LINE, radius=0.12, dash=False)
    icon_tile(s, key, x0 + 0.24, y0 + 0.24, 0.46)
    status_dot(s, x0 + tw - 0.36, y0 + 0.28, done)
    text(s, x0 + 0.24, y0 + 0.8, tw - 0.4, 0.28, head, size=14, font=HEAD)
    text(s, x0 + 0.24, y0 + 1.07, tw - 0.4, 0.42, body, size=11.5, color=TEXT2, line=1.0)
notes(s, "Twelve capabilities. Ten are implemented today; automatic extraction (OCR) and the item-allocation interface complete the final release. "
         "Bill history currently lists recent bills on the home screen; saving them permanently on the device is part of the final release.")

# =================================================== 7 · Architecture ====
s = new_slide()
chrome(s, 7, "System architecture", "How the system fits together",
       lede="A layered, fully on-device design. The calculation core is pure TypeScript with no framework imports.")
rect(s, W - M - 3.3, 0.55, 0.42, 0.22, fill=CARD, line=INK, lw=1.25, radius=0.05)
text(s, W - M - 2.8, 0.52, 1.1, 0.28, "Implemented", size=11, color=TEXT2, anchor="m")
rect(s, W - M - 1.6, 0.55, 0.42, 0.22, fill=CARD, line=INDIGO, lw=1.25, radius=0.05, dash=True)
text(s, W - M - 1.1, 0.52, 1.1, 0.28, "Final release", size=11, color=TEXT2, anchor="m")
# device frame
rect(s, M, 2.12, W - 2 * M, 4.62, fill="EEF1F6", line=None, radius=0.16)
text(s, M + 0.25, 2.24, 6, 0.25, "ON THE DEVICE  ·  iOS AND ANDROID  ·  NO BACKEND", size=10, font=HEAD, color=MUTED, spacing=1.4)
# UI layer
ux, uw = M + 0.25, W - 2 * M - 0.5
rect(s, ux, 2.58, uw, 0.86, fill=INK, radius=0.1)
text(s, ux + 0.25, 2.66, 3, 0.3, "Presentation layer", size=13, font=HEAD, color=SLATE100)
text(s, ux + 0.25, 2.96, 3.2, 0.3, "Expo Router screens · design system", size=11, color=SLATE300)
chips = ["Home", "Capture", "Preview", "Details", "People", "Summary"]
chx = ux + 3.55
for c in chips:
    cwid = 1.12
    sh = rect(s, chx, 2.8, cwid, 0.42, fill=NAVY700, radius=0.21)
    shape_text(sh, c, size=11, color=SLATE100, font=HEAD)
    chx += cwid + 0.14
# flow boxes
boxes = [
    ("Camera & gallery", "expo-image-picker", "src/platform", True),
    ("Text recognition", "Google ML Kit", "src/ocr", False),
    ("Receipt parser", "pure TypeScript", "src/ocr", False),
    ("Bill state", "reducer + context", "src/store", True),
    ("Calculation engine", "buildBill → computeSettlement", "src/core", True),
    ("Settlement", "per-person totals", "derived, never stored", True),
]
bw = 1.72
bgap = (uw - 6 * bw) / 5
by, bh = 3.98, 1.05
centers = []
for i, (head, sub, where, done) in enumerate(boxes):
    x0 = ux + i * (bw + bgap)
    core = head == "Calculation engine"
    rect(s, x0, by, bw, bh, fill=INDIGO if core else CARD, line=None if core else (INK if done else INDIGO),
         lw=1.25, radius=0.1, dash=not done)
    text(s, x0 + 0.12, by + 0.14, bw - 0.24, 0.3, head, size=12.5, font=HEAD, color=CARD if core else INK, align="c")
    text(s, x0 + 0.1, by + 0.45, bw - 0.2, 0.5, sub, size=10.5, color=INDIGO_TINT if core else TEXT2, align="c", line=1.0)
    text(s, x0, by + bh + 0.08, bw, 0.22, where, size=9.5, color=MUTED, align="c", font=HEAD)
    centers.append(x0 + bw / 2)
    if i < 5:
        arrow(s, x0 + bw + 0.04, by + bh / 2, x0 + bw + bgap - 0.04, by + bh / 2, color=INK, width=1.5, dash=(i in (0, 1)))
# camera can also attach the photo directly (implemented path) — note on the dashed OCR path
text(s, centers[1] - 0.9, by - 0.3, 3.6, 0.25, "photo → recognised lines → parsed items", size=10, color=INDIGO, align="c")
# user input from UI down to bill state, settlement back up to UI
arrow(s, centers[3], 3.44, centers[3], by - 0.02, color=INK, width=1.5)
text(s, centers[3] + 0.08, 3.5, 1.7, 0.4, "form input & edits", size=10, color=TEXT2)
arrow(s, centers[5], by - 0.02, centers[5], 3.44, color=INK, width=1.5)
text(s, centers[5] - 1.78, 3.5, 1.7, 0.4, "rendered on Summary", size=10, color=TEXT2, align="r")
# persistence + share
py = 5.62
pb = rect(s, centers[3] - bw / 2, py, bw, 0.72, fill=CARD, line=INDIGO, lw=1.25, radius=0.1, dash=True)
text(s, centers[3] - bw / 2, py + 0.08, bw, 0.3, "Bill history", size=12.5, font=HEAD, align="c")
text(s, centers[3] - bw / 2, py + 0.38, bw, 0.3, "SQLite, on device", size=10.5, color=TEXT2, align="c")
arrow(s, centers[3] - 0.15, by + bh + 0.32, centers[3] - 0.15, py - 0.02, color=INK, width=1.25, dash=True, both=True)
sb = rect(s, centers[5] - bw / 2, py, bw, 0.72, fill=CARD, line=INK, lw=1.25, radius=0.1)
text(s, centers[5] - bw / 2, py + 0.08, bw, 0.3, "Share", size=12.5, font=HEAD, align="c")
text(s, centers[5] - bw / 2, py + 0.38, bw, 0.3, "system share sheet", size=10.5, color=TEXT2, align="c")
arrow(s, centers[5], by + bh + 0.32, centers[5], py - 0.02, color=INK, width=1.25)
text(s, ux, py + 0.05, 5.6, 0.7, "Inputs are stored; money is always recomputed from them, so totals can never go stale.",
     size=11.5, color=TEXT2, line=1.1)
notes(s, "Solid boxes exist in the code today; dashed boxes (ML Kit text recognition, the receipt parser and SQLite history) complete the final release. "
         "The engine in src/core imports nothing from React, React Native or Expo — it takes a plain Bill and returns a plain Settlement.")

# =========================================================== 8 · DFD 0 ====
s = new_slide()
chrome(s, 8, "Data flow diagram", "DFD Level 0 — context diagram")
pcx, pcy, pr = 6.67, 4.25, 1.2
oval(s, pcx - pr, pcy - pr, 2 * pr, 2 * pr, fill=INDIGO)
text(s, pcx - pr, pcy - 0.62, 2 * pr, 1.3, [[("0", {"size": 13, "color": INDIGO_TINT})],
                                           [("Divvy", {"size": 20, "font": HEAD})],
                                           [("bill-splitting system", {"size": 12})]], color=CARD, align="c", line=1.05)
# User entity (left)
ux0, uy0, uw0, uh0 = M + 0.2, 3.35, 2.0, 1.8
ue = rect(s, ux0, uy0, uw0, uh0, fill=INK)
shape_text(ue, [[("User", {"size": 18, "font": HEAD})], [("person splitting the bill", {"size": 11, "color": SLATE300})]],
           color=SLATE100)
import math
flows_in = ["Receipt photo", "Bill details and corrections", "Participants and item allocations"]
flows_out = ["Extracted bill for review", "Individual shares and breakdown", "Bill history"]
allf = [(t, True) for t in flows_in] + [(t, False) for t in flows_out]
ys = [3.48 + i * 0.3 for i in range(6)]
for (label, inbound), yy in zip(allf, ys):
    xe = pcx - math.sqrt(max(pr ** 2 - (yy - pcy) ** 2, 0)) - 0.05
    if inbound:
        arrow(s, ux0 + uw0 + 0.05, yy, xe, yy, color=INK, width=1.25)
    else:
        arrow(s, xe, yy, ux0 + uw0 + 0.05, yy, color=INDIGO, width=1.25)
    text(s, ux0 + uw0 + 0.15, yy - 0.235, 2.6, 0.22, label, size=10, color=INK if inbound else INDIGO)
# camera entity (top right) and share (bottom right)
ex, ew, eh = 9.95, 2.78, 1.0
ce = rect(s, ex, 1.85, ew, eh, fill=INK)
shape_text(ce, [[("Device camera", {"size": 14, "font": HEAD})], [("and photo library", {"size": 11, "color": SLATE300})]], color=SLATE100)
me = rect(s, ex, 5.55, ew, eh, fill=INK)
shape_text(me, [[("Messaging apps", {"size": 14, "font": HEAD})], [("via the system share sheet", {"size": 11, "color": SLATE300})]], color=SLATE100)
# camera flows — two parallel flows, labels clear of the lines
arrow(s, ex - 0.03, 2.25, pcx + 0.85, pcy - 0.85, color=INK, width=1.25)
text(s, 7.25, 2.3, 1.85, 0.25, "Captured or chosen image", size=10)
arrow(s, pcx + 1.06, pcy - 0.56, ex - 0.03, 2.6, color=INDIGO, width=1.25)
text(s, 8.55, 3.4, 1.9, 0.25, "Camera / picker request", size=10, color=INDIGO)
arrow(s, pcx + 1.04, pcy + 0.6, ex - 0.03, 5.95, color=INDIGO, width=1.25)
text(s, 7.35, 5.55, 1.6, 0.25, "Split summary (text)", size=10, color=INDIGO)
# notation key
kx, ky = M + 0.2, 5.75
rect(s, kx, ky + 0.05, 0.36, 0.24, fill=INK)
text(s, kx + 0.48, ky, 1.6, 0.34, "External entity", size=10.5, color=TEXT2, anchor="m")
oval(s, kx + 1.85, ky + 0.03, 0.28, 0.28, fill=INDIGO)
text(s, kx + 2.25, ky, 1.0, 0.34, "Process", size=10.5, color=TEXT2, anchor="m")
arrow(s, kx + 3.05, ky + 0.17, kx + 3.55, ky + 0.17, color=INK)
text(s, kx + 3.65, ky, 1.0, 0.34, "Data flow", size=10.5, color=TEXT2, anchor="m")
text(s, kx, ky + 0.42, 5.2, 0.3, "Yourdon–DeMarco notation. Data stores appear at Level 1.", size=10.5, color=MUTED)
notes(s, "Context diagram: the whole system is one process. The user supplies the receipt, bill details, participants and allocations, "
         "and receives the extracted bill to review, each person's share and the bill history. The device camera and photo library supply images; "
         "the split summary leaves through the system share sheet.")

# =========================================================== 9 · DFD 1 ====
s = new_slide()
chrome(s, 9, "Data flow diagram", "DFD Level 1 — major processes")
cxs = [1.4, 4.2, 7.0, 9.8]
pw1, ph1 = 2.05, 0.95
r1, r2 = 2.38, 4.78
def proc(x, y, num, name):
    e = oval(s, x, y, pw1, ph1, fill=CARD, line=INDIGO, lw=1.75)
    shape_text(e, [[(num, {"size": 10, "color": INDIGO, "font": HEAD})], [(name, {"size": 11.5, "font": HEAD})]], line=0.95, margin=0.1)
def store(x, y, w, sid, name):
    rect(s, x, y, w, 0.01, fill=INK)
    rect(s, x, y + 0.42, w, 0.01, fill=INK)
    rect(s, x + 0.5, y, 0.01, 0.43, fill=INK)
    text(s, x + 0.08, y + 0.02, 0.4, 0.4, sid, size=11, font=HEAD, anchor="m")
    text(s, x + 0.62, y + 0.02, w - 0.7, 0.4, name, size=11.5, anchor="m")
# entity bars (duplicated external entity is marked with *)
top = rect(s, 1.4, 1.52, 10.45, 0.42, fill=INK)
shape_text(top, [[("User", {"font": HEAD, "size": 13}), ("   external entity", {"size": 10, "color": SLATE300})]], color=SLATE100)
bot = rect(s, 1.4, 6.18, 10.45, 0.42, fill=INK)
shape_text(bot, [[("User *", {"font": HEAD, "size": 13}), ("   same entity, drawn twice for clarity", {"size": 10, "color": SLATE300})]], color=SLATE100)
names1 = ["Capture or upload receipt", "Extract receipt information", "Review and correct details", "Manage participants"]
for i, n in enumerate(names1):
    proc(cxs[i], r1, f"{i + 1}.0", n)
proc(cxs[3], r2, "5.0", "Allocate expenses")
proc(cxs[2], r2, "6.0", "Calculate individual shares")
proc(cxs[1], r2, "7.0", "Save and retrieve bills")
store(2.55, 3.66, 2.6, "D1", "Receipt images")
store(7.2, 3.66, 4.4, "D2", "Bill draft (items, charges, people)")
store(1.4, 5.03, 2.05, "D3", "Bill history")
mid = lambda i: cxs[i] + pw1 / 2  # noqa: E731
def lab(x, y, t, w=1.6, c=TEXT2, al="l"):
    text(s, x, y, w, 0.22, t, size=9.5, color=c, align=al)
# user → 1, 3, 4
for i, t in [(0, "receipt photo"), (2, "corrections"), (3, "participant names")]:
    arrow(s, mid(i), 1.96, mid(i), r1 - 0.02)
    lab(mid(i) + 0.07, 2.04, t)
# 1 → D1, D1 → 2
arrow(s, mid(0) + 0.35, r1 + ph1 - 0.07, 3.3, 3.64)
lab(2.2, 3.43, "image", 0.6, al="r")
arrow(s, 4.6, 3.64, mid(1) - 0.3, r1 + ph1 - 0.06)
lab(4.98, 3.43, "image")
# 2 → 3
arrow(s, cxs[1] + pw1 + 0.02, r1 + ph1 / 2, cxs[2] - 0.02, r1 + ph1 / 2)
lab(cxs[1] + pw1 - 0.02, r1 + ph1 / 2 - 0.42, "items &\ncharges", 0.8, al="c")
# 3 → D2, 4 → D2, D2 → 5
arrow(s, mid(2), r1 + ph1 + 0.01, mid(2), 3.64)
lab(mid(2) + 0.07, 3.38, "bill details")
arrow(s, mid(3) - 0.35, r1 + ph1 + 0.01, mid(3) - 0.35, 3.64)
lab(mid(3) - 0.28, 3.38, "people")
arrow(s, mid(3) + 0.45, 4.1, mid(3) + 0.45, r2 - 0.01)
lab(mid(3) + 0.52, 4.3, "items, people")
# user* → 5
arrow(s, mid(3), 6.16, mid(3), r2 + ph1 + 0.02)
lab(mid(3) + 0.07, 5.86, "item assignments")
# 5 → 6, 6 → 7
arrow(s, cxs[3] - 0.02, r2 + ph1 / 2, cxs[2] + pw1 + 0.02, r2 + ph1 / 2)
lab(cxs[2] + pw1 - 0.05, r2 + ph1 / 2 - 0.3, "allocated bill", 0.9, al="c")
arrow(s, cxs[2] - 0.02, r2 + ph1 / 2, cxs[1] + pw1 + 0.02, r2 + ph1 / 2)
lab(cxs[1] + pw1 - 0.05, r2 + ph1 / 2 - 0.3, "settled bill", 0.9, al="c")
# 6 → user*
arrow(s, mid(2), r2 + ph1 + 0.01, mid(2), 6.16, color=INDIGO)
lab(mid(2) + 0.07, 5.86, "individual shares", c=INDIGO)
# 7 ↔ D3
arrow(s, cxs[1] - 0.01, r2 + 0.33, 3.47, 5.12)
lab(3.38, 4.75, "save", 0.7)
arrow(s, 3.47, 5.34, cxs[1] + 0.02, r2 + 0.66)
lab(3.38, 5.55, "past bills", 0.9)
# 7 → user*
arrow(s, mid(1), r2 + ph1 + 0.01, mid(1), 6.16, color=INDIGO)
lab(mid(1) + 0.07, 5.86, "bill history", c=INDIGO)
notes(s, "Level 1 expands the single process into seven. D1 holds the receipt image, D2 the bill being built (items, charges and participants), "
         "and D3 saved bills. Settlements are derived from D2 every time rather than stored, so a saved total can never disagree with its inputs.")

# ===================================================== 10 · Tech stack ====
s = new_slide()
chrome(s, 10, "Technology stack", "Built on a modern, native-first stack")
legend(s, W - M - 3.05, 0.52)
groups = [
    ("Framework", [("RN", "React Native 0.88", "Native UI for iOS and Android from one codebase", True),
                   ("EX", "Expo SDK 58", "Tooling, device APIs and Expo Go on the iPhone", True),
                   ("TS", "TypeScript", "Strict types; money is a branded Paise type", True)]),
    ("App layer", [("ER", "Expo Router", "File-based, typed navigation between screens", True),
                   ("R19", "React 19", "UI, with state in a pure reducer + Context", True),
                   ("SF", "expo-image · expo-symbols", "Fast images and native SF Symbols icons", True)]),
    ("Device & data", [("IP", "expo-image-picker", "Camera capture and gallery upload", True),
                       ("ML", "Google ML Kit", "On-device text recognition for receipts", False),
                       ("SQ", "SQLite", "On-device storage of past bills", False)]),
    ("Quality", [("JS", "Jest + ts-jest", "274 automated tests, incl. a 1,000-bill property test", True),
                 ("ES", "ESLint + Prettier", "Linting and formatting, zero warnings allowed", True),
                 ("HB", "Hermes", "JavaScript engine for the mobile bundle", True)]),
]
gw = (W - 2 * M - 3 * 0.25) / 4
for gi, (gname, items) in enumerate(groups):
    x0 = M + gi * (gw + 0.25)
    text(s, x0, 1.68, gw, 0.28, gname.upper(), size=11, font=HEAD, color=MUTED, spacing=1.4)
    for ii, (mono, name, role, done) in enumerate(items):
        y0 = 2.05 + ii * 1.5
        rect(s, x0, y0, gw, 1.34, fill=CARD, line=LINE, radius=0.12)
        t = rect(s, x0 + 0.22, y0 + 0.24, 0.62, 0.62, fill=INK if done else INDIGO_TINT, radius=0.12)
        shape_text(t, mono, size=13 if len(mono) < 3 else 11, color=SLATE100 if done else INDIGO, font=HEAD, margin=0)
        status_dot(s, x0 + gw - 0.33, y0 + 0.24, done)
        text(s, x0 + 1.0, y0 + 0.22, gw - 1.5, 0.5, name, size=13.5, font=HEAD, line=1.0)
        text(s, x0 + 0.22, y0 + 0.92, gw - 0.4, 0.4, role, size=11, color=TEXT2, line=1.0)
notes(s, "Only technologies the project actually uses are listed as implemented. Google ML Kit was selected and prototyped in a spike, "
         "but runs only in a development build, so it is part of the final release, as is SQLite history.")

# ===================================================== 11 · Core logic ====
s = new_slide()
chrome(s, 11, "Core logic", "How Divvy calculates each share")
steps = [
    ("Money is an integer", "Every amount is stored in paise: ₹123.45 is 12345. No floating point ever touches money."),
    ("Split each item", "An item is divided among the people who ordered it. Spare paise go to them in a fixed order."),
    ("Apply charges in order", "Service charge on the items, then GST on items + service, then tip. Percentages round once, half away from zero."),
    ("Largest remainder", "Each charge is shared in proportion to what each person ordered; leftover paise go to the largest remainders."),
    ("Reconcile", "Σ shares = bill total is checked on every bill and proven on 1,000 generated bills."),
]
y = 1.7
for i, (head, body) in enumerate(steps):
    n = oval(s, M, y, 0.42, 0.42, fill=INDIGO if i == 4 else INK)
    shape_text(n, str(i + 1), size=12, color=CARD, font=HEAD, margin=0)
    text(s, M + 0.6, y - 0.02, 4.4, 0.28, head, size=14, font=HEAD)
    text(s, M + 0.6, y + 0.26, 4.5, 0.6, body, size=11.5, color=TEXT2, line=1.05)
    y += 0.98
# worked example card
ex0, ey0, ew0 = 5.75, 1.62, W - M - 5.75
rect(s, ex0, ey0, ew0, 5.12, fill=CARD, line=LINE, radius=0.14)
text(s, ex0 + 0.3, ey0 + 0.2, 4.5, 0.25, "WORKED EXAMPLE  ·  THE SPICE TABLE", size=10.5, font=HEAD, color=INDIGO, spacing=1.3)
cwid = 0.9
colx = [ex0 + 0.3] + [ex0 + r - cwid for r in (3.62, 4.57, 5.52, 6.5)]
hy = ey0 + 0.5
for j, nm in enumerate(["Aarav", "Priya", "Zoya"]):
    avatar(s, nm, colx[j + 1] + cwid - 0.36 - 0.02, hy, 0.34)
text(s, colx[4], hy, cwid, 0.34, "Total", size=11.5, font=HEAD, color=MUTED, align="r", anchor="m")
rows = [
    ("Paneer Tikka", "shared by Aarav, Priya", ["170.00", "170.00", "—", "340.00"], False),
    ("Dal Makhani", "shared by all three", ["93.34", "93.33", "93.33", "280.00"], False),
    ("Cold Coffee", "Zoya", ["—", "—", "150.00", "150.00"], False),
    ("Butter Naan ×4", "shared by all three", ["53.34", "53.33", "53.33", "160.00"], False),
    ("Items subtotal", "", ["316.68", "316.66", "296.66", "930.00"], True),
    ("Service charge 5%", "of ₹930.00", ["15.84", "15.83", "14.83", "46.50"], False),
    ("GST 5%", "of ₹976.50 = 48.825 → 48.83", ["16.63", "16.63", "15.57", "48.83"], False),
]
ry = hy + 0.46
rh = 0.43
for label, sub, vals, strong in rows:
    if strong:
        rect(s, ex0 + 0.3, ry - 0.04, ew0 - 0.6, rh - 0.02, fill="F1F3F8", radius=0.06)
    text(s, colx[0] + (0.1 if strong else 0), ry, 2.7, 0.26, label, size=12, font=HEAD if strong else BODY)
    if sub:
        text(s, colx[0], ry + 0.22, 2.9, 0.2, sub, size=9.5, color=MUTED)
    for j, v in enumerate(vals):
        text(s, colx[j + 1], ry + 0.02, cwid, 0.26, v, size=12, align="r", font=HEAD if (strong or j == 3) else BODY,
             color=MUTED if v == "—" else INK)
    ry += rh
# total row
rect(s, ex0 + 0.3, ry + 0.02, ew0 - 0.6, 0.6, fill=INK, radius=0.08)
text(s, colx[0] + 0.15, ry + 0.1, 2.5, 0.44, "Each person pays", size=13, font=HEAD, color=SLATE100, anchor="m")
for j, v in enumerate(["349.15", "349.12", "327.06", "1,025.33"]):
    text(s, colx[j + 1], ry + 0.1, cwid, 0.44, v, size=13.5, font=HEAD, align="r", anchor="m",
         color=MINT if j == 3 else SLATE100)
text(s, ex0 + 0.3, ry + 0.7, ew0 - 0.6, 0.25,
     "Σ = 102,533 paise = 93,000 + 4,650 + 4,883 — exactly the bill, as computed by Divvy's engine.",
     size=10, color=TEXT2)
notes(s, "The worked example is taken from docs/money-model.md and reproduced by running the real engine (computeSettlement). "
         "Dal ₹280 ÷ 3 leaves one paisa, which goes to Aarav (first by id). Service: floors sum to 46.49, the leftover paisa goes to the largest remainder (Aarav). "
         "GST 48.825 rounds half away from zero to 48.83; floors sum to 48.81 and the two leftover paise go to Aarav and Priya. Tip is apportioned the same way.")

# ============================================================ 12 · USP ====
s = new_slide(dark=True)
chrome(s, 12, "Features and USP", "What makes Divvy different", dark=True)
# hero stat
text(s, M, 1.8, 4.6, 0.3, "THE GUARANTEE", size=11, font=HEAD, color=INDIGO_LT, spacing=1.6)
text(s, M, 2.15, 4.8, 1.1, "Σ shares = total", size=40, font=HEAD, color=SLATE100)
text(s, M, 3.05, 4.4, 0.9, "Exactly — not approximately — on every bill. No paisa is created or lost by rounding.",
     size=14, color=SLATE300, line=1.15)
stats = [("274", "automated tests"), ("1,000", "generated bills reconciled"), ("8", "people per bill")]
for i, (num, lab_) in enumerate(stats):
    y0 = 4.2 + i * 0.75
    text(s, M, y0, 1.35, 0.6, num, size=26, font=HEAD, color=INDIGO_LT, anchor="m")
    text(s, M + 1.4, y0, 3, 0.6, lab_, size=13, color=SLATE300, anchor="m")
usps = [
    ("receipt", "Receipt-first", "The bill photo is where every split begins, not an afterthought."),
    ("zap", "Less typing", "Scanning pre-fills items and charges; you confirm instead of typing."),
    ("eye", "Transparent", "Every share is broken down into items, charges and tax."),
    ("rupee", "Exact money", "Integer paise and largest-remainder rounding, end to end."),
    ("percent", "Built for Indian bills", "GST on service charge, ₹ with lakh-style grouping."),
    ("lock", "Private and offline", "Runs on the device. No account, no upload, no network."),
]
gx0 = 5.75
gw2 = (W - M - gx0 - 0.25) / 2
gh2 = 1.42
for i, (key, head, body) in enumerate(usps):
    r, c = divmod(i, 2)
    x0, y0 = gx0 + c * (gw2 + 0.25), 1.8 + r * (gh2 + 0.2)
    rect(s, x0, y0, gw2, gh2, fill=NAVY800, line=NAVY600, radius=0.12)
    icon_tile(s, key, x0 + 0.25, y0 + 0.27, 0.5, fill=NAVY700, color="white")
    text(s, x0 + 0.95, y0 + 0.25, gw2 - 1.15, 0.3, head, size=14.5, font=HEAD, color=SLATE100)
    text(s, x0 + 0.95, y0 + 0.57, gw2 - 1.15, 0.75, body, size=12, color=SLATE300, line=1.08)
notes(s, "The figures are real: 274 tests pass in the repository (10 suites), the property test generates 1,000 random bills and checks the invariant on each, "
         "and the app caps a bill at 8 participants to match its 8-colour avatar palette.")

# ===================================================== 13 · Journey ====
s = new_slide()
chrome(s, 13, "User experience", "The user journey")
journey = [
    ("12_home_after", "Start", "Begin a new bill"),
    ("02_capture", "Add the bill", "Camera or gallery"),
    ("03_preview", "Check the photo", "Retake or replace"),
    ("05_details_top", "Bill details", "Amount, tax, charges"),
    ("08_people", "Who's splitting", "Add the people"),
    ("09_summary_top", "Each person pays", "Exact shares"),
]
pw3 = 1.72
gap3 = (W - 2 * M - 6 * pw3) / 5
ph3 = pw3 / ratio
yph = 2.14
line_y = 1.78
rect(s, M + pw3 / 2, line_y, (W - 2 * M) - pw3, 0.015, fill=NAVY500)
for i, (mk, head, sub) in enumerate(journey):
    x0 = M + i * (pw3 + gap3)
    n = oval(s, x0 + pw3 / 2 - 0.19, line_y - 0.19, 0.38, 0.38, fill=INDIGO)
    shape_text(n, str(i + 1), size=11.5, color=CARD, font=HEAD, margin=0)
    picture(s, MOCK(mk), x0, yph, w=pw3, name=head)
    text(s, x0 - 0.15, yph + ph3 + 0.1, pw3 + 0.3, 0.28, head, size=13, font=HEAD, align="c")
    text(s, x0 - 0.15, yph + ph3 + 0.38, pw3 + 0.3, 0.25, sub, size=11, color=TEXT2, align="c")
text(s, M, 6.62, W - 2 * M, 0.25, [[("App screenshots of the working flow.  ", {"color": MUTED}),
                                   ("Final release adds Scan & review after step 3 and Assign items after step 5.", {"color": INDIGO})]],
     size=10.5, align="c")
notes(s, "The six screens are real screenshots, captured by driving the app with the sample receipt. In the final release, "
         "receipt scanning slots in after the photo is confirmed, and item assignment after the people are added.")

# ===================================================== 14 · Future ====
s = new_slide()
chrome(s, 14, "Future scope", "Where Divvy goes next",
       lede="Beyond the final release — directions that build on the same exact, on-device core.")
future = [
    ("wand", "Smarter OCR", "Tune the parser on a corpus of real Indian receipts; flag low-confidence lines."),
    ("allocate", "Advanced allocation", "Drag-to-assign, fractional shares (½, ⅓) and splitting by unit."),
    ("users", "Group expenses", "Saved groups of friends and flatmates for one-tap setup."),
    ("coins", "Settlement tracking", "Mark who has paid, with a UPI payment link for each person."),
    ("chart", "History and analytics", "Search, filters and monthly spending summaries."),
    ("cloud", "Optional cloud sync", "Opt-in backup across devices; on-device stays the default."),
    ("sliders", "Personalisation", "Light theme, default tax and tip, saved preferences."),
]
fw = (W - 2 * M - 3 * 0.25) / 4
fh = 2.05
for i, (key, head, body) in enumerate(future):
    r, c = divmod(i, 4)
    x0, y0 = M + c * (fw + 0.25), 2.2 + r * (fh + 0.25)
    rect(s, x0, y0, fw, fh, fill=CARD, line=NAVY500, lw=1, radius=0.12, dash=True)
    icon_tile(s, key, x0 + 0.26, y0 + 0.28, 0.5)
    text(s, x0 + 0.26, y0 + 0.95, fw - 0.5, 0.3, head, size=14.5, font=HEAD)
    text(s, x0 + 0.26, y0 + 1.27, fw - 0.5, 0.7, body, size=11.5, color=TEXT2, line=1.05)
x0, y0 = M + 3 * (fw + 0.25), 2.2 + fh + 0.25
rect(s, x0, y0, fw, fh, fill=INK, radius=0.12)
text(s, x0 + 0.28, y0 + 0.3, fw - 0.5, 1.5, [[("WHAT STAYS THE SAME", {"size": 10.5, "color": INDIGO_LT, "spc": 1.4, "font": HEAD})],
                                           [("Exact money, transparent shares, private by default.", {"size": 15, "font": HEAD, "color": SLATE100})]],
     line=1.15, para_after=6)
notes(s, "Future scope only — none of these are claimed as built. Each extends the existing engine: it already supports per-item assignment, "
         "discounts and ordered adjustments, so the work is mostly interface.")

# ===================================================== 15 · Conclusion ====
s = new_slide(dark=True)
eyebrow(s, M, 0.48, f"{15:02d}  ·  Conclusion", color=INDIGO_LT)
text(s, M, 0.78, 7, 0.7, "Conclusion", size=32, color=SLATE100, font=HEAD)
concl = [
    ("Problem", "Splitting a shared bill by hand is slow, error-prone and hard to verify."),
    ("Solution", "Divvy turns a receipt photo into an exact, item-by-item split in a few taps."),
    ("Technical contribution", "A pure-TypeScript money engine in integer paise — ordered charges, largest-remainder rounding — proven by 274 tests."),
    ("Product value", "Fair, transparent shares that everyone at the table can trust and check."),
]
y = 1.8
for i, (head, body) in enumerate(concl):
    text(s, M, y, 0.6, 0.3, f"{i + 1:02d}", size=12, font=HEAD, color=INDIGO_LT)
    text(s, M + 0.6, y - 0.02, 5.8, 0.3, head, size=15, font=HEAD, color=SLATE100)
    text(s, M + 0.6, y + 0.3, 5.9, 0.7, body, size=13, color=SLATE300, line=1.1)
    y += 1.12
rect(s, 7.55, 0.9, 0.012, 5.7, fill=NAVY600)
logo(s, 8.25, 1.95, d=0.62, on_dark=True, word_size=40)
text(s, 8.25, 3.2, 4.6, 1.0, "Thank you", size=54, font=HEAD, color=SLATE100)
text(s, 8.25, 4.25, 4.5, 0.4, "Questions are welcome.", size=17, color=INDIGO_LT)
text(s, 8.25, 5.2, 4.6, 1.0, [[(STUDENT, {"font": HEAD, "color": SLATE100, "size": 14})],
                             [(f"{PROGRAMME}  ·  {INSTITUTE}", {})],
                             [(f"{COURSE}  ·  2026", {})]], size=12, color=SLATE300, line=1.2)
notes(s, "Summary of the problem, the solution, the technical contribution and the product value. Thank the panel and invite questions.")

prs.save(OUT)
print("saved", OUT, "slides:", len(prs.slides))
