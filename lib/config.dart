/// Valores injetados no build pelo GitHub Actions (--dart-define).
/// Nunca escreva as chaves direto no código.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const appNome = 'Fica Sóbrio';
const appSlogan = 'Cada dia sóbrio é um nível a mais.';
const linkDownload = String.fromEnvironment(
  'LINK_DOWNLOAD',
  defaultValue: 'https://biellog.github.io/fica-sobrio/',
);

/// Endereço do site (GitHub Pages) e links de convite.
const siteUrl = 'https://biellog.github.io/fica-sobrio/';
const pacoteAndroid = 'br.com.ficasobrio.fica_sobrio';

/// Página do jogo online no navegador, já na sala certa.
String linkSalaBrilha(String sala) => '${siteUrl}jogar/?sala=${Uri.encodeComponent(sala)}';

/// Página do código de convite (mostra o código com botão de copiar).
String linkConvite(String codigo) => '${siteUrl}convite.html?c=${Uri.encodeComponent(codigo)}';
