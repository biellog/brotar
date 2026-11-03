import { describe, it, expect } from 'vitest';
import { soberDays, soberParts, nextMilestone, plantStage, checkinPoints, gamePoints, localDay, MILESTONES, DAY_MS } from '../../src/lib/rules.js';

describe('regras', () => {
  const now = Date.parse('2026-11-03T12:00:00Z');
  it('conta dias completos', () => {
    expect(soberDays(null, now)).toBe(0);
    expect(soberDays('lixo', now)).toBe(0);
    expect(soberDays(new Date(now - DAY_MS + 1000).toISOString(), now)).toBe(0);
    expect(soberDays(new Date(now - DAY_MS).toISOString(), now)).toBe(1);
    expect(soberDays(new Date(now + DAY_MS * 5).toISOString(), now)).toBe(0); // futuro não conta negativo
  });
  it('decompõe tempo', () => {
    expect(soberParts(new Date(now - (2 * DAY_MS + 3 * 3600e3 + 4 * 60e3 + 5e3)).toISOString(), now)).toEqual({ days: 2, hours: 3, minutes: 4, seconds: 5 });
  });
  it('próximo marco', () => {
    expect(nextMilestone(0)).toEqual({ next: 1, prev: 0, progress: 0 });
    expect(nextMilestone(10).next).toBe(14);
    expect(nextMilestone(10).progress).toBeCloseTo(3 / 7);
    expect(nextMilestone(400)).toEqual({ next: null, prev: 365, progress: 1 });
  });
  it('estágios da planta crescem de forma monotônica', () => {
    let last = -1;
    for (let d = 0; d <= 400; d++) { const s = plantStage(d); expect(s).toBeGreaterThanOrEqual(last); last = s; }
    expect(plantStage(0)).toBe(0); expect(plantStage(365)).toBe(6);
  });
  it('pontos', () => {
    expect(checkinPoints(0)).toBe(10); expect(checkinPoints(5)).toBe(15); expect(checkinPoints(999)).toBe(30);
    expect(gamePoints(-1)).toBe(0); expect(gamePoints(49)).toBe(0); expect(gamePoints(120)).toBe(2); expect(gamePoints(1e6)).toBe(20);
  });
  it('dia local respeita o fuso', () => {
    const t = Date.parse('2026-11-03T02:00:00Z'); // 23h do dia 2 em São Paulo
    expect(localDay('America/Sao_Paulo', t)).toBe('2026-11-02');
    expect(localDay('Europe/Lisbon', t)).toBe('2026-11-03');
    expect(() => localDay('Marte/Base', t)).toThrow();
  });
  it('marcos em ordem crescente', () => { expect([...MILESTONES].sort((a, b) => a - b)).toEqual(MILESTONES); });
});

import { normalizeSupabaseUrl } from '../../src/lib/config.js';
describe('URL do Supabase', () => {
  it('aceita a URL colada de vários jeitos', () => {
    for (const u of ['https://abc.supabase.co', 'https://abc.supabase.co/', 'https://abc.supabase.co/rest/v1/', ' https://abc.supabase.co/rest/v1 ']) {
      expect(normalizeSupabaseUrl(u)).toBe('https://abc.supabase.co');
    }
    expect(normalizeSupabaseUrl('')).toBe('');
    expect(normalizeSupabaseUrl('lixo')).toBe('');
  });
});
