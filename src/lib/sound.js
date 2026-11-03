// Efeitos sonoros e música suave sintetizados com Web Audio (sem arquivos de áudio).
const PREF = 'brotar:sound';
let ctx = null;
let master = null;
let enabled = true;
try { enabled = localStorage.getItem(PREF) !== 'off'; } catch { /* sem armazenamento */ }

/** Navegadores só liberam áudio após um gesto do usuário: chame em pointerdown/keydown. */
export function unlockAudio() {
  if (!enabled) return;
  try {
    if (!ctx) {
      const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
      if (!AC) return;
      ctx = new AC();
      master = ctx.createGain();
      master.gain.value = 0.6;
      master.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
  } catch { ctx = null; }
}

export const soundEnabled = () => enabled;
export function setSoundEnabled(on) {
  enabled = !!on;
  try { localStorage.setItem(PREF, enabled ? 'on' : 'off'); } catch { /* */ }
  if (!enabled) stopMusic(); else unlockAudio();
}

function tone({ freq = 440, to, type = 'sine', dur = 0.15, vol = 0.2, delay = 0, attack = 0.008 }) {
  if (!enabled || !ctx || ctx.state !== 'running') return;
  const t0 = ctx.currentTime + delay;
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  if (to) osc.frequency.exponentialRampToValueAtTime(to, t0 + dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(vol, t0 + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g).connect(master);
  osc.start(t0);
  osc.stop(t0 + dur + 0.02);
}

function noise({ dur = 0.2, vol = 0.15, delay = 0, freq = 800 }) {
  if (!enabled || !ctx || ctx.state !== 'running') return;
  const t0 = ctx.currentTime + delay;
  const buf = ctx.createBuffer(1, Math.ceil(ctx.sampleRate * dur), ctx.sampleRate);
  const d = buf.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length);
  const src = ctx.createBufferSource();
  const f = ctx.createBiquadFilter();
  const g = ctx.createGain();
  src.buffer = buf; f.type = 'lowpass'; f.frequency.value = freq; g.gain.value = vol;
  src.connect(f).connect(g).connect(master);
  src.start(t0);
}

const PENTA = [523.25, 587.33, 659.25, 783.99, 880, 1046.5, 1174.66, 1318.5];
const notes = (list, step = 0.09, opts = {}) => list.forEach((f, i) => tone({ freq: f, delay: i * step, dur: 0.22, vol: 0.16, ...opts }));

export const sfx = {
  tap: () => tone({ freq: 660, dur: 0.06, vol: 0.08, type: 'triangle' }),
  catch: (combo = 0) => tone({ freq: PENTA[Math.min(combo, PENTA.length - 1)], dur: 0.14, vol: 0.18, type: 'triangle' }),
  bonus: () => notes([1046.5, 1318.5, 1568], 0.06, { type: 'triangle' }),
  hit: () => { tone({ freq: 160, to: 70, dur: 0.3, vol: 0.3, type: 'sawtooth' }); noise({ dur: 0.25, vol: 0.12, freq: 500 }); },
  miss: () => tone({ freq: 300, to: 220, dur: 0.12, vol: 0.06 }),
  flip: () => noise({ dur: 0.06, vol: 0.08, freq: 3000 }),
  match: () => notes([659.25, 987.77], 0.07, { type: 'triangle' }),
  wrong: () => tone({ freq: 220, to: 180, dur: 0.18, vol: 0.12, type: 'square' }),
  pop: (combo = 0) => { tone({ freq: 500 + combo * 40, to: 900 + combo * 40, dur: 0.09, vol: 0.18 }); noise({ dur: 0.04, vol: 0.05, freq: 4000 }); },
  coin: () => notes([987.77, 1318.5], 0.08, { type: 'square', vol: 0.08 }),
  checkin: () => notes([523.25, 659.25, 783.99, 1046.5], 0.1),
  milestone: () => notes([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5], 0.11, { type: 'triangle', dur: 0.3 }),
  start: () => notes([392, 523.25, 659.25], 0.08, { type: 'triangle' }),
  over: () => notes([783.99, 659.25, 523.25, 392], 0.14, { dur: 0.35 }),
  breatheIn: () => tone({ freq: 220, to: 330, dur: 3.8, vol: 0.06, attack: 1.5 }),
  breatheOut: () => tone({ freq: 330, to: 196, dur: 5.8, vol: 0.05, attack: 1 }),
};

// ---- música ambiente suave (arpejo pentatônico gerado) durante os jogos
let musicTimer = 0;
let musicStep = 0;
const PROG = [[261.63, 329.63, 392, 493.88], [220, 261.63, 329.63, 392], [174.61, 220, 261.63, 329.63], [196, 246.94, 293.66, 392]];
export function startMusic() {
  stopMusic();
  musicStep = 0;
  musicTimer = setInterval(() => {
    if (!enabled || !ctx || ctx.state !== 'running') return;
    const chord = PROG[Math.floor(musicStep / 8) % PROG.length];
    const f = chord[[0, 2, 1, 3, 2, 1, 3, 2][musicStep % 8]];
    tone({ freq: f, dur: 0.5, vol: 0.035, type: 'sine', attack: 0.02 });
    if (musicStep % 8 === 0) tone({ freq: chord[0] / 2, dur: 1.9, vol: 0.04, attack: 0.1 });
    musicStep++;
  }, 260);
}
export function stopMusic() { clearInterval(musicTimer); musicTimer = 0; }
