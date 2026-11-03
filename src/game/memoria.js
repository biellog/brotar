// "Jardim da Memória" — interface (grade de cartas em DOM, acessível por teclado).
import { createMemory, flip, step } from './memoria-engine.js';

export const info = {
  id: 'memoria', name: 'Jardim da Memória', icon: '🃏', duration: 90, lives: 0,
  desc: 'Vire as cartas e encontre os 8 pares de plantas e bichinhos. Acertos seguidos valem mais, e terminar rápido dá bônus!',
  how: 'Toque ou clique nas cartas.',
};

export function mount(stage, { demo = false, sound, onUpdate = () => {}, onEnd = () => {} } = {}) {
  const g = createMemory({ duration: demo ? 4 : info.duration });
  if (demo) globalThis.__brotarGame = g;
  const grid = document.createElement('div');
  grid.className = 'mem-grid';
  const buttons = g.cards.map((c, i) => {
    const b = document.createElement('button');
    b.className = 'mem-card';
    b.dataset.i = String(i);
    b.setAttribute('aria-label', `Carta ${i + 1}`);
    const inner = document.createElement('span');
    inner.className = 'mem-inner';
    const back = document.createElement('span'); back.className = 'mem-back'; back.textContent = '🌱';
    const front = document.createElement('span'); front.className = 'mem-front'; front.textContent = c.icon;
    inner.append(back, front);
    b.append(inner);
    b.addEventListener('click', () => { if (flip(g, i)) { handle(); sync(); } });
    grid.append(b);
    return b;
  });
  stage.append(grid);

  function sync() {
    g.cards.forEach((c, i) => {
      buttons[i].classList.toggle('open', c.open || c.matched);
      buttons[i].classList.toggle('matched', c.matched);
      buttons[i].setAttribute('aria-label', c.open || c.matched ? `Carta ${i + 1}: ${c.icon}` : `Carta ${i + 1}`);
    });
  }
  function handle() {
    for (const e of g.events) {
      if (e.type === 'flip') sound?.flip();
      else if (e.type === 'match') { sound?.match(); [e.i, e.j].forEach((k) => buttons[k].animate?.([{ transform: 'scale(1.12)' }, { transform: 'scale(1)' }], 300)); }
      else if (e.type === 'wrong') { sound?.wrong(); navigator.vibrate?.(40); }
    }
  }

  let raf = 0; let last = 0; let stopped = false;
  function frame(ts) {
    if (stopped) return;
    const dt = last ? (ts - last) / 1000 : 0;
    last = ts;
    step(g, dt);
    if (g.events.some((e) => e.type === 'hide')) sync();
    onUpdate({ score: g.score, timeLeft: g.duration - g.t, label: g.combo >= 2 ? `${g.combo} seguidos!` : `${g.matches}/${g.pairs} pares` });
    if (g.over) {
      cleanup();
      onEnd({ score: g.score, won: g.won, stats: `Pares: ${g.matches}/${g.pairs} · Jogadas: ${g.moves} · Erros: ${g.mistakes}` });
      return;
    }
    raf = requestAnimationFrame(frame);
  }
  function cleanup() { stopped = true; cancelAnimationFrame(raf); }
  raf = requestAnimationFrame(frame);
  return { stop: cleanup };
}
