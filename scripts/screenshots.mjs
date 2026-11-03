// Gera capturas de tela do app para README/Play Store. Uso: npm run build && npm run preview & node scripts/screenshots.mjs
import { chromium, devices } from '@playwright/test';

const BASE = process.env.BASE_URL ?? 'http://localhost:4173/';
const OUT = process.env.OUT ?? 'docs/screenshots';
const DAY = 86_400_000;

const browser = await chromium.launch();
const ctx = await browser.newContext({ ...devices['Pixel 7'], deviceScaleFactor: 2, locale: 'pt-BR', timezoneId: 'America/Sao_Paulo' });

async function page(state) {
  const p = await ctx.newPage();
  await p.addInitScript(({ state, DAY }) => {
    if (!state) return localStorage.clear();
    const d = state.days;
    localStorage.setItem('brotar:guest:v1', JSON.stringify({
      profile: { display_name: 'Ana', motivation: 'Pela minha saúde e pela minha filha', sober_since: new Date(Date.now() - d * DAY - 5.3 * 3600e3).toISOString(), tz: 'America/Sao_Paulo', theme: state.theme ?? 'dia', best_streak_days: d },
      ledger: [{ amount: state.balance, reason: 'boas_vindas', at: Date.now() }],
      items: state.items ?? [], milestones: [1, 3, 7, 14, 30].filter((m) => m <= d), daily: {}, relapses: [],
    }));
  }, { state, DAY });
  return p;
}

const garden = { days: 45, balance: 1240, items: ['girassol', 'borboleta', 'tulipa', 'cogumelo', 'passaro', 'lago', 'cacto'] };

let p = await page(null);
await p.goto(BASE); await p.waitForTimeout(400);
await p.screenshot({ path: `${OUT}/01-boas-vindas.png` }); await p.close();

p = await page(garden);
await p.goto(BASE); await p.waitForTimeout(600);
await p.screenshot({ path: `${OUT}/02-jardim.png` });
await p.screenshot({ path: `${OUT}/02b-jardim-completo.png`, fullPage: true });
await p.getByRole('button', { name: /Loja/ }).click(); await p.waitForTimeout(300);
await p.screenshot({ path: `${OUT}/04-loja.png` });
await p.getByRole('button', { name: /Marcos/ }).click(); await p.waitForTimeout(300);
await p.screenshot({ path: `${OUT}/05-marcos.png` });
await p.getByRole('button', { name: /Jardim/ }).click();
await p.getByRole('button', { name: 'Preciso de ajuda agora' }).click(); await p.waitForTimeout(400);
await p.screenshot({ path: `${OUT}/06-sos.png` }); await p.close();

p = await page({ ...garden, days: 400, theme: 'noite', items: [...garden.items, 'noite', 'ipe', 'abelha', 'cerejeira'] });
await p.goto(BASE); await p.waitForTimeout(600);
await p.screenshot({ path: `${OUT}/07-tema-noite.png` }); await p.close();

// jogo em andamento: um "bot" segue os itens bons
p = await page(garden);
await p.goto(BASE);
await p.getByRole('button', { name: /Jogar/ }).first().click();
await p.getByTestId('play').click();
const c = p.locator('canvas.game'); const box = await c.boundingBox();
for (let i = 0; i < 40; i++) {
  await p.mouse.move(box.x + box.width * (0.5 + 0.35 * Math.sin(i / 4)), box.y + box.height * 0.9);
  await p.mouse.down(); await p.waitForTimeout(90);
}
await p.screenshot({ path: `${OUT}/03-jogo.png` }); await p.close();

await browser.close();
console.log('ok');
