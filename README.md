# 🌱 Fica Sóbrio — o jogo de ficar sóbrio

> **Cada dia sóbrio é um nível a mais.**

App Android (Flutter) que transforma a sobriedade num jogo: contador de dias, XP e níveis,
missões diárias, conquistas, botão **SOS Fissura** com respiração guiada e o mini-game
**Desvia da Garrafa** para atravessar a vontade. Login e todos os dados ficam no **Supabase**.
O APK é compilado **pelo GitHub** — você não precisa instalar nada no computador.

---

## ✨ O que tem no app

| Recurso | O que faz |
|---|---|
| ⏱️ Contador | Dias, horas e minutos sóbrio + dinheiro economizado |
| ⚡ XP e níveis | Semente → Broto → Raiz Firme → … → **Lenda Sóbria** |
| 🎯 Missões diárias | Check-in (+20 XP), jogar, beber água (+5 XP) |
| 🏅 15 conquistas | 24h, 7 dias, 30, 90, 365 dias, recordes no jogo, fissuras vencidas… |
| 🎮 Desvia da Garrafa | Arraste para fugir de 🍺🍷🥃🚬 e pegar 💧⭐❤️ (10 pontos = 1 XP) |
| 🆘 SOS Fissura | Registra intensidade e gatilho, respiração 4-4-6, cronômetro, CVV 188, CAPS (136), AA/NA, SAMU 192 |
| 📓 Check-in diário | Humor, nível de vontade, diário |
| 💚 Recaída sem culpa | Recomeça só o contador; XP, nível e conquistas continuam |
| 🤝 Indique e ganhe | Código de convite: quem indica ganha 200 XP, quem entra 100 XP |
| 📤 Compartilhar | Conquistas, recordes e dias sóbrio viram posts com o link do app |
| 🔒 LGPD | Termo de consentimento + botão "Excluir minha conta" |

### O que é salvo no Supabase
Tudo que a pessoa faz **dentro do app** fica gravado na conta dela:

- `perfis` — nome, data de início, motivo, gasto diário, XP, recaídas, código de convite
- `checkins` — humor, vontade, se ficou sóbrio, diário
- `fissuras` — cada SOS: intensidade, gatilho, se venceu, duração
- `partidas` — pontos e duração de cada partida
- `conquistas` — medalhas desbloqueadas
- `eventos` — **histórico de cada ação** (login, telas abertas, check-ins, partidas, compartilhamentos,
  ligações de ajuda…) junto com os **dados do aparelho** (marca, modelo, versão do Android, fuso)

Cada pessoa só enxerga os próprios dados (Row Level Security).

---

## 🚀 Passo a passo (sem SQL Editor, sem instalar nada)

### 1. Crie o projeto no Supabase
1. Entre em <https://supabase.com> → **New project**. Anote a **senha do banco** que você escolher.
2. Em **Project Settings → API**, copie:
   - **Project URL** → vai virar o secret `SUPABASE_URL`
   - **anon / publishable key** → vai virar o secret `SUPABASE_ANON_KEY`
3. O **Project ref** é o código no meio da URL (`https://`**`abcdxyz`**`.supabase.co`) → `SUPABASE_PROJECT_REF`
4. Em <https://supabase.com/dashboard/account/tokens> clique **Generate new token** → `SUPABASE_ACCESS_TOKEN`

### 2. Repositório
O código já está em <https://github.com/biellog/fica-sobrio> (branch `main`).

### 3. Cadastre os secrets
No repositório: **Settings → Secrets and variables → Actions**

| Nome | Onde cadastrar | Valor |
|---|---|---|
| `SUPABASE_URL` | Secret **ou** Variable | Project URL (pode ter `/rest/v1/` no fim, o workflow limpa) |
| `SUPABASE_ANON_KEY` | Secret **ou** Variable | anon / publishable key |
| `SUPABASE_ACCESS_TOKEN` | Secret | token pessoal do Supabase |
| `SUPABASE_DB_PASSWORD` | Secret | senha do banco |
| `SUPABASE_PROJECT_REF` | Secret (opcional) | se faltar, é tirado da `SUPABASE_URL` |
| `ANDROID_KEYSTORE_BASE64` | Secret | chave de assinatura em base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Secret | senha da chave |
| `ANDROID_KEY_ALIAS` | Secret | apelido da chave |
| `ANDROID_KEY_PASSWORD` | Secret (opcional) | se faltar, usa a senha da chave |

> A chave de assinatura garante que cada versão nova **atualize** o app no celular em vez de pedir
> para desinstalar. Guarde uma cópia em lugar seguro: sem ela não dá para publicar atualizações na Play Store.

### 4. Crie o banco (substitui o SQL Editor)
Aba **Actions → 🗄️ Criar/atualizar banco Supabase → Run workflow**.
Em ~1 minuto todas as tabelas, regras de segurança e funções estarão criadas.
(As migrações antigas do Brotar continuam na pasta só para o histórico do banco bater; as tabelas
do Fica Sóbrio têm nomes diferentes e não conflitam.)
Sempre que algo mudar em `supabase/migrations`, ele roda sozinho.

### 5. Gere o APK
Aba **Actions → 📱 Gerar APK → Run workflow** (ou qualquer push na `main`).
Em ~6 minutos o `FicaSobrio.apk` aparece em **Releases** (lado direito da página do repositório).
Abra esse link no celular, baixe e instale.

### 6. (Recomendado) Ajustes no Supabase pelo painel
- **Authentication → URL Configuration**: coloque o link do seu site/landing page em *Site URL*
  (é para onde o link de confirmação de e-mail leva).
- **Authentication → Providers → Email**: se quiser que a pessoa entre sem confirmar e-mail,
  desative *Confirm email* (mais conversão; menos verificação).

---

## 🧱 Estrutura

```
lib/
  main.dart                 # inicia Supabase e decide login/onboarding/início
  config.dart               # nome, slogan, chaves via --dart-define
  data/repo.dart            # todas as chamadas ao Supabase + registro de eventos
  logic/progresso.dart      # níveis, conquistas, frases, dinheiro
  screens/                  # login, onboarding, início, jogo, SOS, perfil, check-in
supabase/migrations/        # estrutura do banco (aplicada pelo GitHub Actions)
.github/workflows/apk.yml   # compila e publica o APK
.github/workflows/supabase.yml  # cria/atualiza o banco
```

## ⚠️ Aviso importante
O Fica Sóbrio é uma ferramenta de apoio e **não substitui tratamento**. Parar de beber de forma
abrupta após uso intenso pode causar abstinência grave — procure um médico ou o CAPS AD
(Disque Saúde 136). Em sofrimento emocional, ligue **188 (CVV)**. Emergência: **192**.
