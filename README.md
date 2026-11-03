# 🌱 Brotar — Jardim da Sobriedade

> Cada dia sóbrio faz seu jardim crescer.

![Brotar](docs/promo-brotar.png)

O Brotar é um app (Android + site) que transforma a sobriedade num jogo leve e acolhedor:

- **Contador ao vivo** de dias, horas e minutos sóbrios, com a sua frase de motivação.
- **Jardim que cresce:** a planta principal muda de fase (semente → broto → … → árvore florida) com os dias.
- **Sementes (pontos):** ganhe com o check-in diário (10–30), **marcos** (1, 3, 7, 14, 30, 60, 90, 180 e 365 dias, até +2000), o minijogo e anúncios premiados.
- **Loja:** compre plantas, bichinhos e temas (Noite estrelada, Outono, Aurora) para o seu jardim.
- **Minijogo "Chuva Boa":** 45 s para pegar gotas, sóis e sementes e desviar das nuvens de tempestade (os gatilhos). Serve para distrair a vontade.
- **Botão SOS:** respiração guiada, CVV 188, SAMU 192, AA, NA e CAPS AD.
- **Recaída sem punição:** a contagem recomeça, mas sementes, itens e marcos ficam.
- **Conta na nuvem (Supabase)** ou **modo sem conta** (dados só no aparelho).
- **Privacidade:** exportar os dados e excluir a conta pelo próprio app (LGPD e exigência do Google Play).

| Boas-vindas | Jardim | Jogo | Loja | Marcos | SOS | Tema Noite |
|---|---|---|---|---|---|---|
| ![](docs/screenshots/01-boas-vindas.png) | ![](docs/screenshots/02-jardim.png) | ![](docs/screenshots/03-jogo.png) | ![](docs/screenshots/04-loja.png) | ![](docs/screenshots/05-marcos.png) | ![](docs/screenshots/06-sos.png) | ![](docs/screenshots/07-tema-noite.png) |

## Tecnologia

- Web: JavaScript puro + Vite (sem framework, ~20 KB gzip no carregamento inicial)
- Android: Capacitor 8 (`app.brotar.jardim`), AdMob via `@capacitor-community/admob`
- Backend: Supabase (Postgres + Auth). **Todas as regras de pontos rodam no banco**, em funções `SECURITY DEFINER`. O app só pede, nunca escreve pontos.

## Rodar localmente

```bash
npm install
```

```bash
npm run dev
```

Sem `.env`, o app roda em **modo local** (sem login). Para usar contas, copie `.env.example` para `.env` e preencha.

## 1. Configurar o Supabase

1. Crie um projeto em <https://supabase.com>.
2. Abra **SQL Editor**, cole todo o conteúdo de `supabase/migrations/20261103000000_init.sql` e clique em **Run**.
3. Em **Authentication → Sign In / Providers → Email**: deixe **Confirm email** ligado e a senha com no mínimo 8 caracteres. Ligue **Leaked password protection** se o seu plano tiver.
4. Em **Authentication → URL Configuration**:
   - **Site URL:** `https://SEU-USUARIO.github.io/brotar/`
   - **Redirect URLs:** a mesma URL.
5. Em **Project Settings → API**, copie a **Project URL** e a chave **anon / publishable**.
   ⚠️ Nunca use a chave `service_role` no app.

## 2. Publicar no GitHub (site + APK automáticos)

1. Crie um repositório **vazio** chamado `brotar` e envie este código para ele.
2. Em **Settings → Pages → Source**, escolha **GitHub Actions**.
3. Em **Settings → Secrets and variables → Actions → Variables**, crie:

| Variável | Valor |
|---|---|
| `SUPABASE_URL` | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | chave anon/publishable |
| `SITE_URL` | `https://SEU-USUARIO.github.io/brotar/` |
| `ADMOB_APP_ID` | `ca-app-pub-XXXX~YYYY` (deixe vazio para usar o ID de teste) |
| `ADMOB_BANNER_ID` | ID do bloco de banner |
| `ADMOB_REWARDED_ID` | ID do bloco premiado |
| `ADMOB_TESTING` | `true` até o app ser aprovado, depois `false` |

4. Cada push na `main` roda os testes, publica o site e gera o **APK de debug** (aba **Actions → artifact `brotar-android`**).
5. **Para a Play Store** (APK/AAB assinados), gere uma chave **uma única vez** e guarde-a com muito cuidado. Se perder a chave, não consegue atualizar o app:

```bash
keytool -genkeypair -v -keystore brotar-release.jks -alias brotar -keyalg RSA -keysize 4096 -validity 10000
```

```bash
base64 -w0 brotar-release.jks
```

   Crie os **Secrets** `ANDROID_KEYSTORE_BASE64` (a saída do comando acima), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`brotar`) e `ANDROID_KEY_PASSWORD`. Com eles, o CI também gera `app-release.apk` e `app-release.aab`. Para publicar um release com os arquivos anexados, crie uma tag `v1.0.0`.

## 3. AdMob

O app já vem com:
- **Banner** na parte de baixo, escondido durante o jogo.
- **Anúncio premiado** ("Rega extra: +15 sementes"): até 3 por dia, com o limite garantido no servidor.
- **Formulário de consentimento (UMP)** para quem estiver na UE/Reino Unido.
- **IDs de teste do Google por padrão.** Nunca clique nos seus próprios anúncios reais.

Checklist no console do AdMob:
1. Crie o app (Android) e dois blocos: **Banner** e **Premiado**. Coloque os IDs nas variáveis acima.
2. **Muito importante para um app de sobriedade:** em **Bloqueio de controles → Categorias sensíveis**, bloqueie **Álcool**, **Jogos de azar** e **Drogas/remédios**. Também bloqueie as categorias gerais de bebidas.
3. Defina a classificação máxima de conteúdo dos anúncios como **T** (Teen) ou mais restrita.
4. Publique o `app-ads.txt` no site do desenvolvedor informado na Play Store.

## 4. Google Play: pontos de atenção

- **Política de privacidade:** `https://SEU-USUARIO.github.io/brotar/privacidade.html`. Preencha os campos entre colchetes antes de publicar.
- **Exclusão de conta:** existe dentro do app (Perfil → Excluir minha conta). Informe isso no formulário "Segurança dos dados".
- **Segurança dos dados:** declare e-mail, informações de saúde (sobriedade), ID de publicidade (AdMob) e dados de interação com o app.
- **Público:** 18+. Apps sobre álcool/drogas não devem ser direcionados a crianças.
- **Apps de saúde:** preencha a declaração de apps de saúde e deixe claro que o app **não substitui tratamento**.

## Testes

```bash
npm run test:all
```

| Suíte | O que cobre |
|---|---|
| `npm test` (31) | regras de pontos, motor do jogo (determinismo, anti speed-hack), backend local, helper anti-XSS |
| `npm run test:db` (27) | migração real no Postgres: **RLS**, privilégios, injeção de SQL, **gasto duplo em corrida**, limites diários, exclusão LGPD |
| `npm run test:e2e` (13) | fluxo completo no navegador (Pixel 7), **XSS**, **CSP**, dados locais adulterados, segredos no bundle |
| `npm run test:e2e:supabase` (3) | app em modo conta falando com a migração real (cadastro, login, compra, cliente adulterado, exclusão) |

Os testes de banco precisam de um Postgres em `DATABASE_URL` (padrão `postgresql://brotar_test:brotar_test@localhost:5432/brotar_test`).

Veja também [SECURITY.md](SECURITY.md).

---
O Brotar é uma ferramenta de apoio e **não substitui tratamento profissional**. Em crise: **CVV 188** · **SAMU 192**.
