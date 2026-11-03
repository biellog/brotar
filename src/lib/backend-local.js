// Backend local (modo convidado / offline). Mesma interface e mesmas regras do Supabase.
import {
  MILESTONES, MILESTONE_BONUS, DAILY_LIMIT, AD_REWARD, WELCOME_BONUS, SHOP_ITEMS,
  checkinPoints, gamePoints, soberDays, localDay,
} from './rules.js';

const KEY = 'brotar:guest:v1';

export class GameError extends Error {}

function fresh() {
  return {
    profile: { display_name: 'Jardineiro', motivation: '', sober_since: null, tz: 'America/Sao_Paulo', theme: 'dia', best_streak_days: 0 },
    ledger: [{ amount: WELCOME_BONUS, reason: 'boas_vindas', at: Date.now() }],
    items: [], milestones: [], daily: {}, relapses: [],
  };
}

/** Valida o formato do que vem do armazenamento — dados locais podem ter sido adulterados. */
function sane(d) {
  return d && typeof d === 'object' && d.profile && Array.isArray(d.ledger) && Array.isArray(d.items)
    && Array.isArray(d.milestones) && typeof d.daily === 'object';
}

export class LocalBackend {
  constructor({ storage = globalThis.localStorage, now = () => Date.now() } = {}) {
    this.storage = storage;
    this.now = now;
    this.kind = 'local';
    let d = null;
    try { d = JSON.parse(storage?.getItem(KEY) ?? 'null'); } catch { d = null; }
    this.d = sane(d) ? d : fresh();
    this.save();
  }

  save() { try { this.storage?.setItem(KEY, JSON.stringify(this.d)); } catch { /* armazenamento indisponível */ } }
  balance() { return this.d.ledger.reduce((a, l) => a + l.amount, 0); }
  today() { return localDay(this.d.profile.tz, this.now()); }
  bump(kind) {
    const k = `${this.today()}:${kind}`;
    const c = this.d.daily[k] ?? 0;
    if (c >= DAILY_LIMIT[kind]) return false;
    this.d.daily[k] = c + 1;
    return true;
  }
  add(amount, reason, ref) { this.d.ledger.push({ amount, reason, ref, at: this.now() }); }

  async getState() {
    const t = this.today();
    const today = {};
    for (const [k, v] of Object.entries(this.d.daily)) if (k.startsWith(`${t}:`)) today[k.slice(t.length + 1)] = v;
    return structuredClone({
      profile: this.d.profile, server_now: new Date(this.now()).toISOString(), balance: this.balance(),
      items: this.d.items, milestones: [...this.d.milestones].sort((a, b) => a - b), today,
    });
  }

  async startJourney(since) {
    if (this.d.profile.sober_since) throw new GameError('jornada já iniciada');
    const t = Date.parse(since);
    if (Number.isNaN(t) || t > this.now() + 300_000 || t < this.now() - 20 * 365.25 * 86_400_000) throw new GameError('data inválida');
    this.d.profile.sober_since = new Date(Math.min(t, this.now())).toISOString();
    this.save();
    return this.getState();
  }

  async updateProfile(name, motivation, tz) {
    name = String(name ?? '').trim();
    if (name.length < 1 || name.length > 40) throw new GameError('nome inválido');
    if (String(motivation ?? '').length > 280) throw new GameError('motivação muito longa');
    try { localDay(tz); } catch { throw new GameError('fuso inválido'); }
    Object.assign(this.d.profile, { display_name: name, motivation: String(motivation ?? ''), tz });
    this.save();
    return this.getState();
  }

  async checkin() {
    if (!this.d.profile.sober_since) throw new GameError('inicie a jornada primeiro');
    if (!this.bump('checkin')) throw new GameError('check-in de hoje já feito');
    const days = soberDays(this.d.profile.sober_since, this.now());
    const points = checkinPoints(days);
    this.add(points, 'checkin');
    let bonus = 0;
    for (const m of MILESTONES) {
      if (days >= m && !this.d.milestones.includes(m)) {
        this.d.milestones.push(m);
        this.add(MILESTONE_BONUS[m], 'marco', String(m));
        bonus += MILESTONE_BONUS[m];
      }
    }
    this.d.profile.best_streak_days = Math.max(this.d.profile.best_streak_days, days);
    this.save();
    return { points, bonus, state: await this.getState() };
  }

  async submitGame(score) {
    if (!Number.isInteger(score) || score < 0 || score > 100_000) throw new GameError('pontuação inválida');
    let points = gamePoints(score);
    if (points > 0 && this.bump('jogo')) this.add(points, 'jogo'); else points = 0;
    this.save();
    return { points, state: await this.getState() };
  }

  async claimAdReward() {
    if (!this.bump('anuncio')) throw new GameError('limite de recompensas por anúncio atingido hoje');
    this.add(AD_REWARD, 'anuncio');
    this.save();
    return { points: AD_REWARD, state: await this.getState() };
  }

  async buy(itemId) {
    const it = SHOP_ITEMS.find((i) => i.id === itemId);
    if (!it) throw new GameError('item inexistente');
    if (this.d.items.includes(itemId)) throw new GameError('você já tem este item');
    if (this.balance() < it.price) throw new GameError('pontos insuficientes');
    this.d.items.push(itemId);
    if (it.price > 0) this.add(-it.price, 'compra', itemId);
    this.save();
    return this.getState();
  }

  async equipTheme(id) {
    const it = SHOP_ITEMS.find((i) => i.id === id);
    if (id !== 'dia' && !(it?.category === 'tema' && this.d.items.includes(id))) throw new GameError('tema não adquirido');
    this.d.profile.theme = id;
    this.save();
    return this.getState();
  }

  async resetSobriety() {
    const days = soberDays(this.d.profile.sober_since, this.now());
    this.d.relapses.push({ streak_days: days, at: this.now() });
    this.d.profile.sober_since = new Date(this.now()).toISOString();
    this.d.profile.best_streak_days = Math.max(this.d.profile.best_streak_days, days);
    this.save();
    return this.getState();
  }

  async deleteAccount() {
    try { this.storage?.removeItem(KEY); } catch { /* ignore */ }
    this.d = fresh();
  }

  /** Exportação dos dados (direito de portabilidade). */
  async exportData() { return structuredClone(this.d); }
}
