// Integração real: a camada Supabase do app conversa com a migração de verdade num Postgres local.
// As rotas https://fake-proj.supabase.co/* imitam o GoTrue (auth) e o PostgREST (rpc/tabelas).
import { test, expect } from '@playwright/test';
import { readFileSync, readdirSync } from 'node:fs';
import pg from 'pg';

const DB_URL = process.env.DATABASE_URL ?? 'postgresql://brotar_test:brotar_test@localhost:5432/brotar_test';
const pool = new pg.Pool({ connectionString: DB_URL });
const users = new Map(); // email -> { id, password }
const TABLES = new Set(['profiles', 'points_ledger', 'user_items', 'milestones_claimed', 'daily_actions', 'relapses']);

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (sub) => `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub, role: 'authenticated', exp: Math.floor(Date.now() / 1000) + 3600 })}.sig`;
const subOf = (auth) => { try { return JSON.parse(Buffer.from(auth.split(' ')[1].split('.')[1], 'base64url')).sub ?? null; } catch { return null; } };
const session = (id, email) => ({
  access_token: jwt(id), token_type: 'bearer', expires_in: 3600, expires_at: Math.floor(Date.now() / 1000) + 3600, refresh_token: 'r',
  user: { id, aud: 'authenticated', role: 'authenticated', email, app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() },
});

async function asUser(sub, sql, params = []) {
  const c = await pool.connect();
  try {
    await c.query('begin');
    await c.query(`set local role ${sub ? 'authenticated' : 'anon'}`);
    await c.query("select set_config('request.jwt.claim.sub', $1, true)", [sub ?? '']);
    const r = await c.query(sql, params);
    await c.query('commit');
    return r;
  } catch (e) { await c.query('rollback'); throw e; } finally { c.release(); }
}

test.beforeAll(async () => {
  const c = await pool.connect();
  await c.query(readFileSync(new URL('../db/supabase-stub.sql', import.meta.url), 'utf8'));
  const dir = new URL('../../supabase/migrations/', import.meta.url);
  for (const f of readdirSync(dir).sort()) await c.query(readFileSync(new URL(f, dir), 'utf8'));
  c.release();
});
test.afterAll(() => pool.end());

test.beforeEach(async ({ page }) => {
  await page.route('https://fake-proj.supabase.co/**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const body = req.postData() ? JSON.parse(req.postData()) : {};
    const json = (status, data) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(data) });
    if (url.pathname === '/auth/v1/signup') {
      if (users.has(body.email)) return json(422, { code: 'user_already_exists', msg: 'User already registered' });
      const { rows } = await pool.query('insert into auth.users (email) values ($1) returning id', [body.email]);
      users.set(body.email, { id: rows[0].id, password: body.password });
      return json(200, session(rows[0].id, body.email));
    }
    if (url.pathname === '/auth/v1/token') {
      const u = users.get(body.email);
      if (!u || u.password !== body.password) return json(400, { error: 'invalid_grant', error_description: 'Invalid login credentials', code: 'invalid_credentials', msg: 'Invalid login credentials' });
      return json(200, session(u.id, body.email));
    }
    if (url.pathname === '/auth/v1/logout') return route.fulfill({ status: 204 });
    const sub = subOf(req.headers().authorization ?? '');
    if (url.pathname === '/auth/v1/user') return json(200, session(sub, '').user);
    const rpc = url.pathname.match(/^\/rest\/v1\/rpc\/([a-z_]+)$/);
    if (rpc) {
      const keys = Object.keys(body).filter((k) => /^[a-z_]+$/.test(k));
      const sql = `select public.${rpc[1]}(${keys.map((k, i) => `${k} => $${i + 1}`).join(', ')}) as r`;
      try {
        const { rows } = await asUser(sub, sql, keys.map((k) => body[k]));
        return json(200, rows[0].r);
      } catch (e) { return json(400, { message: e.message, code: e.code }); }
    }
    const t = url.pathname.match(/^\/rest\/v1\/([a-z_]+)$/);
    if (t && TABLES.has(t[1])) {
      try { return json(200, (await asUser(sub, `select * from public.${t[1]}`)).rows); } catch (e) { return json(400, { message: e.message }); }
    }
    return json(404, { message: 'not found' });
  });
});

async function signUp(page, email) {
  await page.goto('./');
  await page.getByRole('button', { name: 'Não tem conta? Criar conta' }).click();
  await page.getByPlaceholder('seu@email.com').fill(email);
  await page.getByPlaceholder('mínimo 8 caracteres').fill('senhaforte123');
  await page.getByRole('button', { name: 'Criar conta' }).click();
  await expect(page.getByText('Bem-vindo(a) ao Brotar')).toBeVisible();
  await page.getByRole('button', { name: 'Começo hoje 🌱' }).click();
  await expect(page.getByTestId('balance')).toContainText('100');
}

test('conta: cadastro, jornada, check-in e compra salvos no banco', async ({ page }) => {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await signUp(page, 'ana@exemplo.com');
  await page.getByTestId('checkin').click();
  await expect(page.getByTestId('balance')).toContainText('110');
  await page.getByRole('button', { name: /Loja/ }).click();
  await page.getByTestId('buy-girassol').click();
  await expect(page.getByTestId('balance')).toContainText('50');

  const { rows } = await pool.query("select coalesce(sum(amount),0)::int s from public.points_ledger l join auth.users u on u.id = l.user_id where u.email = 'ana@exemplo.com'");
  expect(rows[0].s).toBe(50);

  // sai e entra de novo: os dados vêm do servidor
  await page.getByRole('button', { name: /Perfil/ }).click();
  await page.getByRole('button', { name: 'Sair' }).click();
  await page.getByPlaceholder('seu@email.com').fill('ana@exemplo.com');
  await page.getByPlaceholder('mínimo 8 caracteres').fill('senhaerrada');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page.getByRole('alert')).toContainText('E-mail ou senha incorretos');
  await page.getByPlaceholder('mínimo 8 caracteres').fill('senhaforte123');
  await page.getByRole('button', { name: 'Entrar' }).click();
  await expect(page.getByTestId('balance')).toContainText('50');
  await page.getByRole('button', { name: /Loja/ }).click();
  await expect(page.getByText('No jardim ✔')).toBeVisible();
  expect(errors).toEqual([]);
});

test('conta: regra do servidor prevalece sobre um cliente adulterado', async ({ page }) => {
  await signUp(page, 'bia@exemplo.com');
  await page.getByRole('button', { name: /Loja/ }).click();
  await page.getByTestId('buy-ipe').evaluate((b) => { b.disabled = false; });
  await page.getByTestId('buy-ipe').click();
  await expect(page.getByRole('alert')).toContainText('pontos insuficientes');
  await expect(page.getByTestId('balance')).toContainText('100');
});

test('conta: excluir conta apaga os dados no servidor', async ({ page }) => {
  await signUp(page, 'caio@exemplo.com');
  await page.getByRole('button', { name: /Perfil/ }).click();
  await page.getByRole('button', { name: 'Excluir minha conta' }).click();
  await page.getByPlaceholder('digite APAGAR').fill('APAGAR');
  await page.getByRole('button', { name: 'Excluir definitivamente' }).click();
  await expect(page.getByPlaceholder('seu@email.com')).toBeVisible();
  const { rows } = await pool.query("select count(*)::int n from auth.users where email = 'caio@exemplo.com'");
  expect(rows[0].n).toBe(0);
});
