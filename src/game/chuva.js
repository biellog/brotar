// "Chuva Boa" — renderização em canvas + controles (mouse, toque e teclado).
import { createGame, step, KINDS, multiplier } from './chuva-engine.js';

export const info = {
  id: 'chuva', name: 'Chuva Boa', icon: '🌧️', duration: 45, lives: 3,
  desc: 'Mova o vasinho para pegar gotas 💧, sóis ☀️ e sementes douradas 🌰. Desvie das nuvens de tempestade ⛈️: elas são os gatilhos!',
  how: 'Mouse: só mover. Celular: arraste o dedo. Teclado: ← →',
};

export function mount(stage, { demo = false, sound, onUpdate = () => {}, onEnd = () => {} } = {}) {
  const canvas = document.createElement('canvas');
  canvas.className = 'game';
  canvas.setAttribute('aria-label', 'Área do jogo Chuva Boa');
  stage.append(canvas);
  const ctx = canvas.getContext('2d');
  // altura lógica acompanha a proporção da tela: nada fica esticado em celulares altos
  const r0 = canvas.getBoundingClientRect();
  const height = r0.width > 0 ? Math.round(Math.min(Math.max((360 * r0.height) / r0.width, 480), 820)) : 560;
  const g = createGame({ duration: demo ? 4 : info.duration, height });
  if (demo) globalThis.__brotarGame = g; // usado só pelos testes automatizados
  const input = { dir: 0, targetX: undefined };
  const fx = [];
  let raf = 0; let last = 0; let stopped = false; let flash = 0;

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const rect = canvas.getBoundingClientRect();
    canvas.width = Math.round(rect.width * dpr);
    canvas.height = Math.round(rect.height * dpr);
    ctx.setTransform((rect.width * dpr) / g.width, 0, 0, (rect.height * dpr) / g.height, 0, 0);
  }

  let rect = canvas.getBoundingClientRect();
  const toGameX = (clientX) => ((clientX - rect.left) / rect.width) * g.width;
  // Mouse: segue o cursor sempre (sem precisar clicar), mesmo se ele sair um pouco do canvas.
  // Toque: segue o dedo enquanto encosta. Em ambos, o vaso vai direto para a posição (sem atraso).
  const onMove = (e) => {
    if (e.pointerType === 'mouse' || e.buttons || e.pointerType === 'touch' || e.pointerType === 'pen') {
      input.targetX = toGameX(e.clientX);
      input.dir = 0;
    }
  };
  const onDown = (e) => { input.targetX = toGameX(e.clientX); };
  const onUp = (e) => { if (e.pointerType !== 'mouse') input.targetX = undefined; };
  const keys = new Set();
  const onKey = (e) => {
    if (!['ArrowLeft', 'ArrowRight', 'a', 'd'].includes(e.key)) return;
    e.preventDefault();
    if (e.type === 'keydown') keys.add(e.key); else keys.delete(e.key);
    input.dir = (keys.has('ArrowRight') || keys.has('d') ? 1 : 0) - (keys.has('ArrowLeft') || keys.has('a') ? 1 : 0);
    input.targetX = undefined;
  };
  const onResize = () => { resize(); rect = canvas.getBoundingClientRect(); };

  canvas.addEventListener('pointerdown', onDown);
  window.addEventListener('pointermove', onMove, { passive: true });
  window.addEventListener('pointerup', onUp);
  window.addEventListener('keydown', onKey);
  window.addEventListener('keyup', onKey);
  window.addEventListener('resize', onResize);
  resize();

  function draw() {
    const { width: W, height: H } = g;
    const sky = ctx.createLinearGradient(0, 0, 0, H);
    sky.addColorStop(0, '#bfe9ff'); sky.addColorStop(1, '#eafbe7');
    ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
    ctx.fillStyle = '#9fd99a';
    ctx.beginPath(); ctx.moveTo(0, H - 40);
    ctx.quadraticCurveTo(W * 0.25, H - 80, W * 0.5, H - 45); ctx.quadraticCurveTo(W * 0.75, H - 15, W, H - 55);
    ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.fill();
    ctx.fillStyle = '#6fbf73'; ctx.fillRect(0, H - 22, W, 22);

    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    for (const o of g.objs) {
      ctx.font = `${o.r * 2}px "Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", sans-serif`;
      ctx.fillText(KINDS[o.kind].icon, o.x, o.y);
    }

    const p = g.player; const grow = Math.min(g.combo, 20);
    ctx.strokeStyle = '#2e7d32'; ctx.lineWidth = 4; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(p.x, p.y - 14); ctx.lineTo(p.x, p.y - 30 - grow * 1.5); ctx.stroke();
    ctx.fillStyle = '#43a047';
    const ly = p.y - 26 - grow * 1.2;
    ctx.beginPath(); ctx.ellipse(p.x - 10, ly, 11, 6, -0.5, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath(); ctx.ellipse(p.x + 10, ly - 6, 11, 6, 0.5, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#c96f3b';
    ctx.beginPath();
    ctx.moveTo(p.x - p.w / 2, p.y - 16); ctx.lineTo(p.x + p.w / 2, p.y - 16);
    ctx.lineTo(p.x + p.w / 2 - 10, p.y + 18); ctx.lineTo(p.x - p.w / 2 + 10, p.y + 18); ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#a5532a'; ctx.fillRect(p.x - p.w / 2 - 3, p.y - 20, p.w + 6, 9);

    for (const f of fx) {
      ctx.globalAlpha = Math.max(f.life, 0);
      if (f.text) { ctx.font = 'bold 18px system-ui, sans-serif'; ctx.fillStyle = f.color; ctx.fillText(f.text, f.x, f.y); }
      else { ctx.fillStyle = f.color; ctx.beginPath(); ctx.arc(f.x, f.y, 3, 0, Math.PI * 2); ctx.fill(); }
      ctx.globalAlpha = 1;
    }
    if (flash > 0) { ctx.fillStyle = `rgba(80,80,120,${flash * 0.35})`; ctx.fillRect(0, 0, W, H); }
  }

  function frame(ts) {
    if (stopped) return;
    const dt = last ? (ts - last) / 1000 : 0;
    last = ts;
    step(g, dt, input);
    for (const e of g.events) {
      if (e.type === 'catch') {
        if (e.kind === 'semente') sound?.bonus(); else sound?.catch(g.combo);
        fx.push({ x: e.x, y: e.y - 20, text: `+${e.pts}`, color: multiplier(g.combo) > 1 ? '#f57f17' : '#1b5e20', life: 1, vy: -40 });
        for (let i = 0; i < 6; i++) fx.push({ x: e.x, y: e.y, vx: (Math.random() - 0.5) * 120, vy: -Math.random() * 120, color: '#4fc3f7', life: 0.7 });
      } else if (e.type === 'hit') {
        flash = 1; sound?.hit(); navigator.vibrate?.(80);
      } else if (e.type === 'miss') {
        sound?.miss();
      }
    }
    flash = Math.max(flash - dt * 2, 0);
    for (const f of fx) { f.x += (f.vx || 0) * dt; f.y += (f.vy || 0) * dt; f.life -= dt; }
    for (let i = fx.length - 1; i >= 0; i--) if (fx[i].life <= 0) fx.splice(i, 1);
    draw();
    onUpdate({ score: g.score, lives: g.lives, maxLives: 3, timeLeft: g.duration - g.t, label: g.combo >= 5 ? `x${multiplier(g.combo)} combo!` : '' });
    if (g.over) {
      cleanup();
      onEnd({ score: g.score, won: g.lives > 0, stats: `Melhor combo: ${g.bestCombo} · Itens pegos: ${g.caught}` });
      return;
    }
    raf = requestAnimationFrame(frame);
  }

  function cleanup() {
    stopped = true;
    cancelAnimationFrame(raf);
    canvas.removeEventListener('pointerdown', onDown);
    window.removeEventListener('pointermove', onMove);
    window.removeEventListener('pointerup', onUp);
    window.removeEventListener('keydown', onKey);
    window.removeEventListener('keyup', onKey);
    window.removeEventListener('resize', onResize);
  }

  raf = requestAnimationFrame(frame);
  return { stop: cleanup };
}
