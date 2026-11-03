import './styles.css';
import { Capacitor } from '@capacitor/core';
import { h, clear } from './ui/dom.js';
import { plantScene } from './ui/plant.js';
import { LocalBackend } from './lib/backend-local.js';
import { hasSupabase, SUPABASE_URL, SUPABASE_ANON_KEY, SITE_URL } from './lib/config.js';
import { adsAvailable, showBanner, hideBanner, showRewarded } from './lib/ads.js';
import { sfx, unlockAudio, soundEnabled, setSoundEnabled, startMusic, stopMusic } from './lib/sound.js';
import { watchUpdates, setDismissed } from './lib/updates.js';
import {
  MILESTONES, MILESTONE_BONUS, MILESTONE_LABELS, DAILY_LIMIT, AD_REWARD, SHOP_ITEMS, PLANT_STAGES,
  soberDays, soberParts, nextMilestone, plantStage, gamePoints, checkinPoints,
} from './lib/rules.js';

const app = document.getElementById('app');
const S = { backend: null, data: null, view: 'jardim', sb: null, user: null, shopTab: 'planta', busy: false };
const GUEST_FLAG = 'brotar:guest-chosen';
const NATIVE = Capacitor.isNativePlatform();

/** Abre um link fora do app. No Android, navegar para outro domínio faz o Capacitor abrir o navegador do sistema. */
function openExternal(url) {
  if (NATIVE) location.href = url; else window.open(url, '_blank', 'noopener');
}
if (NATIVE) {
  document.addEventListener('click', (e) => {
    const a = e.target.closest?.('a[target="_blank"]');
    if (!a) return;
    let url = new URL(a.getAttribute('href'), location.href);
    // páginas do próprio app (ex.: privacidade) abrem na versão publicada do site, se configurada
    if (url.origin === location.origin && /^https:\/\/(?!localhost)/.test(SITE_URL)) url = new URL(url.pathname.split('/').pop(), SITE_URL);
    if (url.origin === location.origin) return;
    e.preventDefault();
    openExternal(url.href);
  });
}

const TIPS = [
  'A vontade é como uma onda: sobe, atinge o pico e passa. Respire e surfe nela.',
  'Beba água, coma algo e descanse. Fome, sede e cansaço aumentam a vontade.',
  'Conte para alguém de confiança como você está hoje.',
  'Um dia de cada vez. Hoje é o único dia que você precisa vencer.',
  'Troque o gatilho: caminhe 10 minutos, tome um banho, ligue para alguém.',
  'Recaída não apaga seu progresso. Cada dia sóbrio continua contando na sua história.',
  'Anote três coisas boas de hoje, por menores que sejam.',
  'Evite lugares e pessoas que puxam você para trás, pelo menos por enquanto.',
];

// ------------------------------------------------------------------ utilidades
const fmt = (n) => new Intl.NumberFormat('pt-BR').format(n);
const plural = (n, s, p) => `${fmt(n)} ${n === 1 ? s : p}`;
const days = () => soberDays(S.data?.profile.sober_since);

function toast(msg, kind = 'ok') {
  document.querySelectorAll('.toast').forEach((old) => old.remove()); // um aviso por vez, sem sobreposição
  const t = h('div', { class: `toast ${kind}`, role: kind === 'err' ? 'alert' : 'status' }, msg);
  document.body.append(t);
  setTimeout(() => t.classList.add('show'), 10);
  setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 300); }, 3200);
}

function modal(title, body, actions = [], closeLabel = actions.length ? 'Cancelar' : 'Fechar') {
  const close = () => { wrap.remove(); document.removeEventListener('keydown', esc); };
  const esc = (e) => { if (e.key === 'Escape') close(); };
  const wrap = h('div', { class: 'modal-wrap', onclick: (e) => { if (e.target === wrap && closeLabel !== null) close(); } },
    h('div', { class: 'modal', role: 'dialog', 'aria-modal': 'true', 'aria-label': title },
      h('h2', {}, title), body,
      h('div', { class: 'modal-actions' },
        ...actions.map((a) => h('button', { class: a.class ?? 'btn', onclick: async () => { if ((await a.onClick?.()) !== false) close(); } }, a.label)),
        closeLabel === null ? null : h('button', { class: 'btn ghost', onclick: close }, closeLabel))));
  if (closeLabel !== null) document.addEventListener('keydown', esc);
  document.body.append(wrap);
  wrap.querySelector('button')?.focus();
  return close;
}

async function act(fn, okMsg) {
  if (S.busy) return null;
  S.busy = true;
  try {
    const r = await fn();
    if (r?.state) S.data = r.state; else if (r?.profile) S.data = r;
    if (okMsg) toast(typeof okMsg === 'function' ? okMsg(r) : okMsg);
    render();
    return r;
  } catch (e) {
    toast(e.message || 'Algo deu errado', 'err');
    return null;
  } finally {
    S.busy = false;
  }
}

// ------------------------------------------------------------------ boot
async function boot() {
  applyTheme('dia');
  ['pointerdown', 'keydown'].forEach((ev) => document.addEventListener(ev, unlockAudio, { passive: true }));
  setupNative();
  if (hasSupabase) {
    const [{ makeSupabase, SupabaseBackend }] = await Promise.all([import('./lib/backend-supabase.js')]);
    S.sb = makeSupabase(SUPABASE_URL, SUPABASE_ANON_KEY);
    S.SupabaseBackend = SupabaseBackend;
    watchUpdates(S.sb, showUpdate).catch(() => {});
    const { data } = await S.sb.auth.getSession();
    S.sb.auth.onAuthStateChange((ev, session) => {
      if (ev === 'SIGNED_OUT') { S.user = null; S.backend = null; renderAuth(); }
      else if (ev === 'PASSWORD_RECOVERY') renderNewPassword();
      else if (session?.user && S.user?.id !== session.user.id) { S.user = session.user; startWith(new SupabaseBackend(S.sb)); }
    });
    if (data.session?.user) { S.user = data.session.user; return startWith(new SupabaseBackend(S.sb)); }
    if (safeGet(GUEST_FLAG) === '1') return startWith(new LocalBackend());
    return renderAuth();
  }
  return startWith(new LocalBackend());
}

// ------------------------------------------------------------------ app Android
async function setupNative() {
  if (!NATIVE) return;
  const { App } = await import('@capacitor/app');
  const info = await App.getInfo().catch(() => null);
  if (info) S.appVersion = `${info.version} (build ${info.build})`;
  // botão "voltar" do Android: fecha jogo/janela antes de sair do app
  App.addListener('backButton', () => {
    const m = document.querySelector('.modal-wrap');
    if (m) return m.querySelector('.modal-actions .btn.ghost')?.click();
    if (currentGame) return currentGame.stop();
    if (S.data?.profile.sober_since && S.view !== 'jardim') { S.view = 'jardim'; return render(); }
    App.minimizeApp();
  });
}

/** Aviso de nova versão (dados vindos da tabela app_releases do Supabase). */
function showUpdate(rel) {
  document.querySelector('.modal-wrap.update')?.remove();
  sfx.bonus();
  const close = modal(`🌱 Nova versão ${rel.version_name}`, h('div', { class: 'stack' },
    h('p', {}, 'Uma atualização do Brotar está disponível.'),
    rel.notes ? h('p', { class: 'notes' }, rel.notes) : null,
    rel.mandatory ? h('p', { class: 'muted' }, 'Esta atualização é necessária para continuar usando o app.') : null),
  [{ label: 'Atualizar agora', onClick: () => { openExternal(rel.url); return !rel.mandatory; } }],
  rel.mandatory ? null : 'Depois');
  document.querySelector('.modal-wrap:last-of-type')?.classList.add('update');
  if (!rel.mandatory) {
    const later = [...document.querySelectorAll('.modal-wrap.update .btn.ghost')].pop();
    later?.addEventListener('click', () => setDismissed(rel.version_code));
  }
  return close;
}

function safeGet(k) { try { return localStorage.getItem(k); } catch { return null; } }
function safeSet(k, v) { try { if (v == null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch { /* */ } }

async function startWith(backend) {
  S.backend = backend;
  try {
    S.data = await backend.getState();
  } catch (e) {
    toast(e.message, 'err');
    return renderAuth();
  }
  render();
  if (S.data.profile.sober_since) showBanner();
}

// ------------------------------------------------------------------ autenticação
function renderAuth() {
  hideBanner();
  let mode = 'entrar';
  const email = h('input', { type: 'email', name: 'email', autocomplete: 'email', required: true, maxLength: 254, placeholder: 'seu@email.com' });
  const pass = h('input', { type: 'password', name: 'password', autocomplete: 'current-password', required: true, minLength: 8, maxLength: 72, placeholder: 'mínimo 8 caracteres' });
  const submit = h('button', { class: 'btn big', type: 'submit' }, 'Entrar');
  const switcher = h('button', { class: 'link', type: 'button', onclick: () => {
    mode = mode === 'entrar' ? 'criar' : 'entrar';
    submit.textContent = mode === 'entrar' ? 'Entrar' : 'Criar conta';
    switcher.textContent = mode === 'entrar' ? 'Não tem conta? Criar conta' : 'Já tem conta? Entrar';
    pass.autocomplete = mode === 'entrar' ? 'current-password' : 'new-password';
  } }, 'Não tem conta? Criar conta');

  const form = h('form', { class: 'card auth', onsubmit: async (e) => {
    e.preventDefault();
    if (S.busy) return;
    S.busy = true; submit.disabled = true;
    try {
      const creds = { email: email.value.trim(), password: pass.value };
      const { error, data } = mode === 'entrar'
        ? await S.sb.auth.signInWithPassword(creds)
        : await S.sb.auth.signUp({ ...creds, options: { emailRedirectTo: SITE_URL } });
      if (error) throw error;
      if (mode === 'criar' && !data.session) toast('Conta criada! Confirme pelo link enviado ao seu e-mail.');
    } catch (err) {
      toast(err.message === 'Invalid login credentials' ? 'E-mail ou senha incorretos' : err.message, 'err');
    } finally { S.busy = false; submit.disabled = false; }
  } },
  h('label', {}, 'E-mail', email), h('label', {}, 'Senha', pass), submit, switcher,
  h('button', { class: 'link', type: 'button', onclick: async () => {
    if (!email.value.includes('@')) return toast('Digite seu e-mail primeiro', 'err');
    const { error } = await S.sb.auth.resetPasswordForEmail(email.value.trim(), { redirectTo: SITE_URL });
    toast(error ? error.message : 'Se o e-mail existir, enviamos um link para redefinir a senha.', error ? 'err' : 'ok');
  } }, 'Esqueci minha senha'));

  clear(app).append(h('main', { class: 'screen center' },
    h('div', { class: 'brand' }, h('img', { src: 'icon.svg', alt: '', width: 88, height: 88 }), h('h1', {}, 'Brotar'), h('p', {}, 'Cada dia sóbrio faz seu jardim crescer.')),
    form,
    h('button', { class: 'btn ghost', onclick: () => { safeSet(GUEST_FLAG, '1'); startWith(new LocalBackend()); } }, 'Continuar sem conta (salvo só neste aparelho)'),
    h('a', { class: 'small', href: 'privacidade.html', target: '_blank', rel: 'noopener' }, 'Política de privacidade')));
}

function renderNewPassword() {
  const pass = h('input', { type: 'password', minLength: 8, maxLength: 72, autocomplete: 'new-password' });
  modal('Nova senha', h('label', {}, 'Digite a nova senha', pass), [{ label: 'Salvar', onClick: async () => {
    if (pass.value.length < 8) { toast('Mínimo 8 caracteres', 'err'); return false; }
    const { error } = await S.sb.auth.updateUser({ password: pass.value });
    toast(error ? error.message : 'Senha alterada!', error ? 'err' : 'ok');
    return !error;
  } }]);
}

// ------------------------------------------------------------------ onboarding
function renderOnboarding() {
  const today = new Date();
  const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const date = h('input', { type: 'date', max: iso(today), min: iso(new Date(today.getFullYear() - 20, 0, 1)), value: iso(today) });
  const start = (d) => act(() => S.backend.startJourney(d.toISOString()), 'Sua jornada começou. Estamos com você! 🌱');
  clear(app).append(h('main', { class: 'screen center' },
    h('div', { class: 'brand' }, h('img', { src: 'icon.svg', alt: '', width: 88, height: 88 }), h('h1', {}, 'Bem-vindo(a) ao Brotar')),
    h('div', { class: 'card' },
      h('p', {}, 'Aqui cada dia sem álcool ou outras drogas vira ', h('b', {}, 'sementes'), ' para você cultivar um jardim só seu. Faça o check-in diário, jogue para distrair a vontade e desbloqueie plantas, bichinhos e temas.'),
      h('button', { class: 'btn big', onclick: () => start(new Date()) }, 'Começo hoje 🌱'),
      h('p', { class: 'muted' }, 'Ou já está sóbrio(a) há algum tempo? Informe desde quando:'),
      h('div', { class: 'row' }, date, h('button', { class: 'btn', onclick: () => {
        const [y, m, d] = date.value.split('-').map(Number);
        if (!y) return toast('Escolha uma data', 'err');
        start(new Date(y, m - 1, d));
      } }, 'Confirmar')),
      h('p', { class: 'small muted' }, 'Essa data não pode ser alterada depois, apenas reiniciada. Seja honesto(a) com você mesmo(a) 💚'))));
}

// ------------------------------------------------------------------ layout
function applyTheme(t) { document.documentElement.dataset.theme = t; }

const TABS = [
  ['jardim', '🌿', 'Jardim'], ['jogar', '🎮', 'Jogar'], ['loja', '🛍️', 'Loja'], ['marcos', '🏅', 'Marcos'], ['perfil', '👤', 'Perfil'],
];

function render() {
  if (!S.data) return;
  if (!S.data.profile.sober_since) return renderOnboarding();
  applyTheme(S.data.profile.theme);
  const views = { jardim: viewGarden, jogar: viewPlay, loja: viewShop, marcos: viewMilestones, perfil: viewProfile };
  clear(app).append(
    h('header', { class: 'top' },
      h('div', { class: 'hello' }, h('small', {}, 'Olá,'), h('strong', { class: 'name' }, S.data.profile.display_name)),
      h('div', { class: 'row' },
        h('div', { class: 'balance', title: 'Suas sementes', 'data-testid': 'balance' }, '🌱 ', h('b', {}, fmt(S.data.balance))),
        h('button', { class: 'sos', onclick: openSOS, 'aria-label': 'Preciso de ajuda agora' }, 'SOS'))),
    h('main', { class: 'screen', id: 'view' }, views[S.view]()),
    h('nav', { class: 'tabs' }, ...TABS.map(([id, icon, label]) =>
      h('button', { class: S.view === id ? 'active' : '', 'aria-current': S.view === id ? 'page' : null, onclick: () => { S.view = id; render(); window.scrollTo(0, 0); } },
        h('span', { 'aria-hidden': 'true' }, icon), label))));
}

// ------------------------------------------------------------------ Jardim
let ticker = 0;
function viewGarden() {
  const d = days();
  const parts = soberParts(S.data.profile.sober_since);
  const nm = nextMilestone(d);
  const stage = plantStage(d);
  const owned = SHOP_ITEMS.filter((i) => S.data.items.includes(i.id) && i.category !== 'tema');
  const doneToday = (S.data.today.checkin ?? 0) >= DAILY_LIMIT.checkin;
  const adsLeft = DAILY_LIMIT.anuncio - (S.data.today.anuncio ?? 0);
  const clock = h('span', { class: 'clock' }, `${parts.hours}h ${parts.minutes}min ${parts.seconds}s`);
  clearInterval(ticker);
  ticker = setInterval(() => {
    if (!clock.isConnected) return clearInterval(ticker);
    const p = soberParts(S.data.profile.sober_since);
    clock.textContent = `${p.hours}h ${p.minutes}min ${p.seconds}s`;
    if (p.days !== d) render();
  }, 1000);

  const slots = [[8, 70], [84, 74], [20, 86], [72, 88], [36, 80], [60, 78], [4, 90], [90, 90], [46, 92], [28, 72], [66, 70], [14, 78], [78, 82]];
  const garden = h('div', { class: 'garden' }, plantScene(stage, S.data.profile.theme),
    ...owned.map((it, i) => h('span', { class: 'deco', title: it.name, style: { left: `${slots[i % slots.length][0]}%`, top: `${slots[i % slots.length][1]}%`, animationDelay: `${i * 0.3}s` } }, it.icon)));

  const tip = TIPS[Math.floor(Date.now() / 86_400_000) % TIPS.length];
  return h('div', { class: 'stack' },
    h('section', { class: 'card hero' },
      h('div', { class: 'counter' }, h('span', { class: 'big-num', 'data-testid': 'days' }, fmt(d)), h('span', {}, d === 1 ? 'dia sóbrio' : 'dias sóbrios')),
      clock,
      S.data.profile.motivation ? h('p', { class: 'motivation' }, '“', S.data.profile.motivation, '”') : null),
    h('section', { class: 'card garden-card' }, garden,
      h('div', { class: 'stage' }, h('b', {}, PLANT_STAGES[stage].name), stage < PLANT_STAGES.length - 1 ? ` · próxima fase com ${plural(PLANT_STAGES[stage + 1].min, 'dia', 'dias')}` : ' · fase máxima! 🌼')),
    h('section', { class: 'card' },
      nm.next ? [
        h('div', { class: 'row between' }, h('span', {}, `Próximo marco: `, h('b', {}, MILESTONE_LABELS[nm.next])), h('span', { class: 'muted' }, `+${MILESTONE_BONUS[nm.next]} 🌱`)),
        h('div', { class: 'bar' }, h('div', { style: { width: `${Math.round(nm.progress * 100)}%` } })),
        h('small', { class: 'muted' }, `Faltam ${plural(nm.next - d, 'dia', 'dias')}`),
      ] : h('b', {}, 'Você completou todos os marcos. Inspirador! 🌳'),
      h('button', { class: 'btn big', disabled: doneToday, 'data-testid': 'checkin', onclick: async () => {
        const r = await act(() => S.backend.checkin(), (x) => x.bonus ? `+${x.points} 🌱 e marco desbloqueado: +${x.bonus} 🌱! 🎉` : `+${x.points} sementes. Orgulho de você! 💚`);
        if (r) (r.bonus ? sfx.milestone : sfx.checkin)();
      } },
      doneToday ? 'Check-in feito hoje ✔ Volte amanhã' : `Hoje estou sóbrio(a) · +${checkinPoints(d)} 🌱`),
      adsAvailable() && adsLeft > 0 ? h('button', { class: 'btn ghost', onclick: async () => {
        if (await showRewarded()) act(() => S.backend.claimAdReward(), `+${AD_REWARD} sementes pela rega extra 💧`);
        else toast('Anúncio indisponível agora', 'err');
      } }, `📺 Rega extra: assistir anúncio (+${AD_REWARD} 🌱, restam ${adsLeft})`) : null),
    h('section', { class: 'card tip' }, h('b', {}, '💡 Dica do dia'), h('p', {}, tip)));
}

// ------------------------------------------------------------------ Jogar
const GAMES = {
  chuva: () => import('./game/chuva.js'),
  memoria: () => import('./game/memoria.js'),
  colheita: () => import('./game/colheita.js'),
};
const GAME_CARDS = [
  { id: 'chuva', icon: '🌧️', name: 'Chuva Boa', desc: 'Pegue gotas, sóis e sementes com o vasinho. Desvie das tempestades.', time: '45 s' },
  { id: 'memoria', icon: '🃏', name: 'Jardim da Memória', desc: 'Encontre os 8 pares de plantas e bichinhos. Calmo e bom para focar.', time: '90 s' },
  { id: 'colheita', icon: '🧺', name: 'Colheita Feliz', desc: 'Toque nos frutos que brotam da terra, mas deixe as pragas em paz.', time: '40 s' },
];
let currentGame = null;

function soundButton(extraClass = '') {
  const b = h('button', { class: `btn ghost small ${extraClass}`, 'aria-label': 'Ligar ou desligar sons', 'data-testid': 'sound-toggle' });
  const paint = () => { b.textContent = soundEnabled() ? '🔊' : '🔇'; b.setAttribute('aria-pressed', String(soundEnabled())); };
  b.addEventListener('click', () => {
    setSoundEnabled(!soundEnabled());
    paint();
    if (currentGame && soundEnabled()) startMusic();
  });
  paint();
  return b;
}

function viewPlay() {
  const left = DAILY_LIMIT.jogo - (S.data.today.jogo ?? 0);
  return h('div', { class: 'stack' },
    h('section', { class: 'card' },
      h('div', { class: 'row between' }, h('h2', {}, '🎮 Jogos'), soundButton()),
      h('p', { class: 'muted' }, left > 0
        ? `Partidas premiadas hoje: ${left} de ${DAILY_LIMIT.jogo}, somando todos os jogos (1 🌱 a cada 50 pontos, até 20 por partida).`
        : 'Você já usou as partidas premiadas de hoje, mas pode continuar jogando para se distrair 💚')),
    ...GAME_CARDS.map((g) => h('section', { class: 'card game-card' },
      h('span', { class: 'game-icon', 'aria-hidden': 'true' }, g.icon),
      h('div', { class: 'game-info' }, h('b', {}, g.name), h('small', { class: 'muted' }, g.desc), h('small', { class: 'tag' }, `⏱ ${g.time}`)),
      h('button', { class: 'btn', 'data-testid': `play-${g.id}`, onclick: () => startGame(g.id) }, 'Jogar'))));
}

function closeGame(overlay, ctrl) {
  ctrl?.stop();
  stopMusic();
  overlay.remove();
  currentGame = null;
  render();
  showBanner();
}

async function startGame(id = 'chuva') {
  hideBanner();
  unlockAudio();
  const mod = await GAMES[id]();
  const { info } = mod;
  const hud = { score: h('b', {}, '0'), lives: h('span', { class: 'lives' }), time: h('span', {}, `${info.duration}s`), label: h('span', { class: 'combo' }) };
  let ctrl = null;
  const stage = h('div', { class: `stage stage-${id}` });
  const overlay = h('div', { class: 'game-wrap', 'data-testid': 'game' },
    h('div', { class: 'hud' }, h('span', {}, '⭐ ', hud.score), hud.label, hud.time, hud.lives,
      soundButton('hud-btn'),
      h('button', { class: 'btn ghost small hud-btn', onclick: () => closeGame(overlay, ctrl) }, 'Sair')),
    stage);
  document.body.append(overlay);
  currentGame = { overlay, stop: () => closeGame(overlay, ctrl) };
  sfx.start();
  startMusic();
  ctrl = mod.mount(stage, {
    demo: new URLSearchParams(location.search).has('demo'),
    sound: sfx,
    onUpdate: (u) => {
      hud.score.textContent = fmt(u.score);
      hud.time.textContent = `${Math.max(Math.ceil(u.timeLeft), 0)}s`;
      hud.label.textContent = u.label ?? '';
      hud.lives.textContent = u.maxLives ? '❤️'.repeat(u.lives) + '🤍'.repeat(Math.max(u.maxLives - u.lives, 0)) : '';
    },
    onEnd: async (res) => {
      stopMusic();
      sfx.over();
      const r = await act(() => S.backend.submitGame(res.score));
      const pts = r?.points ?? 0;
      if (pts > 0) setTimeout(() => sfx.coin(), 600);
      overlay.append(h('div', { class: 'game-over', 'data-testid': 'game-over' },
        h('h2', {}, res.won ? `${info.icon} Muito bem!` : `${info.icon} Fim de jogo`),
        h('p', { class: 'big-num' }, fmt(res.score)),
        h('p', {}, res.stats),
        h('p', {}, pts > 0 ? `Você ganhou +${pts} 🌱` : gamePoints(res.score) > 0 ? 'Sem partidas premiadas hoje, mas a distração valeu!' : 'Faça 50 pontos ou mais para ganhar sementes.'),
        h('p', { class: 'muted' }, 'Se a vontade apertou, lembre: ela passa. Você está indo bem.'),
        h('div', { class: 'row' },
          h('button', { class: 'btn', onclick: () => { overlay.remove(); currentGame = null; startGame(id); } }, 'Jogar de novo'),
          h('button', { class: 'btn ghost', onclick: () => closeGame(overlay, null) }, 'Voltar'))));
    },
  });
}

// ------------------------------------------------------------------ Loja
function viewShop() {
  const cats = [['planta', 'Plantas'], ['decoracao', 'Decoração'], ['tema', 'Temas']];
  const items = SHOP_ITEMS.filter((i) => i.category === S.shopTab);
  return h('div', { class: 'stack' },
    h('div', { class: 'seg' }, ...cats.map(([id, label]) => h('button', { class: S.shopTab === id ? 'active' : '', onclick: () => { S.shopTab = id; render(); } }, label))),
    S.shopTab === 'tema' ? h('section', { class: 'card item free' }, h('span', { class: 'icon' }, '☀️'), h('div', {}, h('b', {}, 'Tema Dia'), h('small', { class: 'muted' }, 'Grátis')),
      S.data.profile.theme === 'dia' ? h('span', { class: 'tag' }, 'Em uso') : h('button', { class: 'btn small', onclick: () => act(() => S.backend.equipTheme('dia')) }, 'Usar')) : null,
    h('div', { class: 'grid' }, ...items.map((it) => {
      const has = S.data.items.includes(it.id);
      const can = S.data.balance >= it.price;
      let action;
      if (has && it.category === 'tema') {
        action = S.data.profile.theme === it.id ? h('span', { class: 'tag' }, 'Em uso') : h('button', { class: 'btn small', onclick: () => act(() => S.backend.equipTheme(it.id), 'Tema aplicado ✨') }, 'Usar');
      } else if (has) {
        action = h('span', { class: 'tag' }, 'No jardim ✔');
      } else {
        action = h('button', { class: 'btn small', disabled: !can, 'data-testid': `buy-${it.id}`, onclick: async () => { if (await act(() => S.backend.buy(it.id), `${it.name} foi para o seu jardim! 🎉`)) sfx.coin(); } }, `🌱 ${fmt(it.price)}`);
      }
      return h('section', { class: `card item ${has ? 'owned' : ''}` }, h('span', { class: 'icon' }, it.icon), h('b', {}, it.name), action);
    })),
    h('p', { class: 'muted center-text' }, 'Ganhe sementes com o check-in diário, marcos de sobriedade e o minijogo.'));
}

// ------------------------------------------------------------------ Marcos
function viewMilestones() {
  const d = days();
  return h('div', { class: 'stack' },
    h('section', { class: 'card row around' },
      h('div', { class: 'stat' }, h('b', {}, fmt(d)), h('small', {}, 'dias agora')),
      h('div', { class: 'stat' }, h('b', {}, fmt(Math.max(S.data.profile.best_streak_days, d))), h('small', {}, 'melhor sequência')),
      h('div', { class: 'stat' }, h('b', {}, `${S.data.milestones.length}/${MILESTONES.length}`), h('small', {}, 'marcos'))),
    ...MILESTONES.map((m) => {
      const got = S.data.milestones.includes(m);
      return h('section', { class: `card milestone ${got ? 'got' : ''}` },
        h('span', { class: 'icon' }, got ? '🏅' : '🔒'),
        h('div', {}, h('b', {}, MILESTONE_LABELS[m]), h('small', { class: 'muted' }, got ? 'Conquistado!' : d >= m ? 'Faça o check-in para resgatar' : `Faltam ${plural(m - d, 'dia', 'dias')}`)),
        h('span', { class: 'tag' }, `+${MILESTONE_BONUS[m]} 🌱`));
    }));
}

// ------------------------------------------------------------------ Perfil
function viewProfile() {
  const p = S.data.profile;
  const name = h('input', { value: p.display_name, maxLength: 40, required: true });
  const mot = h('textarea', { maxLength: 280, rows: 3, placeholder: 'Ex.: Pela minha saúde e pela minha família' }, p.motivation);
  const zones = ['America/Sao_Paulo', 'America/Manaus', 'America/Cuiaba', 'America/Belem', 'America/Fortaleza', 'America/Recife', 'America/Rio_Branco', 'America/Noronha', 'Europe/Lisbon'];
  const detected = Intl.DateTimeFormat().resolvedOptions().timeZone;
  if (detected && !zones.includes(detected)) zones.push(detected);
  if (!zones.includes(p.tz)) zones.push(p.tz);
  const tz = h('select', {}, ...zones.map((z) => h('option', { value: z, selected: z === p.tz }, z.replace('_', ' '))));
  const isLocal = S.backend.kind === 'local';

  return h('div', { class: 'stack' },
    h('form', { class: 'card', onsubmit: (e) => { e.preventDefault(); act(() => S.backend.updateProfile(name.value, mot.value, tz.value), 'Perfil salvo'); } },
      h('h2', {}, 'Seu perfil'),
      h('label', {}, 'Como quer ser chamado(a)', name),
      h('label', {}, 'Sua motivação (aparece no jardim)', mot),
      h('label', {}, 'Fuso horário (define a virada do dia)', tz),
      h('button', { class: 'btn', type: 'submit' }, 'Salvar')),
    h('section', { class: 'card' },
      h('h2', {}, 'Recaída'),
      h('p', { class: 'muted' }, 'Acontece, e não apaga o que você construiu. Seu jardim, sementes e marcos continuam com você. A contagem de dias só recomeça.'),
      h('button', { class: 'btn warn', onclick: () => modal('Recomeçar a contagem?', h('p', {}, 'Tudo bem. O importante é continuar. Suas sementes e itens ficam guardados. Quer recomeçar a contagem agora?'),
        [{ label: 'Recomeçar hoje', class: 'btn warn', onClick: () => act(() => S.backend.resetSobriety(), 'Novo começo. Um dia de cada vez 💚') }]) }, 'Tive uma recaída')),
    h('section', { class: 'card' },
      h('h2', {}, 'Conta e dados'),
      isLocal
        ? h('p', { class: 'muted' }, hasSupabase ? 'Você está sem conta: seus dados ficam só neste aparelho.' : 'Modo local: seus dados ficam só neste aparelho.')
        : h('p', { class: 'muted' }, 'Conectado como ', h('b', {}, S.user?.email ?? '')),
      isLocal && hasSupabase ? h('button', { class: 'btn', onclick: () => { safeSet(GUEST_FLAG, null); renderAuth(); } }, 'Entrar / criar conta para salvar na nuvem') : null,
      h('button', { class: 'btn ghost', onclick: exportData }, 'Baixar meus dados (JSON)'),
      !isLocal ? h('button', { class: 'btn ghost', onclick: () => S.sb.auth.signOut() }, 'Sair') : null,
      h('button', { class: 'btn danger', onclick: confirmDelete }, isLocal ? 'Apagar todos os dados' : 'Excluir minha conta'),
      h('a', { class: 'small', href: 'privacidade.html', target: '_blank', rel: 'noopener' }, 'Política de privacidade')),
    h('section', { class: 'card row between' }, h('span', {}, 'Sons e música'), soundButton()),
    h('p', { class: 'small muted center-text' }, 'O Brotar é uma ferramenta de apoio e não substitui tratamento profissional.'),
    S.appVersion ? h('p', { class: 'small muted center-text' }, `Versão ${S.appVersion}`) : null);
}

async function exportData() {
  const data = await S.backend.exportData();
  const url = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }));
  const a = h('a', { href: url, download: 'brotar-meus-dados.json' });
  document.body.append(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function confirmDelete() {
  const input = h('input', { placeholder: 'digite APAGAR' });
  modal('Excluir tudo?', h('div', {}, h('p', {}, 'Isso apaga definitivamente sua conta, sementes, itens e histórico. Não pode ser desfeito.'), input), [{
    label: 'Excluir definitivamente', class: 'btn danger', onClick: async () => {
      if (input.value.trim().toUpperCase() !== 'APAGAR') { toast('Digite APAGAR para confirmar', 'err'); return false; }
      try {
        await S.backend.deleteAccount();
        safeSet(GUEST_FLAG, null);
        toast('Dados apagados.');
        S.data = null; S.view = 'jardim';
        if (hasSupabase) renderAuth(); else startWith(new LocalBackend());
      } catch (e) { toast(e.message, 'err'); return false; }
      return true;
    },
  }]);
}

// ------------------------------------------------------------------ SOS
function openSOS() {
  const circle = h('div', { class: 'breath' }, h('span', {}, 'Toque para começar'));
  let timer = 0;
  const phases = [['Inspire…', 4000, 'in'], ['Segure…', 4000, 'hold'], ['Solte devagar…', 6000, 'out']];
  const run = (i = 0) => {
    if (!circle.isConnected) return;
    const [label, ms, cls] = phases[i % 3];
    circle.className = `breath ${cls}`;
    if (cls === 'in') sfx.breatheIn(); else if (cls === 'out') sfx.breatheOut();
    circle.firstChild.textContent = label;
    timer = setTimeout(() => run(i + 1), ms);
  };
  circle.addEventListener('click', () => { unlockAudio(); clearTimeout(timer); run(); }, { once: true });
  modal('Você não está sozinho(a) 💚', h('div', { class: 'sos-body' },
    h('p', {}, 'A vontade é forte agora, mas ela passa — geralmente em 15 a 30 minutos. Vamos respirar juntos:'),
    circle,
    h('ul', { class: 'help' },
      h('li', {}, h('a', { href: 'tel:188' }, '📞 CVV — 188'), ' (24h, gratuito, apoio emocional)'),
      h('li', {}, h('a', { href: 'tel:192' }, '🚑 SAMU — 192'), ' em emergência médica'),
      h('li', {}, h('a', { href: 'https://www.aa.org.br', target: '_blank', rel: 'noopener noreferrer' }, 'Alcoólicos Anônimos (AA)')),
      h('li', {}, h('a', { href: 'https://www.na.org.br', target: '_blank', rel: 'noopener noreferrer' }, 'Narcóticos Anônimos (NA)')),
      h('li', {}, 'Procure o CAPS AD mais próximo (SUS, gratuito).')),
    S.data?.profile.motivation ? h('p', { class: 'motivation' }, 'Lembre-se: “', S.data.profile.motivation, '”') : null),
  [{ label: '🎮 Jogar para distrair', onClick: () => { S.view = 'jogar'; render(); startGame(); } }], 'Fechar');
}

boot();
