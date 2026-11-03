import { describe, it, expect } from 'vitest';
import { createMemory, flip, step as memStep, FLIP_BACK_DELAY } from '../../src/game/memoria-engine.js';
import { createHarvest, step as hStep, tap, CROPS } from '../../src/game/colheita-engine.js';
import { createGame, step as chuvaStep } from '../../src/game/chuva-engine.js';

const advance = (g, fn, secs) => { for (let i = 0; i < secs * 60; i++) fn(g, 1 / 60); };

describe('Chuva Boa: controle sem atraso', () => {
  it('o vaso vai direto para a posição do ponteiro no mesmo quadro', () => {
    const g = createGame({ seed: 1 });
    chuvaStep(g, 1 / 60, { targetX: 50 });
    expect(g.player.x).toBe(50);
    chuvaStep(g, 1 / 60, { targetX: 300 });
    expect(g.player.x).toBe(300);
  });
});

describe('Jardim da Memória', () => {
  it('baralho tem exatamente 2 de cada ícone', () => {
    const g = createMemory({ seed: 3 });
    const count = {};
    g.cards.forEach((c) => { count[c.icon] = (count[c.icon] ?? 0) + 1; });
    expect(Object.values(count)).toEqual(Array(8).fill(2));
  });
  it('par certo pontua; par errado fecha depois do atraso e bloqueia cliques', () => {
    const g = createMemory({ seed: 3 });
    const a = 0; const b = g.cards.findIndex((c, i) => i !== a && c.icon === g.cards[a].icon);
    const wrong = g.cards.findIndex((c, i) => i !== a && c.icon !== g.cards[a].icon);
    flip(g, a); flip(g, wrong);
    expect(g.mistakes).toBe(1);
    expect(flip(g, b)).toBe(false); // bloqueado enquanto mostra o erro
    advance(g, memStep, FLIP_BACK_DELAY + 0.1);
    expect(g.cards[a].open).toBe(false);
    flip(g, a); flip(g, b);
    expect(g.cards[a].matched && g.cards[b].matched).toBe(true);
    expect(g.score).toBe(60);
  });
  it('não aceita virar a mesma carta duas vezes', () => {
    const g = createMemory({ seed: 3 });
    expect(flip(g, 0)).toBe(true);
    expect(flip(g, 0)).toBe(false);
    expect(g.moves).toBe(0);
  });
  it('jogador perfeito vence com bônus de tempo', () => {
    const g = createMemory({ seed: 9 });
    const seen = new Set();
    for (let i = 0; i < g.cards.length; i++) {
      if (seen.has(i)) continue;
      const j = g.cards.findIndex((c, k) => k !== i && c.icon === g.cards[i].icon);
      seen.add(i); seen.add(j);
      flip(g, i); flip(g, j);
      memStep(g, 0.5);
    }
    expect(g.over).toBe(true); expect(g.won).toBe(true);
    expect(g.score).toBeGreaterThan(1000); // vale as 20 sementes máximas
  });
  it('acaba por tempo', () => {
    const g = createMemory({ seed: 1, duration: 2 });
    advance(g, memStep, 3);
    expect(g.over).toBe(true); expect(g.won).toBe(false);
  });
});

describe('Colheita Feliz', () => {
  it('colher dá pontos; praga tira vida; buraco vazio não faz nada', () => {
    const g = createHarvest({ seed: 2 });
    g.holes[0] = { kind: 'morango', until: 99 };
    g.holes[1] = { kind: 'praga', until: 99 };
    expect(tap(g, 0)).toBe(true);
    expect(g.score).toBe(CROPS.morango.points);
    tap(g, 1);
    expect(g.lives).toBe(2); expect(g.combo).toBe(0);
    expect(tap(g, 5)).toBe(false);
  });
  it('fruto que some quebra a sequência; praga que some não pune', () => {
    const g = createHarvest({ seed: 2 });
    g.spawnIn = 999; g.combo = 4;
    g.holes[0] = { kind: 'praga', until: 0.1 };
    hStep(g, 0.05); hStep(g, 0.05); hStep(g, 0.05);
    expect(g.combo).toBe(4); expect(g.lives).toBe(3);
    g.holes[1] = { kind: 'tomate', until: g.t + 0.01 };
    hStep(g, 0.05);
    expect(g.combo).toBe(0);
  });
  it('três pragas encerram o jogo', () => {
    const g = createHarvest({ seed: 2 });
    for (let i = 0; i < 3; i++) { g.holes[i] = { kind: 'praga', until: 99 }; tap(g, i); }
    expect(g.over).toBe(true); expect(g.lives).toBe(0);
  });
  it('um bot que colhe tudo de bom pontua bem', () => {
    const g = createHarvest({ seed: 11 });
    while (!g.over) {
      hStep(g, 1 / 30);
      g.holes.forEach((h, i) => { if (h && !CROPS[h.kind].harmful) tap(g, i); });
    }
    expect(g.lives).toBe(3);
    expect(g.score).toBeGreaterThan(500);
  });
});
