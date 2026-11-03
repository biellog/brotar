// "Jardim da Memória" — lógica pura (sem DOM): encontre os pares de cartas.
import { mulberry32 } from './chuva-engine.js';

export const ICONS = ['🌻', '🌷', '🌵', '🌹', '🌸', '🍄', '🦋', '🐝', '🐦', '🌳', '🍀', '🐞'];
export const FLIP_BACK_DELAY = 0.8; // segundos que um par errado fica à mostra

export function createMemory({ seed = Date.now(), pairs = 8, duration = 90 } = {}) {
  const rng = mulberry32(seed);
  const pool = [...ICONS];
  for (let i = pool.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [pool[i], pool[j]] = [pool[j], pool[i]]; }
  const deck = [...pool.slice(0, pairs), ...pool.slice(0, pairs)];
  for (let i = deck.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [deck[i], deck[j]] = [deck[j], deck[i]]; }
  return {
    pairs, duration, t: 0, score: 0, moves: 0, matches: 0, mistakes: 0, combo: 0, bestCombo: 0, over: false, won: false,
    cards: deck.map((icon, id) => ({ id, icon, open: false, matched: false })),
    first: null, pending: null, events: [],
  };
}

/** Vira a carta i. Retorna true se a jogada foi aceita. */
export function flip(g, i) {
  g.events = [];
  const c = g.cards[i];
  if (g.over || !c || c.open || c.matched || g.pending) return false;
  c.open = true;
  g.events.push({ type: 'flip', i });
  if (g.first === null) { g.first = i; return true; }
  const a = g.cards[g.first];
  g.moves += 1;
  if (a.icon === c.icon) {
    a.matched = c.matched = true;
    g.matches += 1; g.combo += 1; g.bestCombo = Math.max(g.bestCombo, g.combo);
    const pts = 60 + 20 * Math.min(g.combo - 1, 4);
    g.score += pts;
    g.events.push({ type: 'match', i, j: g.first, pts });
    if (g.matches === g.pairs) finish(g, true);
  } else {
    g.mistakes += 1; g.combo = 0;
    g.pending = { a: g.first, b: i, until: g.t + FLIP_BACK_DELAY };
    g.events.push({ type: 'wrong', i, j: g.first });
  }
  g.first = null;
  return true;
}

function finish(g, won) {
  g.over = true; g.won = won;
  if (won) g.score += Math.round(Math.max(g.duration - g.t, 0) * 8); // bônus de tempo
  g.events.push({ type: 'over', won });
}

export function step(g, dt) {
  if (g.over) return g;
  g.events = [];
  g.t += Math.min(Math.max(dt, 0), 0.05);
  if (g.pending && g.t >= g.pending.until) {
    g.cards[g.pending.a].open = false;
    g.cards[g.pending.b].open = false;
    g.pending = null;
    g.events.push({ type: 'hide' });
  }
  if (g.t >= g.duration) finish(g, false);
  return g;
}
