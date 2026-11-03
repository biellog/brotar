import { describe, it, expect, beforeEach } from 'vitest';
import { LocalBackend } from '../../src/lib/backend-local.js';
import { WELCOME_BONUS, checkinPoints, MILESTONE_BONUS, DAY_MS } from '../../src/lib/rules.js';

class Mem { constructor() { this.m = new Map(); } getItem(k) { return this.m.get(k) ?? null; } setItem(k, v) { this.m.set(k, String(v)); } removeItem(k) { this.m.delete(k); } }

let store; let clock; let be;
beforeEach(() => { store = new Mem(); clock = Date.parse('2026-11-03T15:00:00Z'); be = new LocalBackend({ storage: store, now: () => clock }); });

describe('backend local', () => {
  it('estado inicial', async () => {
    const s = await be.getState();
    expect(s.balance).toBe(WELCOME_BONUS); expect(s.profile.sober_since).toBeNull();
  });
  it('jornada só começa uma vez e rejeita futuro', async () => {
    await expect(be.startJourney(new Date(clock + DAY_MS).toISOString())).rejects.toThrow('data inválida');
    await be.startJourney(new Date(clock - 3 * DAY_MS).toISOString());
    await expect(be.startJourney(new Date(clock).toISOString())).rejects.toThrow('já iniciada');
  });
  it('check-in, marcos e virada do dia', async () => {
    await be.startJourney(new Date(clock - 3 * DAY_MS).toISOString());
    const r = await be.checkin();
    expect(r.points).toBe(checkinPoints(3)); expect(r.bonus).toBe(MILESTONE_BONUS[1] + MILESTONE_BONUS[3]);
    await expect(be.checkin()).rejects.toThrow('já feito');
    clock += DAY_MS;
    const r2 = await be.checkin();
    expect(r2.bonus).toBe(0); expect(r2.points).toBe(checkinPoints(4));
  });
  it('persiste entre instâncias', async () => {
    await be.startJourney(new Date(clock).toISOString());
    await be.buy('girassol');
    const be2 = new LocalBackend({ storage: store, now: () => clock });
    expect((await be2.getState()).items).toEqual(['girassol']);
  });
  it('loja valida saldo, duplicidade e item inexistente', async () => {
    await expect(be.buy('ipe')).rejects.toThrow('insuficientes');
    await expect(be.buy('nada')).rejects.toThrow('inexistente');
    await be.buy('girassol');
    await expect(be.buy('girassol')).rejects.toThrow('já tem');
  });
  it('jogo: limite diário e validação', async () => {
    await expect(be.submitGame(-1)).rejects.toThrow('inválida');
    await expect(be.submitGame(1.5)).rejects.toThrow('inválida');
    for (let i = 0; i < 3; i++) expect((await be.submitGame(500)).points).toBe(10);
    expect((await be.submitGame(500)).points).toBe(0);
  });
  it('tema exige compra', async () => {
    await expect(be.equipTheme('noite')).rejects.toThrow('não adquirido');
    await expect(be.equipTheme('girassol')).rejects.toThrow('não adquirido');
  });
  it('perfil valida', async () => {
    await expect(be.updateProfile(' ', '', 'America/Sao_Paulo')).rejects.toThrow('nome');
    await expect(be.updateProfile('Ana', '', 'X/Y')).rejects.toThrow('fuso');
    const s = await be.updateProfile(' Ana ', 'oi', 'America/Manaus');
    expect(s.profile.display_name).toBe('Ana');
  });
  it('JSON corrompido volta ao estado inicial', async () => {
    store.setItem('brotar:guest:v1', '{quebrado');
    const b = new LocalBackend({ storage: store, now: () => clock });
    expect((await b.getState()).balance).toBe(WELCOME_BONUS);
  });
  it('estado retornado é cópia (UI não altera o estado interno)', async () => {
    const s = await be.getState(); s.balance = 999999; s.items.push('ipe');
    expect((await be.getState()).items).toEqual([]);
  });
  it('apagar conta zera tudo', async () => {
    await be.buy('girassol'); await be.deleteAccount();
    expect((await be.getState()).items).toEqual([]);
  });
});
