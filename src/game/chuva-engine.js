// "Chuva Boa" — lógica pura do minijogo (sem DOM), determinística com semente.
// Pegue gotas, sóis e sementes douradas com o vasinho; desvie das nuvens de tempestade (gatilhos).

export const KINDS = {
  gota: { points: 10, r: 14, weight: 60, icon: '💧' },
  sol: { points: 25, r: 16, weight: 18, icon: '☀️' },
  semente: { points: 50, r: 15, weight: 5, icon: '🌰' },
  nuvem: { points: 0, r: 22, weight: 22, icon: '⛈️', harmful: true },
};

export function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function createGame({ seed = Date.now(), width = 360, height = 560, duration = 45, lives = 3 } = {}) {
  return {
    width, height, duration, rng: mulberry32(seed),
    t: 0, score: 0, lives, combo: 0, bestCombo: 0, caught: 0, over: false,
    spawnIn: 0.4, nextId: 1,
    player: { x: width / 2, y: height - 56, w: 70, speed: 420 },
    objs: [], events: [],
  };
}

export const multiplier = (combo) => Math.min(1 + Math.floor(combo / 5), 4);
export const difficulty = (g) => Math.min(g.t / g.duration, 1); // 0 → 1

function pickKind(rng, diff) {
  const entries = Object.entries(KINDS).map(([k, v]) => [k, k === 'nuvem' ? v.weight * (1 + diff * 1.2) : v.weight]);
  const total = entries.reduce((a, [, w]) => a + w, 0);
  let r = rng() * total;
  for (const [k, w] of entries) { if ((r -= w) <= 0) return k; }
  return 'gota';
}

/** Avança a simulação. input = { dir: -1|0|1, targetX?: number } */
export function step(g, dt, input = {}) {
  if (g.over) return g;
  dt = Math.min(Math.max(dt, 0), 0.05);
  g.events = [];
  g.t += dt;
  const diff = difficulty(g);

  // movimento do jogador
  const p = g.player;
  if (typeof input.targetX === 'number') {
    // controle direto (mouse/dedo): o vaso vai exatamente para onde o ponteiro está — sem atraso
    p.x = input.targetX;
  } else if (input.dir) {
    p.x += input.dir * p.speed * dt;
  }
  p.x = Math.min(Math.max(p.x, p.w / 2), g.width - p.w / 2);

  // surgimento
  g.spawnIn -= dt;
  if (g.spawnIn <= 0) {
    const kind = pickKind(g.rng, diff);
    const r = KINDS[kind].r;
    g.objs.push({
      id: g.nextId++, kind, r,
      x: r + g.rng() * (g.width - 2 * r), y: -r,
      vy: 140 + diff * 170 + g.rng() * 60,
      vx: (g.rng() - 0.5) * 40 * diff,
    });
    g.spawnIn = 0.75 - diff * 0.4 + g.rng() * 0.25;
  }

  // física e colisão
  const top = p.y - 18;
  for (const o of g.objs) {
    o.y += o.vy * dt;
    o.x = Math.min(Math.max(o.x + o.vx * dt, o.r), g.width - o.r);
    if (!o.done && o.y + o.r * 0.6 >= top && o.y - o.r <= p.y + 10 && Math.abs(o.x - p.x) <= p.w / 2 + o.r * 0.5) {
      o.done = true;
      const k = KINDS[o.kind];
      if (k.harmful) {
        g.lives -= 1; g.combo = 0;
        g.events.push({ type: 'hit', x: o.x, y: o.y });
      } else {
        g.combo += 1; g.caught += 1;
        g.bestCombo = Math.max(g.bestCombo, g.combo);
        const pts = k.points * multiplier(g.combo);
        g.score += pts;
        g.events.push({ type: 'catch', x: o.x, y: o.y, pts, kind: o.kind });
      }
    } else if (!o.done && o.y - o.r > g.height) {
      o.done = true;
      if (!KINDS[o.kind].harmful) { g.combo = 0; g.events.push({ type: 'miss', x: o.x }); }
    }
  }
  g.objs = g.objs.filter((o) => !o.done);

  if (g.lives <= 0 || g.t >= g.duration) {
    g.over = true;
    g.lives = Math.max(g.lives, 0);
    g.events.push({ type: 'over' });
  }
  return g;
}
