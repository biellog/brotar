/// Valores injetados no build pelo GitHub Actions (--dart-define).
/// Nunca escreva as chaves direto no código.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const appNome = 'Fica Sóbrio';
const appSlogan = 'Cada dia sóbrio é um nível a mais.';
const linkDownload = String.fromEnvironment(
  'LINK_DOWNLOAD',
  defaultValue: 'https://github.com/biellog/fica-sobrio/releases/latest',
);
