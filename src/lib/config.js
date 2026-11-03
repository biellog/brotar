// Configuração via variáveis de ambiente do Vite (definidas em .env ou nos Secrets do GitHub).
// A chave "anon"/"publishable" do Supabase é pública por natureza; a proteção real é o RLS.
// NUNCA coloque a service_role key aqui.
const env = import.meta.env ?? {};

// Aceita a URL colada de várias formas (com barra, com /rest/v1/...): usa só a origem.
export function normalizeSupabaseUrl(raw) {
  try { return new URL(String(raw ?? '').trim()).origin; } catch { return ''; }
}
export const SUPABASE_URL = normalizeSupabaseUrl(env.VITE_SUPABASE_URL);
export const SUPABASE_ANON_KEY = String(env.VITE_SUPABASE_ANON_KEY ?? '').trim();
// URL pública do site (GitHub Pages) — destino dos links de confirmação/redefinição de senha.
export const SITE_URL = env.VITE_SITE_URL || (globalThis.location ? location.origin + location.pathname : '');
export const hasSupabase = /^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(SUPABASE_URL) && SUPABASE_ANON_KEY.length > 20;

// AdMob — por padrão usa os IDs de TESTE oficiais do Google (nunca clique nos seus próprios anúncios reais).
export const ADMOB = {
  banner: env.VITE_ADMOB_BANNER_ID || 'ca-app-pub-3940256099942544/6300978111',
  rewarded: env.VITE_ADMOB_REWARDED_ID || 'ca-app-pub-3940256099942544/5224354917',
  testing: env.VITE_ADMOB_TESTING !== 'false',
};
