// "Colheita Feliz" — lógica pura: toque nos frutos que brotam; não toque nas pragas.
import { mulberry32 } from './chuva-engine.js';

export const CROPS = {
  tomate: { icon: '🍅', points: 10, weight: 48 },
  morango: { icon: '🍓', points: 20, weight: 24 },
  estrela: { icon: '🌟', points: 50, weight: 6 },
  praga: { icon: '🐛', points: 0, weight: 22, harmful: true },
};

export const multiplier = (combo) => Math.min(1 + Math.floor(combo / 6), 3);

export function createHarvest({ seed = Date.now(), holes = 9, duration = 40, lives = 3 } = {}) {
  return {
    rng: mulberry32(seed), duration, t: 0, score: 0, lives, combo: 0, bestCombo: 0, harvested: 0, over: false,
    holes: Array.from({ length: holes }, () => null), spawnIn: 0.3, events: [],
  };
}

const difficulty = (g) => Math.min(g.t / g.duration, 1);

function pick(rng) {
  const list = Object.entries(CROPS);
  let r = rng() * list.reduce((a, [, c]) => a + c.weight, 0);
  for (const [k, c] of list) { if ((r -= c.weight) <= 0) return k; }
  return 'tomate';
}

export function step(g, dt) {
  if (g.over) return g;
  g.events = [];
  dt = Math.min(Math.max(dt, 0), 0.05);
  g.t += dt;
  const diff = difficulty(g);

  g.holes.forEach((h, i) => {
    if (h && g.t >= h.until) {
      g.holes[i] = null;
      if (!CROPS[h.kind].harmful) { g.combo = 0; g.events.push({ type: 'miss', i }); }
    }
  });

  g.spawnIn -= dt;
  if (g.spawnIn <= 0) {
    const free = g.holes.map((h, i) => (h ? -1 : i)).filter((i) => i >= 0);
    if (free.length) {
      const i = free[Math.floor(g.rng() * free.length)];
      const kind = pick(g.rng);
      g.holes[i] = { kind, until: g.t + (1.7 - diff * 0.8) + g.rng() * 0.3 };
      g.events.push({ type: 'spawn', i, kind });
    }
    g.spawnIn = 0.6 - diff * 0.3 + g.rng() * 0.15;
  }

  if (g.lives <= 0 || g.t >= g.duration) { g.over = true; g.lives = Math.max(g.lives, 0); g.events.push({ type: 'over' }); }
  return g;
}

/** Toque no buraco i. */
export function tap(g, i) {
  g.events = [];
  const h = g.holes[i];
  if (g.over || !h) return false;
  g.holes[i] = null;
  const c = CROPS[h.kind];
  if (c.harmful) {
    g.lives -= 1; g.combo = 0;
    g.events.push({ type: 'hit', i });
    if (g.lives <= 0) { g.over = true; g.lives = 0; g.events.push({ type: 'over' }); }
  } else {
    g.combo += 1; g.harvested += 1; g.bestCombo = Math.max(g.bestCombo, g.combo);
    const pts = c.points * multiplier(g.combo);
    g.score += pts;
    g.events.push({ type: 'harvest', i, pts, kind: h.kind });
  }
  return true;
}
