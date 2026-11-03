import { test, expect } from '@playwright/test';

const DAY = 86_400_000;
/** Pré-carrega um estado de convidado (modo local) com N dias de sobriedade. */
async function seed(page, { days = 0, balance = 100, items = [], extra = {} } = {}) {
  await page.addInitScript(({ days, balance, items, extra, DAY }) => {
    if (sessionStorage.getItem('seeded')) return;
    sessionStorage.setItem('seeded', '1');
    localStorage.setItem('brotar:guest:v1', JSON.stringify({
      profile: { display_name: 'Ana', motivation: 'Pela minha filha', sober_since: new Date(Date.now() - days * DAY - 3600e3).toISOString(), tz: 'America/Sao_Paulo', theme: 'dia', best_streak_days: 0, ...extra },
      ledger: [{ amount: balance, reason: 'boas_vindas', at: Date.now() }], items, milestones: [], daily: {}, relapses: [],
    }));
  }, { days, balance, items, extra, DAY });
}

function collectErrors(page) {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  return errors;
}

test('onboarding: nova pessoa começa hoje', async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto('./');
  await expect(page.getByText('Bem-vindo(a) ao Brotar')).toBeVisible();
  await page.getByRole('button', { name: 'Começo hoje 🌱' }).click();
  await expect(page.getByTestId('days')).toHaveText('0');
  await expect(page.getByTestId('balance')).toContainText('100');
  expect(errors).toEqual([]);
});

test('onboarding rejeita data futura', async ({ page }) => {
  await page.goto('./');
  await page.locator('input[type=date]').fill('2099-01-01');
  await page.getByRole('button', { name: 'Confirmar' }).click();
  await expect(page.getByRole('alert')).toContainText('data inválida');
});

test('check-in com marcos e limite diário', async ({ page }) => {
  await seed(page, { days: 7 });
  await page.goto('./');
  await expect(page.getByTestId('days')).toHaveText('7');
  await page.getByTestId('checkin').click();
  await expect(page.getByRole('status')).toContainText('marco desbloqueado');
  // 100 + checkin(7)=17 + marcos 20+30+70 = 237
  await expect(page.getByTestId('balance')).toContainText('237');
  await expect(page.getByTestId('checkin')).toBeDisabled();
  await page.reload();
  await expect(page.getByTestId('checkin')).toBeDisabled();
  await page.getByRole('button', { name: /Marcos/ }).click();
  await expect(page.locator('.milestone.got')).toHaveCount(3);
});

test('loja: compra, saldo e tema', async ({ page }) => {
  await seed(page, { days: 2, balance: 400 });
  await page.goto('./');
  await page.getByRole('button', { name: /Loja/ }).click();
  await page.getByTestId('buy-girassol').click();
  await expect(page.getByTestId('balance')).toContainText('340');
  await expect(page.getByTestId('buy-ipe')).toBeDisabled();
  await page.getByRole('button', { name: 'Temas' }).click();
  await page.getByTestId('buy-noite').click();
  await page.getByRole('button', { name: 'Usar' }).last().click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'noite');
  await page.getByRole('button', { name: /Jardim/ }).click();
  await expect(page.locator('.deco')).toHaveCount(1);
});

test('minijogo termina e paga sementes', async ({ page }) => {
  await seed(page, { days: 1 });
  await page.goto('./?demo');
  await page.getByRole('button', { name: /Jogar/ }).first().click();
  await page.getByTestId('play-chuva').click();
  const canvas = page.locator('canvas.game');
  await expect(canvas).toBeVisible();
  const box = await canvas.boundingBox();
  for (let i = 0; i < 10; i++) {
    await page.mouse.move(box.x + box.width * (0.2 + 0.06 * i), box.y + box.height * 0.9);
    await page.mouse.down();
    await page.waitForTimeout(150);
  }
  await page.mouse.up();
  await expect(page.getByTestId('game-over')).toBeVisible({ timeout: 10_000 });
  const score = Number((await page.getByTestId('game-over').locator('.big-num').textContent()).replace(/\D/g, ''));
  await page.getByRole('button', { name: 'Voltar' }).click();
  await expect(page.getByTestId('game')).toHaveCount(0);
  await expect(page.getByTestId('play-chuva')).toBeVisible();
  await expect(page.getByTestId('balance')).toContainText(String(100 + Math.min(Math.floor(score / 50), 20)));
});

test('Chuva Boa: o vaso segue o mouse sem clicar e sem atraso', async ({ browser }) => {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } }); // desktop com mouse
  const page = await ctx.newPage();
  await seed(page, { days: 1 });
  await page.goto('./?demo');
  await page.getByRole('button', { name: /Jogar/ }).first().click();
  await page.getByTestId('play-chuva').click();
  const box = await page.locator('canvas.game').boundingBox();
  for (const frac of [0.25, 0.8, 0.5]) {
    await page.mouse.move(box.x + box.width * frac, box.y + box.height / 2); // só move, sem apertar
    await page.waitForTimeout(60); // ~3 quadros
    const x = await page.evaluate(() => globalThis.__brotarGame.player.x);
    expect(Math.abs(x - 360 * frac)).toBeLessThan(2);
  }
  await ctx.close();
});

test('Jardim da Memória: vira cartas e termina', async ({ page }) => {
  await seed(page, { days: 1 });
  await page.goto('./?demo');
  await page.getByRole('button', { name: /Jogar/ }).first().click();
  await page.getByTestId('play-memoria').click();
  const cards = page.locator('.mem-card');
  await expect(cards).toHaveCount(16);
  // acerta um par usando o estado do jogo
  const [a, b] = await page.evaluate(() => {
    const c = globalThis.__brotarGame.cards; const j = c.findIndex((x, k) => k > 0 && x.icon === c[0].icon); return [0, j];
  });
  await cards.nth(a).click();
  await cards.nth(b).click();
  await expect(page.locator('.mem-card.matched')).toHaveCount(2);
  await expect(page.getByTestId('game-over')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByTestId('game-over')).toContainText('Pares: 1/8');
});

test('Colheita Feliz: colher frutos dá pontos', async ({ page }) => {
  await seed(page, { days: 1 });
  await page.goto('./?demo');
  await page.getByRole('button', { name: /Jogar/ }).first().click();
  await page.getByTestId('play-colheita').click();
  await expect(page.locator('.hole')).toHaveCount(9);
  const fruit = page.locator('.hole.up').filter({ hasNotText: '🐛' }).first();
  await fruit.waitFor({ timeout: 4000 });
  await fruit.dispatchEvent('pointerdown');
  await expect.poll(() => page.evaluate(() => globalThis.__brotarGame.score)).toBeGreaterThan(0);
  await expect(page.getByTestId('game-over')).toBeVisible({ timeout: 10_000 });
});

test('botão de som liga/desliga e é lembrado', async ({ page }) => {
  await seed(page, { days: 1 });
  await page.goto('./');
  await page.getByRole('button', { name: /Jogar/ }).first().click();
  const btn = page.getByTestId('sound-toggle');
  await expect(btn).toHaveText('🔊');
  await btn.click();
  await expect(btn).toHaveText('🔇');
  await page.reload();
  await page.getByRole('button', { name: /Jogar/ }).first().click();
  await expect(page.getByTestId('sound-toggle')).toHaveText('🔇');
});

test('SOS abre respiração e contatos de ajuda', async ({ page }) => {
  await seed(page, { days: 3 });
  await page.goto('./');
  await page.getByRole('button', { name: 'Preciso de ajuda agora' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await expect(page.getByRole('link', { name: /CVV — 188/ })).toHaveAttribute('href', 'tel:188');
  await page.keyboard.press('Escape');
  await expect(page.getByRole('dialog')).toHaveCount(0);
});

test('recaída mantém sementes e itens', async ({ page }) => {
  await seed(page, { days: 10, balance: 300, items: ['cacto'] });
  await page.goto('./');
  await page.getByRole('button', { name: /Perfil/ }).click();
  await page.getByRole('button', { name: 'Tive uma recaída' }).click();
  await page.getByRole('button', { name: 'Recomeçar hoje' }).click();
  await page.getByRole('button', { name: /Jardim/ }).click();
  await expect(page.getByTestId('days')).toHaveText('0');
  await expect(page.getByTestId('balance')).toContainText('300');
  await expect(page.locator('.deco')).toHaveCount(1);
});

test('apagar dados exige confirmação', async ({ page }) => {
  await seed(page, { days: 5 });
  await page.goto('./');
  await page.getByRole('button', { name: /Perfil/ }).click();
  await page.getByRole('button', { name: 'Apagar todos os dados' }).click();
  await page.getByRole('button', { name: 'Excluir definitivamente' }).click();
  await expect(page.getByRole('dialog')).toBeVisible();
  await page.getByPlaceholder('digite APAGAR').fill('apagar');
  await page.getByRole('button', { name: 'Excluir definitivamente' }).click();
  await expect(page.getByText('Bem-vindo(a) ao Brotar')).toBeVisible();
});

// ---------------------------------------------------------------- segurança
test.describe('segurança', () => {
  test('XSS: nome e motivação maliciosos são exibidos como texto', async ({ page }) => {
    let dialog = false;
    page.on('dialog', () => { dialog = true; });
    const payload = '<img src=x onerror="window.__xss=1;alert(1)">';
    await seed(page, { days: 1, extra: { display_name: payload, motivation: '<script>window.__xss=2</script>' } });
    await page.goto('./');
    await expect(page.locator('.name')).toHaveText(payload);
    await page.getByRole('button', { name: /Perfil/ }).click();
    await page.locator('input').first().fill('"><svg onload=window.__xss=3>');
    await page.getByRole('button', { name: 'Salvar' }).click();
    await page.getByRole('button', { name: /Jardim/ }).click();
    expect(await page.evaluate(() => window.__xss)).toBeUndefined();
    expect(await page.locator('#app img[src=x], #app script, #app svg[onload]').count()).toBe(0);
    expect(dialog).toBe(false);
  });

  test('CSP estrita presente e bloqueia script inline', async ({ page }) => {
    await page.goto('./');
    const csp = await page.locator('meta[http-equiv="Content-Security-Policy"]').getAttribute('content');
    expect(csp).toContain("script-src 'self'");
    expect(csp).toContain("object-src 'none'");
    expect(csp).not.toContain('unsafe-inline');
    expect(csp).not.toContain('unsafe-eval');
    const ran = await page.evaluate(() => new Promise((r) => {
      const s = document.createElement('script'); s.textContent = 'window.__inline = 1'; document.body.append(s);
      setTimeout(() => r(window.__inline === 1), 100);
    }));
    expect(ran).toBe(false);
  });

  test('dados locais corrompidos/adulterados não quebram o app', async ({ page }) => {
    const errors = collectErrors(page);
    await page.addInitScript(() => localStorage.setItem('brotar:guest:v1', '{"profile":null,"__proto__":{"polluted":1}}'));
    await page.goto('./');
    await expect(page.getByText('Bem-vindo(a) ao Brotar')).toBeVisible();
    expect(await page.evaluate(() => ({}).polluted)).toBeUndefined();
    expect(errors).toEqual([]);
  });

  test('links externos usam rel=noopener', async ({ page }) => {
    await seed(page, { days: 1 });
    await page.goto('./');
    await page.getByRole('button', { name: 'Preciso de ajuda agora' }).click();
    for (const a of await page.locator('a[target=_blank]').all()) {
      expect(await a.getAttribute('rel')).toContain('noopener');
    }
  });

  test('build não contém segredos', async ({ request }) => {
    const html = await (await request.get('./')).text();
    const scripts = [...html.matchAll(/src="\.\/(assets\/[^"]+\.js)"/g)].map((m) => m[1]);
    expect(scripts.length).toBeGreaterThan(0);
    for (const s of scripts) {
      const js = await (await request.get(`./${s}`)).text();
      expect(js).not.toMatch(/service_role/i);
      expect(js).not.toMatch(/sk_live_|AKIA[0-9A-Z]{16}|-----BEGIN (RSA )?PRIVATE KEY/);
    }
  });
});
