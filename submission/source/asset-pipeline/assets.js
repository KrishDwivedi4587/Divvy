// Generates every raster asset used by the deck and poster:
// icons, phone mockups of real screenshots, concept screens, logo.
// usage: node assets.js <shotsDir> <outAssetsDir> <receiptPhoto>
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const [, , SHOTS, OUT, RECEIPT] = process.argv.map((p, i) => (i > 1 ? path.resolve(p) : p));
const ICONS = path.join(__dirname, 'node_modules/lucide-static/icons');
const mk = (d) => fs.mkdirSync(d, { recursive: true });
['icons', 'mockups', 'screenshots', 'brand', 'concepts'].forEach((d) => mk(path.join(OUT, d)));

const C = {
  bg: '#0B1220', raised: '#131C2E', elevated: '#1B2740', border: '#24324F', borderStrong: '#35456A',
  text: '#F5F7FA', secondary: '#A9B4C7', muted: '#7A879E', indigo: '#6B4EEA',
  mint: '#34D399', amber: '#FBBF24', orange: '#FB923C', red: '#F87171', ink: '#0B1220',
};
const fileUrl = (p) => 'file:///' + p.replace(/\\/g, '/');
const b64 = (p) => 'data:image/' + (p.endsWith('.png') ? 'png' : 'jpeg') + ';base64,' + fs.readFileSync(p).toString('base64');

const ICON_SET = {
  camera: 'camera', gallery: 'image-up', scan: 'scan-text', review: 'list-checks', users: 'users',
  allocate: 'split', calc: 'calculator', history: 'history', share: 'share-2', lock: 'lock',
  shield: 'shield-check', receipt: 'receipt', percent: 'percent', user: 'user-round', layers: 'layers',
  database: 'database', phone: 'smartphone', cpu: 'cpu', check: 'circle-check', edit: 'pencil-line',
  wallet: 'wallet', cloud: 'cloud', chart: 'chart-column', sliders: 'sliders-horizontal', target: 'target',
  zap: 'zap', scale: 'scale', eye: 'eye', coins: 'hand-coins', userplus: 'user-plus', rupee: 'indian-rupee',
  route: 'route', test: 'test-tube-diagonal', code: 'code-xml', braces: 'braces', box: 'box', blocks: 'blocks',
  nav: 'navigation', alert: 'triangle-alert', grid: 'layout-grid', sparkles: 'sparkles', folder: 'folder-clock',
  banknote: 'banknote', merge: 'git-merge', type: 'type', wand: 'wand-sparkles',
};
const ICON_COLORS = { indigo: C.indigo, white: '#FFFFFF', ink: C.ink, muted: '#7A879E', mint: '#10B981', red: '#E5484D' };

function phoneHtml(src, w = 390, h = 844) {
  const SB = 50;
  return `<!doctype html><html><head><style>
  html,body{margin:0;background:transparent}
  .ph{position:relative;width:${w + 28}px;height:${h + SB + 28}px;border-radius:64px;background:#05070C;
      box-shadow:inset 0 0 0 2px #2A3346, inset 0 0 0 5px #05070C, inset 0 0 0 6px #1A2130;}
  .sc{position:absolute;left:14px;top:14px;width:${w}px;height:${h + SB}px;border-radius:50px;overflow:hidden;background:${C.bg}}
  .sb{height:${SB}px;display:flex;align-items:center;justify-content:space-between;padding:6px 30px 0 40px;box-sizing:border-box;
      color:#F5F7FA;font:600 15px -apple-system,'Segoe UI',sans-serif}
  .sb .r{display:flex;gap:6px;align-items:center}
  .bars{display:flex;gap:2px;align-items:flex-end}.bars i{width:3px;background:#F5F7FA;border-radius:1px}
  .bat{width:22px;height:11px;border:1.5px solid #F5F7FA99;border-radius:3px;padding:1px;box-sizing:border-box}.bat i{display:block;height:100%;width:78%;background:#F5F7FA;border-radius:1px}
  .sc img{width:${w}px;height:${h}px;display:block;object-fit:cover;object-position:top}
  .island{position:absolute;left:50%;top:24px;transform:translateX(-50%);width:108px;height:31px;border-radius:20px;background:#000}
  </style></head><body><div class="ph"><div class="sc">
    <div class="sb"><span>9:41</span><span class="r"><span class="bars"><i style="height:4px"></i><i style="height:6px"></i><i style="height:8px"></i><i style="height:10px"></i></span><span class="bat"><i></i></span></span></div>
    <img src="${src}"></div><div class="island"></div></div></body></html>`;
}

const FONT = `font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;`;
const av = (t, c, s = 28) =>
  `<span style="display:inline-flex;align-items:center;justify-content:center;width:${s}px;height:${s}px;border-radius:50%;background:${c};color:${C.bg};font-weight:700;font-size:${Math.round(s * 0.39)}px">${t}</span>`;
const avOff = (t, s = 28) =>
  `<span style="display:inline-flex;align-items:center;justify-content:center;width:${s - 2}px;height:${s - 2}px;border-radius:50%;border:1px dashed ${C.borderStrong};color:${C.muted};font-weight:700;font-size:${Math.round(s * 0.39)}px">${t}</span>`;

function screenShell(title, step, body, footer) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  *{box-sizing:border-box} html,body{margin:0;width:390px;height:844px;overflow:hidden;background:${C.bg};color:${C.text};${FONT}}
  .hdr{display:flex;align-items:center;gap:12px;padding:14px 16px 10px}
  .back{width:30px;height:30px;border-radius:50%;background:${C.raised};display:flex;align-items:center;justify-content:center;color:${C.secondary};font-size:15px}
  .t{font-size:17px;font-weight:700}
  .bars{display:flex;gap:6px;padding:0 16px}.bars i{flex:1;height:3px;border-radius:2px;background:${C.border}}.bars i.on{background:${C.indigo}}
  .step{font-size:11px;color:${C.muted};padding:8px 16px 0}
  .card{background:${C.raised};border:1px solid ${C.border};border-radius:14px}
  .row{display:flex;align-items:center;gap:10px;padding:11px 14px}
  .div{height:1px;background:${C.border}}
  .muted{color:${C.muted}} .sec{color:${C.secondary}}
  .foot{position:absolute;left:0;right:0;bottom:0;padding:12px 16px 26px;background:${C.bg};border-top:1px solid ${C.border}}
  .btn{height:46px;border-radius:12px;background:${C.indigo};color:#fff;font-weight:700;font-size:14px;display:flex;align-items:center;justify-content:center}
  .num{font-variant-numeric:tabular-nums}
  </style></head><body>
  <div class="hdr"><div class="back">‹</div><div class="t">${title}</div></div>
  <div class="bars">${step.bars}</div><div class="step">${step.label}</div>
  ${body}
  <div class="foot">${footer}</div></body></html>`;
}

function conceptScan(receipt) {
  // Receipt photo with recognised line boxes, then the extracted, editable rows.
  const box = (top, h) =>
    `<div style="position:absolute;left:23%;right:21%;top:${top}%;height:${h}%;border:1.5px solid ${C.indigo};border-radius:4px;background:${C.indigo}22"></div>`;
  const item = (name, qty, amt, flag) => `
    <div class="row" style="padding:9px 14px">
      <div style="flex:1;min-width:0"><div style="font-size:14px;font-weight:700">${name}</div>
      <div style="font-size:11px" class="muted">Qty ${qty}${flag ? ` · <span style="color:${C.amber}">Check this line</span>` : ''}</div></div>
      <div class="num" style="font-size:14px;font-weight:700;padding:6px 10px;border-radius:8px;border:1px solid ${flag ? C.amber : C.border}">${amt}</div>
    </div>`;
  const body = `
  <div style="padding:10px 16px 0">
    <div class="card" style="position:relative;height:250px;overflow:hidden">
      <img src="${receipt}" style="position:absolute;left:50%;top:50%;width:330px;transform:translate(-50%,-47%)">
      ${box(45.6, 4.6)}${box(50.5, 4.6)}${box(55.4, 4.6)}${box(60.3, 4.6)}
      <div style="position:absolute;left:10px;top:10px;font-size:11px;font-weight:700;padding:4px 9px;border-radius:99px;background:${C.bg}D0;color:${C.text}">Scanned on device</div>
    </div>
  </div>
  <div style="display:flex;justify-content:space-between;align-items:baseline;padding:14px 16px 8px">
    <div style="font-size:16px;font-weight:700">4 items found</div><div style="font-size:11px" class="muted">Tap any value to edit</div></div>
  <div style="padding:0 16px"><div class="card">
    ${item('Paneer Tikka', 1, '₹340.00')}<div class="div"></div>
    ${item('Dal Makhani', 1, '₹280.00')}<div class="div"></div>
    ${item('Cold Coffee', 1, '₹150.00', true)}<div class="div"></div>
    ${item('Butter Naan', 4, '₹160.00')}
  </div></div>
  <div style="padding:10px 16px 0"><div class="card" style="padding:10px 14px;display:flex;gap:16px;font-size:12px">
    <div style="flex:1"><div class="muted">Service charge</div><div class="num" style="font-weight:700;font-size:13px">5% · ₹46.50</div></div>
    <div style="flex:1"><div class="muted">GST</div><div class="num" style="font-weight:700;font-size:13px">5% · ₹48.83</div></div>
  </div></div>`;
  const footer = `<div style="display:flex;align-items:center;gap:8px;font-size:12px;color:${C.mint};margin-bottom:10px">
      <span style="width:16px;height:16px;border-radius:50%;background:${C.mint};color:${C.bg};display:inline-flex;align-items:center;justify-content:center;font-size:11px;font-weight:700">✓</span>
      Items add up to ₹930.00, matching the bill</div>
    <div class="btn">Use these items  →</div>`;
  return screenShell('Review the bill', { bars: '<i class="on"></i><i class="on"></i><i></i><i></i><i></i>', label: 'Step 2 of 5 · Review' }, body, footer);
}

function conceptAssign() {
  const P = [['AA', C.orange], ['PR', C.amber], ['ZO', C.mint]];
  const item = (name, amt, who) => `
    <div class="row" style="padding:12px 14px">
      <div style="flex:1"><div style="font-size:14px;font-weight:700">${name}</div>
      <div class="num muted" style="font-size:12px">${amt}${who.length > 1 ? ` · split ${who.length} ways` : ''}</div></div>
      <div style="display:flex;gap:6px">${P.map(([t, c], i) => (who.includes(i) ? av(t, c, 30) : avOff(t, 30))).join('')}</div>
    </div>`;
  const body = `
  <div style="padding:12px 16px 8px;display:flex;justify-content:space-between;align-items:center">
    <div style="font-size:16px;font-weight:700">Who had what?</div>
    <div style="font-size:12px;font-weight:700;color:${C.mint};padding:4px 10px;border-radius:99px;background:${C.mint}1F">All 4 assigned</div></div>
  <div style="padding:0 16px"><div class="card">
    ${item('Paneer Tikka', '₹340.00', [0, 1])}<div class="div"></div>
    ${item('Dal Makhani', '₹280.00', [0, 1, 2])}<div class="div"></div>
    ${item('Cold Coffee', '₹150.00', [2])}<div class="div"></div>
    ${item('Butter Naan ×4', '₹160.00', [0, 1, 2])}
  </div></div>
  <div style="padding:12px 16px 0;font-size:12px" class="muted">Tap a person to add or remove them from an item. Service charge and GST are shared in proportion to what each person ordered.</div>
  <div style="padding:14px 16px 0"><div class="card" style="padding:14px;display:flex;justify-content:space-between">
    ${[['AA', C.orange, 'Aarav', '₹349.15'], ['PR', C.amber, 'Priya', '₹349.12'], ['ZO', C.mint, 'Zoya', '₹327.06']]
      .map(([t, c, n, a]) => `<div style="display:flex;flex-direction:column;align-items:center;gap:5px;width:96px">${av(t, c, 44)}<div style="font-size:12px" class="sec">${n}</div><div class="num" style="font-size:15px;font-weight:700">${a}</div></div>`)
      .join('')}
  </div></div>`;
  const footer = `<div style="display:flex;justify-content:space-between;align-items:center;gap:12px">
     <div><div style="font-size:11px" class="muted">Total</div><div class="num" style="font-size:20px;font-weight:700">₹1,025.33</div></div>
     <div class="btn" style="flex:0 0 160px">See summary  →</div></div>`;
  return screenShell('Assign items', { bars: '<i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i><i></i>', label: 'Step 4 of 5 · Assign' }, body, footer);
}

function logoHtml(onDark, withWord) {
  const a = onDark ? C.text : C.ink;
  const ring = onDark ? C.bg : '#FFFFFF';
  return `<!doctype html><html><head><style>html,body{margin:0;background:transparent}
  .w{display:flex;align-items:center;gap:26px;padding:10px;${FONT}}
  .d{position:relative;width:${200 - 76 + 100}px;height:100px}
  .d i{position:absolute;top:0;width:100px;height:100px;border-radius:50%}
  </style></head><body><div class="w"><div class="d">
   <i style="left:0;background:${a}"></i><i style="left:62px;background:${C.indigo};box-shadow:0 0 0 7px ${ring}"></i></div>
   ${withWord ? `<div style="font-size:92px;font-weight:700;letter-spacing:-2px;color:${a}">Divvy</div>` : ''}
  </div></body></html>`;
}

(async () => {
  const browser = await puppeteer.launch({ executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true, args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage();
  const render = async (html, file, w, h, scale, transparent = true, clipEl) => {
    await page.setViewport({ width: w, height: h, deviceScaleFactor: scale });
    await page.setContent(html, { waitUntil: 'load', timeout: 0 });
    await page.evaluate(() => document.fonts.ready);
    if (clipEl) {
      const el = await page.$(clipEl);
      await el.screenshot({ path: file, omitBackground: transparent });
    } else {
      await page.screenshot({ path: file, omitBackground: transparent, clip: { x: 0, y: 0, width: w, height: h } });
    }
  };

  // Icons
  for (const [key, name] of Object.entries(ICON_SET)) {
    const svg = fs.readFileSync(path.join(ICONS, name + '.svg'), 'utf8');
    for (const [cname, col] of Object.entries(ICON_COLORS)) {
      const s = svg.replace(/stroke="currentColor"/g, `stroke="${col}"`).replace(/width="24"/, 'width="128"').replace(/height="24"/, 'height="128"').replace(/stroke-width="2"/, 'stroke-width="1.75"');
      await render(`<html><body style="margin:0;background:transparent">${s}</body></html>`, path.join(OUT, 'icons', `${key}_${cname}.png`), 128, 128, 2);
    }
  }
  console.log('icons done');

  // Real screenshots → copy and frame
  const shots = fs.readdirSync(SHOTS).filter((f) => f.endsWith('.png'));
  for (const f of shots) {
    fs.copyFileSync(path.join(SHOTS, f), path.join(OUT, 'screenshots', f));
    await render(phoneHtml(b64(path.join(SHOTS, f))), path.join(OUT, 'mockups', 'phone_' + f), 418, 922, 2, true, '.ph');
  }
  console.log('phones done');

  // Concept screens (clearly named concept_*)
  const receipt = b64(RECEIPT);
  const concepts = { concept_scan_review: conceptScan(receipt), concept_assign_items: conceptAssign() };
  for (const [name, html] of Object.entries(concepts)) {
    const raw = path.join(OUT, 'concepts', name + '.png');
    await render(html, raw, 390, 844, 3, false);
    await render(phoneHtml(b64(raw)), path.join(OUT, 'mockups', 'phone_' + name + '.png'), 418, 922, 2, true, '.ph');
  }
  console.log('concepts done');

  // Logos
  await render(logoHtml(true, true), path.join(OUT, 'brand', 'divvy_logo_on_dark.png'), 700, 140, 3, true, '.w');
  await render(logoHtml(false, true), path.join(OUT, 'brand', 'divvy_logo_on_light.png'), 700, 140, 3, true, '.w');
  await render(logoHtml(true, false), path.join(OUT, 'brand', 'divvy_mark_on_dark.png'), 260, 140, 3, true, '.w');
  await render(logoHtml(false, false), path.join(OUT, 'brand', 'divvy_mark_on_light.png'), 260, 140, 3, true, '.w');
  fs.copyFileSync(RECEIPT, path.join(OUT, 'brand', 'sample_receipt_photo.jpg'));
  console.log('brand done');
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
