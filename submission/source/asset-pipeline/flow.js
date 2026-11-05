// Drive the real Divvy web build through its flow and capture screenshots.
const puppeteer = require('puppeteer-core');
const path = require('path');
const OUT = path.resolve(process.argv[2]);
const RECEIPT = path.resolve(process.argv[3]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const browser = await puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true,
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 3, isMobile: true, hasTouch: true });
  page.on('pageerror', (e) => console.log('PAGEERROR', e.message));
  await page.goto('http://localhost:8099/', { waitUntil: 'networkidle0', timeout: 120000 });
  await sleep(2500);
  const shot = async (name) => {
    await sleep(700);
    await page.screenshot({ path: path.join(OUT, name + '.png') });
    console.log('shot', name);
  };
  const clickText = async (text) => {
    const el = await page.waitForSelector(`::-p-text(${text})`, { timeout: 15000 });
    await el.click();
    await sleep(600);
  };
  const typeInto = async (handle, text) => {
    await handle.click({ clickCount: 3 });
    for (const ch of text) { await handle.type(ch); await sleep(45); }
    await sleep(300);
  };
  const scrollMain = async (y) => {
    await page.evaluate((y) => {
      const els = [...document.querySelectorAll('div')].filter((d) => {
        const s = getComputedStyle(d);
        return (s.overflowY === 'auto' || s.overflowY === 'scroll') && d.scrollHeight > d.clientHeight;
      });
      els.forEach((e) => (e.scrollTop = y));
      window.scrollTo(0, y);
    }, y);
    await sleep(400);
  };

  await shot('01_home_empty');

  // Upload a bill photo from the "gallery" (file chooser on web).
  await clickText('New bill');
  await shot('02_capture');
  const [chooser] = await Promise.all([page.waitForFileChooser(), clickText('Upload from gallery')]);
  await chooser.accept([RECEIPT]);
  await sleep(1500);
  await shot('03_preview');
  await clickText('Use this photo');
  await sleep(800);
  await shot('04_details_empty');

  // Fill bill details.
  let inputs = await page.$$('input');
  console.log('inputs on details:', inputs.length);
  await typeInto(inputs[0], 'Dinner at The Spice Table');
  await typeInto(inputs[1], '930');
  await typeInto(inputs[2], '5'); // tax %
  await clickText('Add a charge');
  inputs = await page.$$('input');
  console.log('inputs after charge:', inputs.length);
  await typeInto(inputs[4], 'Service charge');
  await typeInto(inputs[5], '5');
  await page.evaluate(() => document.activeElement && document.activeElement.blur());
  await scrollMain(0);
  await shot('05_details_top');
  await scrollMain(400);
  await shot('06_details_scrolled');
  await scrollMain(2000);
  await shot('06b_details_bottom');

  await clickText('Continue');
  await sleep(800);
  await shot('07_people_empty');
  for (const n of ['Aarav', 'Priya', 'Zoya']) {
    const field = await page.waitForSelector('input[placeholder="Name"]');
    await typeInto(field, n);
    await page.keyboard.press('Enter');
    await sleep(400);
  }
  const rm = await page.waitForSelector('[aria-label="Remove You"]');
  await rm.click();
  await sleep(500);
  await page.evaluate(() => document.activeElement && document.activeElement.blur());
  await shot('08_people');

  await clickText('See summary');
  await sleep(1000);
  await scrollMain(0);
  await shot('09_summary_top');
  await scrollMain(500);
  await shot('10_summary_mid');
  await scrollMain(3000);
  await shot('11_summary_bottom');

  await clickText('Save & finish');
  await sleep(1500);
  await scrollMain(0);
  await shot('12_home_after');
  await scrollMain(3000);
  await shot('13_home_recent');

  // Two more bills entered manually, so the history list shows several entries.
  const extra = [
    { name: 'Lunch at Cafe Mocha', amount: '1240', tax: '5', people: ['Aarav', 'Priya', 'Zoya', 'Kabir'] },
    { name: 'Movie night snacks', amount: '486.50', tax: '', people: ['Priya', 'Zoya'] },
  ];
  for (const b of extra) {
    await scrollMain(0);
    await clickText('New bill');
    await clickText('Enter details manually');
    await sleep(800);
    const ins = await page.$$('input');
    await typeInto(ins[0], b.name);
    await typeInto(ins[1], b.amount);
    if (b.tax) await typeInto(ins[2], b.tax);
    await page.evaluate(() => document.activeElement && document.activeElement.blur());
    await clickText('Continue');
    await sleep(800);
    for (const n of b.people) {
      const field = await page.waitForSelector('input[placeholder="Name"]');
      await typeInto(field, n);
      await page.keyboard.press('Enter');
      await sleep(400);
    }
    const you = await page.$('[aria-label="Remove You"]');
    if (you) { await you.click(); await sleep(400); }
    await clickText('See summary');
    await sleep(900);
    await clickText('Save & finish');
    await sleep(1400);
  }
  await scrollMain(3000);
  await shot('14_home_history');

  // Capture full DOM text for verification of figures.
  const text = await page.evaluate(() => document.body.innerText);
  console.log('---HOME TEXT---\n' + text);
  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
