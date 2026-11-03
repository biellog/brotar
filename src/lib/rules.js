// Regras do jogo. ESPELHO de supabase/migrations/*_init.sql — os testes em tests/db
// garantem que as duas implementações dão o mesmo resultado.

export const MILESTONES = [1, 3, 7, 14, 30, 60, 90, 180, 365];
export const MILESTONE_BONUS = { 1: 20, 3: 30, 7: 70, 14: 100, 30: 250, 60: 400, 90: 600, 180: 1000, 365: 2000 };
export const DAILY_LIMIT = { checkin: 1, jogo: 3, anuncio: 3 };
export const AD_REWARD = 15;
export const WELCOME_BONUS = 100;
export const DAY_MS = 86_400_000;

export const MILESTONE_LABELS = {
  1: 'Primeiro dia', 3: 'Três dias', 7: 'Uma semana', 14: 'Duas semanas', 30: 'Um mês',
  60: 'Dois meses', 90: 'Três meses', 180: 'Seis meses', 365: 'Um ano',
};

export const checkinPoints = (days) => 10 + Math.min(Math.max(days, 0), 20);
export const gamePoints = (score) => Math.min(Math.floor(Math.max(score, 0) / 50), 20);

/** Dias completos (24h) desde o início da jornada. */
export function soberDays(soberSince, now = Date.now()) {
  if (!soberSince) return 0;
  const start = typeof soberSince === 'number' ? soberSince : Date.parse(soberSince);
  if (Number.isNaN(start)) return 0;
  return Math.max(Math.floor((now - start) / DAY_MS), 0);
}

/** Decomposição para o contador ao vivo. */
export function soberParts(soberSince, now = Date.now()) {
  if (!soberSince) return { days: 0, hours: 0, minutes: 0, seconds: 0 };
  const ms = Math.max(now - Date.parse(soberSince), 0);
  return {
    days: Math.floor(ms / DAY_MS),
    hours: Math.floor((ms % DAY_MS) / 3_600_000),
    minutes: Math.floor((ms % 3_600_000) / 60_000),
    seconds: Math.floor((ms % 60_000) / 1000),
  };
}

export function nextMilestone(days) {
  const next = MILESTONES.find((m) => m > days);
  if (!next) return { next: null, prev: 365, progress: 1 };
  const prev = [...MILESTONES].reverse().find((m) => m <= days) ?? 0;
  return { next, prev, progress: (days - prev) / (next - prev) };
}

/** Estágio da planta principal (0 = semente … 6 = árvore florida). */
export const PLANT_STAGES = [
  { min: 0, name: 'Semente' }, { min: 1, name: 'Broto' }, { min: 3, name: 'Mudinha' },
  { min: 7, name: 'Planta jovem' }, { min: 30, name: 'Arbusto' }, { min: 90, name: 'Árvore' },
  { min: 365, name: 'Árvore florida' },
];
export function plantStage(days) {
  let s = 0;
  PLANT_STAGES.forEach((st, i) => { if (days >= st.min) s = i; });
  return s;
}

/** Data local (AAAA-MM-DD) num fuso horário IANA — usada para limites diários. */
export function localDay(tz = 'America/Sao_Paulo', now = Date.now()) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' })
    .format(new Date(now));
}

export const SHOP_ITEMS = [
  { id: 'girassol', name: 'Girassol', category: 'planta', price: 60, icon: '🌻' },
  { id: 'tulipa', name: 'Tulipa', category: 'planta', price: 80, icon: '🌷' },
  { id: 'cacto', name: 'Cacto resistente', category: 'planta', price: 100, icon: '🌵' },
  { id: 'rosa', name: 'Rosa', category: 'planta', price: 140, icon: '🌹' },
  { id: 'cerejeira', name: 'Cerejeira', category: 'planta', price: 250, icon: '🌸' },
  { id: 'bonsai', name: 'Bonsai sábio', category: 'planta', price: 400, icon: '🪴' },
  { id: 'ipe', name: 'Ipê amarelo', category: 'planta', price: 700, icon: '🌳' },
  { id: 'borboleta', name: 'Borboletas', category: 'decoracao', price: 90, icon: '🦋' },
  { id: 'passaro', name: 'Passarinho', category: 'decoracao', price: 120, icon: '🐦' },
  { id: 'cogumelo', name: 'Cogumelos', category: 'decoracao', price: 70, icon: '🍄' },
  { id: 'lago', name: 'Laguinho', category: 'decoracao', price: 300, icon: '🪷' },
  { id: 'abelha', name: 'Abelhas amigas', category: 'decoracao', price: 150, icon: '🐝' },
  { id: 'arco_iris', name: 'Arco-íris', category: 'decoracao', price: 900, icon: '🌈' },
  { id: 'noite', name: 'Tema Noite estrelada', category: 'tema', price: 200, icon: '🌙' },
  { id: 'outono', name: 'Tema Outono', category: 'tema', price: 200, icon: '🍂' },
  { id: 'aurora', name: 'Tema Aurora', category: 'tema', price: 500, icon: '🌌' },
];
