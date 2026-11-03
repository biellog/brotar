// Renderiza logo, ícones e splash (PNG) a partir de public/icon.svg.
import { chromium } from '@playwright/test';
import { readFileSync } from 'node:fs';

const svg = readFileSync('public/icon.svg', 'utf8');
const fg = svg.replace(/<rect[^>]*fill="url\(#bg\)"\/>/, ''); // primeiro plano sem fundo (ícone adaptativo)
const b = await chromium.launch();
const p = await b.newPage();
async function shot(html, w, h, path, transparent = false) {
  await p.setViewportSize({ width: w, height: h });
  await p.setContent(`<html><body style="margin:0;${transparent ? 'background:transparent' : ''}">${html}</body></html>`);
  await p.screenshot({ path, omitBackground: transparent });
}
const fit = (s, size) => s.replace('<svg ', `<svg width="${size}" height="${size}" `);
await shot(fit(svg, 1024), 1024, 1024, 'assets/icon-only.png', true);
await shot(`<div style="width:1024px;height:1024px;display:grid;place-items:center">${fit(fg, 640)}</div>`, 1024, 1024, 'assets/icon-foreground.png', true);
await shot('<div style="width:1024px;height:1024px;background:linear-gradient(135deg,#43a047,#1b5e20)"></div>', 1024, 1024, 'assets/icon-background.png');
const splash = (bg, color) => `<div style="width:2732px;height:2732px;background:${bg};display:flex;flex-direction:column;align-items:center;justify-content:center;font:700 160px system-ui;color:${color}">${fit(svg, 700)}<div style="margin-top:60px">Brotar</div></div>`;
await shot(splash('#f1fbef', '#2e7d32'), 2732, 2732, 'assets/splash.png');
await shot(splash('#0f1f14', '#a5d6a7'), 2732, 2732, 'assets/splash-dark.png');
await shot(fit(svg, 512), 512, 512, 'public/icon-512.png', true);
await shot(fit(svg, 192), 192, 192, 'public/icon-192.png', true);
await b.close();
console.log('assets ok');
