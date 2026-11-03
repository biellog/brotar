// Aviso de atualização do app Android usando a tabela public.app_releases do Supabase.
const DISMISS_KEY = 'brotar:update-dismissed';

/** Decide qual aviso mostrar. Função pura (testada em tests/unit/updates.test.js). */
export function pickUpdate(currentBuild, releases, dismissedCode = 0) {
  const cur = Number(currentBuild) || 0;
  const valid = (releases ?? []).filter((r) => Number.isInteger(r?.version_code) && /^https:\/\/\S+$/.test(r?.url ?? ''));
  const newer = valid.filter((r) => r.version_code > cur).sort((a, b) => b.version_code - a.version_code);
  if (!newer.length) return null;
  const latest = newer[0];
  const mandatory = newer.some((r) => r.mandatory); // alguma versão pulada era obrigatória
  if (!mandatory && latest.version_code <= dismissedCode) return null;
  return { ...latest, mandatory };
}

export function getDismissed() { try { return Number(localStorage.getItem(DISMISS_KEY)) || 0; } catch { return 0; } }
export function setDismissed(code) { try { localStorage.setItem(DISMISS_KEY, String(code)); } catch { /* */ } }

/**
 * Verifica atualização ao abrir, ao voltar do segundo plano e ao vivo (Realtime).
 * show(release) é chamado quando há uma versão mais nova que a instalada.
 */
export async function watchUpdates(sb, show) {
  const { Capacitor } = await import('@capacitor/core');
  if (!sb || !Capacitor.isNativePlatform()) return () => {};
  const { App } = await import('@capacitor/app');
  const { build } = await App.getInfo();
  let shownCode = 0;

  const check = async () => {
    const { data, error } = await sb.from('app_releases')
      .select('version_code, version_name, notes, url, mandatory')
      .eq('platform', 'android').gt('version_code', Number(build) || 0)
      .order('version_code', { ascending: false }).limit(20);
    if (error) return;
    const up = pickUpdate(build, data, getDismissed());
    if (up && up.version_code !== shownCode) { shownCode = up.version_code; show(up); }
  };

  await check();
  const resume = await App.addListener('resume', check);
  const channel = sb.channel('app-releases')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'app_releases' }, () => check())
    .subscribe();
  return () => { resume.remove(); sb.removeChannel(channel); };
}
