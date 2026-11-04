// Confere se o modo online do Brilha Junto funciona: dois clientes no mesmo canal,
// um envia uma posição e o outro precisa receber em tempo real (Supabase Realtime).
import { createClient } from '@supabase/supabase-js';

const url = process.env.SB_URL;
const chave = process.env.SB_KEY;
const canal = 'brilha-ci-' + Date.now();
const a = createClient(url, chave);
const b = createClient(url, chave);

const limite = setTimeout(() => {
  console.log('FALHOU: nenhuma mensagem chegou em 20 s');
  process.exit(2);
}, 20000);

const cb = b.channel(canal, { config: { presence: { key: 'ci-b' } } });
cb.on('broadcast', { event: 'p' }, (m) => {
  console.log('OK: o celular B recebeu a posição do celular A em tempo real ->', JSON.stringify(m.payload));
  clearTimeout(limite);
  process.exit(0);
});
cb.on('presence', { event: 'sync' }, () => console.log('presença no canal:', Object.keys(cb.presenceState()).length));
await new Promise((ok) => cb.subscribe((s) => { console.log('B:', s); if (s === 'SUBSCRIBED') ok(); }));
await cb.track({ i: 'ci-b', n: 'Teste', c: 4294955366 });

const ca = a.channel(canal);
await new Promise((ok) => ca.subscribe((s) => { console.log('A:', s); if (s === 'SUBSCRIBED') ok(); }));
setInterval(() => ca.send({ type: 'broadcast', event: 'p', payload: { j: [{ i: 'ci-a', x: 100, y: 200, s: 3 }] } }), 1000);
