// Gera imagens de divulgação a partir das capturas reais (docs/screenshots).
import { chromium } from '@playwright/test';
import { readFileSync } from 'node:fs';

const img = (f) => `data:image/png;base64,${readFileSync(f).toString('base64')}`;
const icon = `data:image/svg+xml;base64,${readFileSync('public/icon.svg').toString('base64')}`;
const phone = (f, extra = '') => `<div class="phone" style="${extra}"><img src="${img(f)}"></div>`;
const css = `
  body{margin:0;font-family:system-ui,sans-serif}
  .bg{position:relative;overflow:hidden;background:radial-gradient(circle at 20% 20%,#66bb6a,#1b5e20 70%);color:#fff;display:flex;align-items:center}
  .phone{background:#111;border-radius:46px;padding:12px;box-shadow:0 30px 60px rgba(0,0,0,.35);}
  .phone img{display:block;border-radius:36px;width:100%}
  h1{margin:0;font-size:96px;letter-spacing:-2px} p{margin:8px 0 0;font-size:34px;opacity:.95;line-height:1.3}
  .badge{display:inline-block;margin-top:28px;background:#fff;color:#1b5e20;font-weight:800;padding:14px 26px;border-radius:999px;font-size:28px}
`;
const b = await chromium.launch();
const p = await b.newPage();

await p.setViewportSize({ width: 1920, height: 1080 });
await p.setContent(`<style>${css}</style><div class="bg" style="width:1920px;height:1080px">
  <div style="padding-left:110px;width:640px">
    <img src="${icon}" width="150" height="150">
    <h1>Brotar</h1>
    <p>Cada dia sóbrio faz seu jardim crescer.</p>
    <p style="font-size:26px;opacity:.85;margin-top:22px">✔ Check-in diário e marcos<br>✔ Sementes para comprar plantas e temas<br>✔ Minijogo para distrair a vontade<br>✔ Botão SOS com respiração guiada</p>
    <span class="badge">Android • Web</span>
  </div>
  <div style="position:relative;flex:1;height:100%">
    ${phone('docs/screenshots/04-loja.png', 'position:absolute;width:330px;left:40px;top:190px;transform:rotate(-8deg)')}
    ${phone('docs/screenshots/03-jogo.png', 'position:absolute;width:330px;right:60px;top:190px;transform:rotate(8deg)')}
    ${phone('docs/screenshots/02-jardim.png', 'position:absolute;width:370px;left:50%;margin-left:-185px;top:90px;z-index:2')}
  </div></div>`);
await p.waitForTimeout(300);
await p.screenshot({ path: 'docs/promo-brotar.png' });

await p.setViewportSize({ width: 1024, height: 500 });
await p.setContent(`<style>${css} h1{font-size:76px} p{font-size:28px}</style><div class="bg" style="width:1024px;height:500px">
  <div style="padding-left:60px;width:520px"><img src="${icon}" width="96" height="96"><h1>Brotar</h1><p>Cada dia sóbrio faz seu jardim crescer.</p></div>
  <div style="position:relative;flex:1;height:100%">
    ${phone('docs/screenshots/02-jardim.png', 'position:absolute;width:210px;left:30px;top:60px;transform:rotate(-6deg)')}
    ${phone('docs/screenshots/07-tema-noite.png', 'position:absolute;width:210px;left:220px;top:40px;transform:rotate(6deg)')}
  </div></div>`);
await p.waitForTimeout(300);
await p.screenshot({ path: 'docs/feature-graphic-1024x500.png' });
await b.close();
console.log('promo ok');
