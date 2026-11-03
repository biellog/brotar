// "Colheita Feliz" — interface (canteiro 3x3 em DOM).
import { createHarvest, step, tap, CROPS, multiplier } from './colheita-engine.js';

export const info = {
  id: 'colheita', name: 'Colheita Feliz', icon: '🧺', duration: 40, lives: 3,
  desc: 'Frutos brotam da terra por pouco tempo: toque nos tomates 🍅, morangos 🍓 e estrelas 🌟. Não toque nas pragas 🐛, elas são os gatilhos!',
  how: 'Toque ou clique rápido. No teclado, use 1 a 9.',
};

export function mount(stage, { demo = false, sound, onUpdate = () => {}, onEnd = () => {} } = {}) {
  const g = createHarvest({ duration: demo ? 4 : info.duration });
  if (demo) globalThis.__brotarGame = g;
  const field = document.createElement('div');
  field.className = 'harvest';
  const cells = g.holes.map((_, i) => {
    const b = document.createElement('button');
    b.className = 'hole';
    b.dataset.i = String(i);
    b.setAttribute('aria-label', `Canteiro ${i + 1}`);
    const crop = document.createElement('span');
    crop.className = 'crop';
    b.append(crop);
    b.addEventListener('pointerdown', (e) => { e.preventDefault(); hit(i); });
    field.append(b);
    return { b, crop, kind: null };
  });
  stage.append(field);
  const onKey = (e) => { const n = Number(e.key); if (n >= 1 && n <= 9) hit(n - 1); };
  window.addEventListener('keydown', onKey);

  function float(i, text, cls) {
    const f = document.createElement('span');
    f.className = `float ${cls}`;
    f.textContent = text;
    cells[i].b.append(f);
    setTimeout(() => f.remove(), 700);
  }

  function hit(i) {
    if (!tap(g, i)) return;
    for (const e of g.events) {
      if (e.type === 'harvest') { if (e.kind === 'estrela') sound?.bonus(); else sound?.pop(g.combo); float(i, `+${e.pts}`, multiplier(g.combo) > 1 ? 'gold' : ''); }
      else if (e.type === 'hit') { sound?.hit(); navigator.vibrate?.(80); float(i, '💥', 'bad'); field.classList.add('shake'); setTimeout(() => field.classList.remove('shake'), 300); }
    }
    sync();
  }

  function sync() {
    g.holes.forEach((h, i) => {
      const kind = h?.kind ?? null;
      const c = cells[i];
      if (c.kind === kind) return;
      c.kind = kind;
      c.crop.textContent = kind ? CROPS[kind].icon : '';
      c.b.classList.toggle('up', !!kind);
      c.b.setAttribute('aria-label', kind ? `Canteiro ${i + 1}: ${kind}` : `Canteiro ${i + 1}`);
    });
  }

  let raf = 0; let last = 0; let stopped = false;
  function frame(ts) {
    if (stopped) return;
    const dt = last ? (ts - last) / 1000 : 0;
    last = ts;
    step(g, dt);
    for (const e of g.events) if (e.type === 'miss') sound?.miss();
    sync();
    onUpdate({ score: g.score, lives: g.lives, maxLives: 3, timeLeft: g.duration - g.t, label: g.combo >= 6 ? `x${multiplier(g.combo)} combo!` : '' });
    if (g.over) {
      cleanup();
      onEnd({ score: g.score, won: g.lives > 0, stats: `Colhidos: ${g.harvested} · Melhor sequência: ${g.bestCombo}` });
      return;
    }
    raf = requestAnimationFrame(frame);
  }
  function cleanup() { stopped = true; cancelAnimationFrame(raf); window.removeEventListener('keydown', onKey); }
  raf = requestAnimationFrame(frame);
  return { stop: cleanup };
}
