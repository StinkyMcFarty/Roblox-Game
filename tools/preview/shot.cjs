// Screenshot the preview: serve the repo root first (python3 -m http.server 8765)
// node tools/preview/shot.cjs out.png "scenes=wolverine:Comic/Adamantium&views=25,160&w=420&h=520" 840 520
const { chromium } = require('playwright-core');
(async () => {
  const [out, query, w, h] = process.argv.slice(2);
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
  page.on('console', (m) => { if (m.type() === 'error') console.log('console:', m.text()); });
  page.on('pageerror', (e) => console.log('pageerror:', e.message));
  await page.goto('http://localhost:8765/tools/preview/render.html?' + query);
  await page.waitForFunction(() => document.title === 'done', null, { timeout: 120000 });
  await page.locator('canvas').screenshot({ path: out });
  await browser.close();
})();
