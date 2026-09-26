const { chromium } = require('playwright-core');
(async () => {
  const [out, query, w, h] = process.argv.slice(2);
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
  page.on('console', (m) => { const t = m.text(); if (!t.includes('404')) console.log('console:', t.slice(0, 300)); });
  page.on('pageerror', (e) => console.log('pageerror:', e.message));
  await page.goto('http://localhost:8765/tools/preview/thumb.html?' + query + `&w=${w}&h=${h}`);
  await page.waitForFunction(() => document.title === 'done', null, { timeout: 600000 });
  await page.locator('canvas').screenshot({ path: out });
  await browser.close();
})();
