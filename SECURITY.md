# Segurança do Brotar

Relatório da revisão de segurança feita em 03/11/2026 e dos controles implementados.

## Modelo de ameaça

| Ameaça | Controle | Teste |
|---|---|---|
| Usuário se dá pontos/itens chamando a API direto | Tabelas só com `SELECT` (RLS); toda escrita via RPC `SECURITY DEFINER` que valida regras | `db.test.js` › acesso direto às tabelas |
| Ler dados de outra pessoa | RLS `user_id = auth.uid()` em todas as tabelas | `db.test.js` › RLS; verificação automática de que **toda** tabela tem RLS |
| Anônimo chamando RPCs | `revoke execute … from public, anon`; só `authenticated` | `db.test.js` › anon não chama nenhuma RPC |
| Gasto duplo / check-in duplo em requisições simultâneas | `SELECT … FOR UPDATE` no perfil serializa as operações de pontos | `db.test.js` › corrida (10 compras e 8 check-ins simultâneos) |
| Burlar limites diários (jogo, anúncio, check-in) | Contador `daily_actions` com `UPDATE … WHERE count < limite` atômico | `db.test.js` |
| Trapaça na data de início (voltar 400 dias) | `start_journey` só funciona uma vez; depois só `reset_sobriety` (para *agora*) | `db.test.js` › anti-trapaça |
| Farm de marcos com recaídas | Cada marco paga **uma vez na vida** | `db.test.js` |
| Pontuação falsa do minijogo | Servidor limita a 20 sementes por partida e 3 partidas premiadas/dia; valida faixa | `db.test.js`, `engine.test.js` (dt limitado) |
| Injeção de SQL | Só parâmetros; `search_path = ''` em todas as funções (verificado em teste) | `db.test.js` › injeção, search_path |
| XSS (nome/motivação maliciosos) | Nenhum `innerHTML`: helper `h()` cria só TextNodes, bloqueia `javascript:` e handlers em string | `dom.test.js`, `app.spec.js` › XSS |
| Script injetado | CSP estrita sem `unsafe-inline`/`unsafe-eval`, `object-src 'none'` | `app.spec.js` › CSP |
| Vazamento de segredos | Só a chave pública anon vai para o app; o teste procura `service_role`/chaves privadas no bundle | `app.spec.js` › segredos |
| Dados locais adulterados/corrompidos | Validação de formato ao carregar; volta ao estado inicial | `backend-local.test.js`, `app.spec.js` |
| Cliente adulterado (botão desabilitado reativado) | Servidor recusa | `supabase.spec.js` |
| Dependências vulneráveis | `npm audit` no CI (0 vulnerabilidades; `overrides` para glob/minimatch) | CI |
| Backup do app expondo token de sessão | `allowBackup=false`, `usesCleartextTraffic=false`, depuração do WebView desligada | revisão manual |
| Chave de assinatura vazar | Keystore só em Secrets, decodificado em `$RUNNER_TEMP` e apagado depois; `*.jks` no `.gitignore` | revisão manual |
| CI com permissões demais | `permissions: contents: read` por padrão; escrita só nos jobs de Pages/Release | revisão manual |
| LGPD (dados de saúde) | Exportar dados e excluir conta no app; política de privacidade | `db.test.js`, `supabase.spec.js` |

## Testes de mutação

Para provar que os testes de segurança detectam falhas de verdade, foi injetada uma migração vulnerável
(`grant insert` em `points_ledger` + policy permissiva + RLS desligado em `relapses`). **Os testes falharam como esperado**
e voltaram a passar depois que a mutação foi removida.

## Limitações conhecidas

1. **Anúncio premiado sem verificação no servidor (SSV):** um cliente modificado pode pedir a recompensa sem assistir ao anúncio. O impacto é limitado a 45 sementes/dia pelo servidor. Melhoria futura: Server-Side Verification do AdMob numa Edge Function.
2. **A pontuação do minijogo é informada pelo cliente:** o impacto é limitado a 60 sementes/dia.
3. **A sobriedade é autodeclarada:** é uma ferramenta de apoio, não de fiscalização.
4. **No GitHub Pages não é possível definir cabeçalhos HTTP:** a CSP vai por `<meta>`, então `frame-ancestors` não se aplica. Para isso, use Cloudflare/Netlify.

## Configurações a revisar no Supabase

- Confirmação de e-mail ligada e senha com no mínimo 8 caracteres.
- Leaked password protection (se o plano permitir).
- Rate limits de Auth (padrões do Supabase).
- **Security Advisor** (Database → Advisors) sem alertas depois de rodar a migração.
