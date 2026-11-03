import { describe, it, expect } from 'vitest';
import { createGame, step, multiplier, mulberry32 } from '../../src/game/chuva-engine.js';

const run = (g, secs, input = {}) => { for (let i = 0; i < secs * 60; i++) step(g, 1 / 60, input); return g; };

describe('motor do minijogo', () => {
  it('é determinístico com a mesma semente', () => {
    const a = run(createGame({ seed: 42 }), 20, { dir: 1 });
    const b = run(createGame({ seed: 42 }), 20, { dir: 1 });
    expect(a.score).toBe(b.score); expect(a.lives).toBe(b.lives);
  });
  it('termina por tempo', () => {
    const g = run(createGame({ seed: 1, duration: 5, lives: 99 }), 6);
    expect(g.over).toBe(true); expect(g.t).toBeGreaterThanOrEqual(5);
  });
  it('não passa do tempo nem aceita dt gigante (anti speed-hack)', () => {
    const g = createGame({ seed: 1 });
    step(g, 1000);
    expect(g.t).toBeLessThanOrEqual(0.05);
    step(g, -5);
    expect(g.t).toBeLessThanOrEqual(0.05);
  });
  it('jogador fica dentro da tela', () => {
    const g = run(createGame({ seed: 3, lives: 99 }), 3, { dir: -1 });
    expect(g.player.x).toBe(g.player.w / 2);
    run(g, 5, { targetX: 99999 });
    expect(g.player.x).toBe(g.width - g.player.w / 2);
  });
  it('pegar item soma pontos; nuvem tira vida e zera combo', () => {
    const g = createGame({ seed: 5 });
    g.spawnIn = 999;
    g.objs.push({ id: 1, kind: 'gota', r: 14, x: g.player.x, y: g.player.y - 30, vy: 100, vx: 0 });
    run(g, 0.5);
    expect(g.score).toBe(10); expect(g.combo).toBe(1);
    g.objs.push({ id: 2, kind: 'nuvem', r: 22, x: g.player.x, y: g.player.y - 30, vy: 100, vx: 0 });
    run(g, 0.5);
    expect(g.lives).toBe(2); expect(g.combo).toBe(0);
  });
  it('acaba quando as vidas zeram', () => {
    const g = createGame({ seed: 5, lives: 1 });
    g.spawnIn = 999;
    g.objs.push({ id: 1, kind: 'nuvem', r: 22, x: g.player.x, y: g.player.y - 30, vy: 100, vx: 0 });
    run(g, 0.5);
    expect(g.over).toBe(true); expect(g.lives).toBe(0);
  });
  it('multiplicador limitado a x4', () => {
    expect(multiplier(0)).toBe(1); expect(multiplier(5)).toBe(2); expect(multiplier(100)).toBe(4);
  });
  it('um bot que segue os itens bons consegue pontuar (jogo é ganhável)', () => {
    const g = createGame({ seed: 7 });
    while (!g.over) {
      const target = g.objs.filter((o) => o.kind !== 'nuvem').sort((a, b) => b.y - a.y)[0];
      step(g, 1 / 60, target ? { targetX: target.x } : {});
    }
    expect(g.score).toBeGreaterThan(300);
  });
  it('rng uniforme o suficiente', () => {
    const r = mulberry32(9); let s = 0; for (let i = 0; i < 10000; i++) s += r();
    expect(s / 10000).toBeGreaterThan(0.45); expect(s / 10000).toBeLessThan(0.55);
  });
});
