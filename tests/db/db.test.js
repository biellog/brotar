// Testes de banco + segurança (RLS, privilégios, regras de pontos, corrida de gasto duplo).
// Requer Postgres: DATABASE_URL=postgresql://user:pass@localhost:5432/db
import { readFileSync, readdirSync } from 'node:fs';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import pg from 'pg';
import { checkinPoints, gamePoints, MILESTONE_BONUS, WELCOME_BONUS, SHOP_ITEMS } from '../../src/lib/rules.js';

const DB_URL = process.env.DATABASE_URL ?? 'postgresql://brotar_test:brotar_test@localhost:5432/brotar_test';
const root = new URL('../../', import.meta.url);

let admin;
const pool = new pg.Pool({ connectionString: DB_URL, max: 10 });

async function newUser() {
  const { rows } = await admin.query("insert into auth.users (email) values ('t@t.com') returning id");
  return rows[0].id;
}

/** Executa SQL como um usuário autenticado (ou anon se id = null), igual ao PostgREST. */
async function as(userId, sql, params = []) {
  const c = await pool.connect();
  try {
    await c.query('begin');
    await c.query(`set local role ${userId ? 'authenticated' : 'anon'}`);
    await c.query("select set_config('request.jwt.claim.sub', $1, true)", [userId ?? '']);
    const r = await c.query(sql, params);
    await c.query('commit');
    return r;
  } catch (e) {
    await c.query('rollback');
    throw e;
  } finally {
    c.release();
  }
}
const rpc = async (u, fn, ...args) => {
  const ph = args.map((_, i) => `$${i + 1}`).join(',');
  const { rows } = await as(u, `select public.${fn}(${ph}) as r`, args);
  return rows[0].r;
};
const daysAgo = (u, d) => admin.query(`update public.profiles set sober_since = now() - ($2 || ' days')::interval - interval '1 minute' where id = $1`, [u, String(d)]);

beforeAll(async () => {
  admin = await pool.connect();
  await admin.query(readFileSync(new URL('supabase-stub.sql', import.meta.url), 'utf8'));
  const dir = new URL('supabase/migrations/', root);
  for (const f of readdirSync(dir).sort()) await admin.query(readFileSync(new URL(f, dir), 'utf8'));
});
afterAll(async () => { admin?.release(); await pool.end(); });

describe('cadastro', () => {
  it('cria perfil e bônus de boas-vindas ao criar usuário', async () => {
    const u = await newUser();
    const s = await rpc(u, 'get_state');
    expect(s.balance).toBe(WELCOME_BONUS);
    expect(s.profile.display_name).toBe('Jardineiro');
    expect(s.profile.sober_since).toBeNull();
  });

  it('catálogo da loja no banco é idêntico ao do app', async () => {
    const { rows } = await as(null, 'select id, name, category, price, icon from public.shop_items order by sort');
    expect(rows).toEqual(SHOP_ITEMS);
  });
});

describe('segurança: acesso direto às tabelas', () => {
  it('anon não chama nenhuma RPC', async () => {
    await expect(rpc(null, 'get_state')).rejects.toThrow(/permission denied/);
    await expect(rpc(null, 'daily_checkin')).rejects.toThrow(/permission denied/);
  });

  it('anon não lê perfis nem extrato', async () => {
    await expect(as(null, 'select * from public.profiles')).rejects.toThrow(/permission denied/);
    await expect(as(null, 'select * from public.points_ledger')).rejects.toThrow(/permission denied/);
  });

  it('usuário não vê dados de outro usuário (RLS)', async () => {
    const a = await newUser(); const b = await newUser();
    const { rows } = await as(a, 'select id from public.profiles');
    expect(rows.map((r) => r.id)).toEqual([a]);
    const led = await as(a, 'select user_id from public.points_ledger');
    expect(led.rows.every((r) => r.user_id === a)).toBe(true);
    const other = await as(a, 'select * from public.points_ledger where user_id = $1', [b]);
    expect(other.rows).toHaveLength(0);
  });

  it('usuário não consegue inserir pontos, itens ou alterar o perfil diretamente', async () => {
    const u = await newUser();
    await expect(as(u, "insert into public.points_ledger (user_id, amount, reason) values ($1, 99999, 'jogo')", [u])).rejects.toThrow(/permission denied/);
    await expect(as(u, "insert into public.user_items (user_id, item_id) values ($1, 'ipe')", [u])).rejects.toThrow(/permission denied/);
    await expect(as(u, "update public.profiles set sober_since = now() - interval '400 days' where id = $1", [u])).rejects.toThrow(/permission denied/);
    await expect(as(u, "update public.profiles set theme = 'aurora'")).rejects.toThrow(/permission denied/);
    await expect(as(u, 'delete from public.points_ledger')).rejects.toThrow(/permission denied/);
    await expect(as(u, "insert into public.shop_items values ('x','x','planta',0,'x',0)")).rejects.toThrow(/permission denied/);
    await expect(as(u, "insert into public.daily_actions values ($1, current_date, 'jogo', -50)", [u])).rejects.toThrow(/permission denied/);
  });

  it('funções internas (_bump, _balance…) não são expostas', async () => {
    const u = await newUser();
    await expect(as(u, "select public._bump($1, current_date, 'jogo')", [u])).rejects.toThrow(/permission denied/);
    await expect(as(u, 'select public._balance($1)', [u])).rejects.toThrow(/permission denied/);
    await expect(as(u, 'select public.handle_new_user()')).rejects.toThrow(/permission denied/);
  });

  it('todas as funções SECURITY DEFINER fixam search_path', async () => {
    const { rows } = await admin.query(`
      select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.prosecdef
         and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')`);
    expect(rows).toEqual([]);
  });

  it('todas as tabelas públicas têm RLS ligado', async () => {
    const { rows } = await admin.query(`select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relkind='r' and not c.relrowsecurity`);
    expect(rows).toEqual([]);
  });
});

describe('jornada e check-in', () => {
  it('rejeita data no futuro ou absurda', async () => {
    const u = await newUser();
    await expect(rpc(u, 'start_journey', new Date(Date.now() + 86400e3).toISOString())).rejects.toThrow(/data inválida/);
    await expect(rpc(u, 'start_journey', '1900-01-01T00:00:00Z')).rejects.toThrow(/data inválida/);
  });

  it('não permite reiniciar a jornada para uma data antiga (anti-trapaça)', async () => {
    const u = await newUser();
    await rpc(u, 'start_journey', new Date().toISOString());
    await expect(rpc(u, 'start_journey', new Date(Date.now() - 400 * 86400e3).toISOString())).rejects.toThrow(/já iniciada/);
  });

  it('check-in exige jornada iniciada', async () => {
    const u = await newUser();
    await expect(rpc(u, 'daily_checkin')).rejects.toThrow(/inicie a jornada/);
  });

  it('check-in dá pontos + marcos e só uma vez por dia', async () => {
    const u = await newUser();
    await rpc(u, 'start_journey', new Date().toISOString());
    await daysAgo(u, 7);
    const r = await rpc(u, 'daily_checkin');
    expect(r.points).toBe(checkinPoints(7));
    expect(r.bonus).toBe(MILESTONE_BONUS[1] + MILESTONE_BONUS[3] + MILESTONE_BONUS[7]);
    expect(r.state.balance).toBe(WELCOME_BONUS + r.points + r.bonus);
    expect(r.state.milestones).toEqual([1, 3, 7]);
    await expect(rpc(u, 'daily_checkin')).rejects.toThrow(/já feito/);
  });

  it('marco é pago uma vez só, mesmo após recaída', async () => {
    const u = await newUser();
    await rpc(u, 'start_journey', new Date().toISOString());
    await daysAgo(u, 3);
    await rpc(u, 'daily_checkin');
    await rpc(u, 'reset_sobriety');
    await admin.query('delete from public.daily_actions where user_id = $1', [u]);
    await daysAgo(u, 3);
    const r = await rpc(u, 'daily_checkin');
    expect(r.bonus).toBe(0);
  });

  it('recaída não remove pontos nem itens e registra histórico', async () => {
    const u = await newUser();
    await rpc(u, 'start_journey', new Date().toISOString());
    await daysAgo(u, 10);
    await rpc(u, 'buy_item', 'girassol');
    const before = await rpc(u, 'get_state');
    const after = await rpc(u, 'reset_sobriety');
    expect(after.balance).toBe(before.balance);
    expect(after.items).toEqual(['girassol']);
    expect(after.profile.best_streak_days).toBe(10);
    const { rows } = await as(u, 'select streak_days from public.relapses');
    expect(rows).toEqual([{ streak_days: 10 }]);
  });
});

describe('minijogo e anúncios', () => {
  it('pontos do jogo seguem a regra e limite de 3 por dia', async () => {
    const u = await newUser();
    for (const score of [155, 9999, 400]) {
      const r = await rpc(u, 'submit_game_score', score);
      expect(r.points).toBe(gamePoints(score));
    }
    const r4 = await rpc(u, 'submit_game_score', 300);
    expect(r4.points).toBe(0);
    expect(r4.state.balance).toBe(WELCOME_BONUS + gamePoints(155) + gamePoints(9999) + gamePoints(400));
  });

  it('rejeita pontuação negativa ou absurda', async () => {
    const u = await newUser();
    await expect(rpc(u, 'submit_game_score', -5)).rejects.toThrow(/inválida/);
    await expect(rpc(u, 'submit_game_score', 10_000_000)).rejects.toThrow(/inválida/);
  });

  it('pontuação zero não consome uma partida premiada', async () => {
    const u = await newUser();
    await rpc(u, 'submit_game_score', 5);
    const s = await rpc(u, 'get_state');
    expect(s.today.jogo ?? 0).toBe(0);
  });

  it('recompensa de anúncio limitada a 3 por dia', async () => {
    const u = await newUser();
    for (let i = 0; i < 3; i++) await rpc(u, 'claim_ad_reward');
    await expect(rpc(u, 'claim_ad_reward')).rejects.toThrow(/limite/);
  });
});

describe('loja', () => {
  it('compra desconta pontos e não permite comprar duas vezes', async () => {
    const u = await newUser();
    const s = await rpc(u, 'buy_item', 'cogumelo');
    expect(s.balance).toBe(WELCOME_BONUS - 70);
    expect(s.items).toEqual(['cogumelo']);
    await expect(rpc(u, 'buy_item', 'cogumelo')).rejects.toThrow(/já tem/);
  });

  it('pontos insuficientes', async () => {
    const u = await newUser();
    await expect(rpc(u, 'buy_item', 'ipe')).rejects.toThrow(/insuficientes/);
  });

  it('item inexistente / injeção', async () => {
    const u = await newUser();
    await expect(rpc(u, 'buy_item', "girassol'; drop table public.profiles; --")).rejects.toThrow(/inexistente/);
    const { rows } = await admin.query("select to_regclass('public.profiles') as t");
    expect(rows[0].t).toBe('profiles');
  });

  it('não equipa tema que não comprou', async () => {
    const u = await newUser();
    await expect(rpc(u, 'equip_theme', 'aurora')).rejects.toThrow(/não adquirido/);
    await expect(rpc(u, 'equip_theme', 'girassol')).rejects.toThrow(/não adquirido/);
    const s = await rpc(u, 'equip_theme', 'dia');
    expect(s.profile.theme).toBe('dia');
  });

  it('corrida: 10 compras simultâneas não gastam duas vezes o mesmo saldo', async () => {
    const u = await newUser();
    await admin.query("insert into public.points_ledger (user_id, amount, reason) values ($1, 100, 'jogo')", [u]);
    // saldo 200: dá para girassol(60)+tulipa(80)=140, mas não + cacto(100)
    const items = ['girassol', 'tulipa', 'cacto', 'girassol', 'tulipa', 'cacto', 'girassol', 'tulipa', 'cacto', 'cacto'];
    await Promise.allSettled(items.map((i) => rpc(u, 'buy_item', i)));
    const s = await rpc(u, 'get_state');
    expect(s.balance).toBeGreaterThanOrEqual(0);
    const spent = s.items.reduce((acc, id) => acc + SHOP_ITEMS.find((x) => x.id === id).price, 0);
    expect(s.balance).toBe(200 - spent);
    expect(new Set(s.items).size).toBe(s.items.length);
  });

  it('corrida: check-ins simultâneos pagam só uma vez', async () => {
    const u = await newUser();
    await rpc(u, 'start_journey', new Date().toISOString());
    await Promise.allSettled(Array.from({ length: 8 }, () => rpc(u, 'daily_checkin')));
    const { rows } = await admin.query("select count(*)::int as n from public.points_ledger where user_id=$1 and reason='checkin'", [u]);
    expect(rows[0].n).toBe(1);
  });
});

describe('perfil e conta', () => {
  it('valida nome, motivação e fuso', async () => {
    const u = await newUser();
    await expect(rpc(u, 'update_profile', '', 'x', 'America/Sao_Paulo')).rejects.toThrow(/nome/);
    await expect(rpc(u, 'update_profile', 'a'.repeat(41), 'x', 'America/Sao_Paulo')).rejects.toThrow(/nome/);
    await expect(rpc(u, 'update_profile', 'Ana', 'x'.repeat(281), 'America/Sao_Paulo')).rejects.toThrow(/longa/);
    await expect(rpc(u, 'update_profile', 'Ana', '', 'Marte/Base')).rejects.toThrow(/fuso/);
    const s = await rpc(u, 'update_profile', '  <script>alert(1)</script> ', 'Pela minha filha', 'America/Manaus');
    expect(s.profile.display_name).toBe('<script>alert(1)</script>'); // guardado como texto; o app escapa ao exibir
    expect(s.profile.tz).toBe('America/Manaus');
  });

  it('apagar conta remove todos os dados (LGPD)', async () => {
    const u = await newUser();
    await rpc(u, 'buy_item', 'cogumelo');
    await rpc(u, 'delete_my_account');
    for (const t of ['profiles', 'points_ledger', 'user_items', 'daily_actions']) {
      const col = t === 'profiles' ? 'id' : 'user_id';
      const { rows } = await admin.query(`select count(*)::int n from public.${t} where ${col} = $1`, [u]);
      expect(rows[0].n, t).toBe(0);
    }
  });
});

describe('app_releases (aviso de atualização)', () => {
  it('qualquer pessoa lê; ninguém escreve pelo app', async () => {
    await admin.query("insert into public.app_releases (version_code, version_name, notes, url) values (7, 'v1.1.0', 'Novos jogos', 'https://github.com/biellog/brotar/releases/tag/v1.1.0')");
    const anon = await as(null, 'select version_code, version_name from public.app_releases');
    expect(anon.rows).toEqual([{ version_code: 7, version_name: 'v1.1.0' }]);
    const u = await newUser();
    await expect(as(u, "insert into public.app_releases (version_code, version_name, url) values (999, 'falsa', 'https://evil.example')")).rejects.toThrow(/permission denied/);
    await expect(as(null, "insert into public.app_releases (version_code, version_name, url) values (999, 'falsa', 'https://evil.example')")).rejects.toThrow(/permission denied/);
    await expect(as(u, "update public.app_releases set url = 'https://evil.example'")).rejects.toThrow(/permission denied/);
    await expect(as(u, 'delete from public.app_releases')).rejects.toThrow(/permission denied/);
  });

  it('só aceita URL https e versão única por plataforma', async () => {
    await expect(admin.query("insert into public.app_releases (version_code, version_name, url) values (8, 'x', 'javascript:alert(1)')")).rejects.toThrow(/check/);
    await expect(admin.query("insert into public.app_releases (version_code, version_name, url) values (8, 'x', 'http://inseguro.com')")).rejects.toThrow(/check/);
    await expect(admin.query("insert into public.app_releases (version_code, version_name, url) values (7, 'dup', 'https://a.com')")).rejects.toThrow(/duplicate|unique/);
  });
});
