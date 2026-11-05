// Render an HTML file to PNG with headless Chrome.
// usage: node render.js in.html out.png width height [scale] [transparent]
const puppeteer = require('puppeteer-core');
const path = require('path');
(async () => {
  const [, , inp, out, w, h, scale = '3', transparent = '0'] = process.argv;
  const browser = await puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true,
    args: ['--allow-file-access-from-files'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: +w, height: +h, deviceScaleFactor: +scale });
  await page.goto('file:///' + path.resolve(inp).replace(/\\/g, '/'), { waitUntil: 'networkidle0' });
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: out, omitBackground: transparent === '1', clip: { x: 0, y: 0, width: +w, height: +h } });
  await browser.close();
  console.log('wrote', out);
})();
