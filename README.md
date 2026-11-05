# 🌱 Fica Sóbrio — o jogo de ficar sóbrio

> **Cada dia sóbrio é um nível a mais.**

App Android (Flutter) que transforma a sobriedade num jogo: contador de dias, XP e níveis,
missões diárias, conquistas, botão **SOS Fissura** com respiração guiada e o mini-game
**3 jogos com música** para atravessar a vontade, e aviso de atualização com notificação. Login e todos os dados ficam no **Supabase**.
O APK é compilado **pelo GitHub** — você não precisa instalar nada no computador.

---

## ✨ O que tem no app

| Recurso | O que faz |
|---|---|
| ⏱️ Contador | Dias, horas e minutos sóbrio + dinheiro economizado |
| 💸 Quanto o vício custa | Painel na tela inicial: gasto por dia, semana ou mês → quanto junta em 1 mês, 5 meses, 1 ano, 5 anos, 10 anos e 10 anos rendendo, e o que dá para comprar |
| ⚡ XP e níveis | Semente → Broto → Raiz Firme → … → **Lenda Sóbria** |
| 🎯 Missões diárias | Check-in (+20 XP), jogar, beber água (+5 XP) |
| 🏅 15 conquistas | 24h, 7 dias, 30, 90, 365 dias, recordes no jogo, fissuras vencidas… |
| 🎮 9 jogos | **Online:** 🌟 Brilha Junto (arena de vagalumes em tempo real pelo Supabase Realtime: luzes sincronizadas, x2 voando perto de alguém, estrelas cadentes, rodadas de 2 min sem perdedor, emotes, "Achar partidas" com as salas abertas ao vivo, salas públicas ou privadas com código, link que abre a sala no app ou no navegador (versão web em `/jogar/`) e bots 🤖 controlados por um "anfitrião" para todos verem os mesmos). **Simulador:** 🧃 Império do Suco 3D (mundo aberto isométrico: ande pela praça, pegue os copos nas barracas do fundo, venda no balcão, fique em cima das placas para abrir e melhorar barracas, 23 missões em sequência que dão dinheiro e ⭐ pontos de habilidade (agilidade, força, carisma, barista, marketing, liderança), e a **Gerência**: sente no computador para comprar boosts (turbo, produção x2, promoção), melhorias da empresa (logo, máquina de gelo, uniformes, mesas, delivery, franquia), mochila, tênis e contratar ajudantes que vendem sozinhos, inclusive com o app fechado). **Desafios:** Desvia da Tempestade, Bolhas da Calma, Memória Zen. **Relaxantes (sem perder):** Plástico Bolha, Jardim Mágico (plantar, regar, colher com combos, flor dourada e céu que vira noite), Mandala Mágica e Aquário da Calma, os 3 últimos liberados com atividades de Movimento. Sem bebida nem cigarro na tela |
| 🚶 Movimento | Caminhada (1.500 passos) e corrida leve (3.000 passos) com contador de passos do celular, alongamento e treino leve guiados. Cada atividade dá +30 XP e libera jogos: 1 → Jardim Mágico, 3 → Mandala, 5 → Aquário |
| 🛡️ XP justo | O servidor limita o XP por dia (check-in, água, recaída, jogos, movimento) e o "venci a fissura" do SOS só vale com 1min30 surfando a onda, até 3x por dia, com 30 min de intervalo |
| 🔒 Segurança | O app só edita campos de cadastro do perfil (XP, recaídas e convites só pelo servidor), histórico do SOS imutável, limites de tamanho e de eventos por minuto, convites com teto contra contas falsas, atualização só do repositório oficial e conferência do APK |
| 🎵 Som | Música original ("Serenidade", composta para o app em `tool/compor_musica.py`) em loop no app inteiro (pausa quando o app sai da tela) e efeitos nos jogos: erro na Tempestade, carta virando na Memória, bolha certa e errada nas Bolhas. Volume da música e dos efeitos ajustáveis em **Perfil → Som e música** ou no botão 🎵 |
| 🚀 Atualizações | O app consulta a tabela `versoes_app` no Supabase: mostra aviso, botão **Atualizar** e notificação (verificação a cada ~4 h, mesmo com o app fechado) |
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
Se o seu Supabase ainda tiver as tabelas do app de teste antigo (Brotar), elas são apagadas
automaticamente nessa mesma execução.
Sempre que algo mudar em `supabase/migrations`, ele roda sozinho.

### 5. Gere o APK
Aba **Actions → 📱 Gerar APK → Run workflow** (ou qualquer push na `main`).
Em ~6 minutos o `FicaSobrio.apk` aparece em **Releases** (lado direito da página do repositório).
Abra esse link no celular, baixe e instale.

### 6. Como funcionam as atualizações
A cada push na `main`, o workflow do APK publica a versão em **Releases** e registra na tabela
`versoes_app` do Supabase (usando o `SUPABASE_ACCESS_TOKEN`). Os celulares com o app:
- mostram um aviso e o botão **Atualizar** ao abrir o app (e em **Perfil → Verificar atualizações**);
- recebem uma **notificação** (o app verifica sozinho a cada ~4 horas).

Para obrigar todo mundo a atualizar (sem botão "Depois"), crie a variable `ATUALIZACAO_OBRIGATORIA` = `true`.
**Importante:** cadastre a chave de assinatura (`ANDROID_KEYSTORE_BASE64` e cia.), senão o Android
não instala a versão nova por cima da antiga.

### 7. (Recomendado) Ajustes no Supabase pelo painel
- **Authentication → URL Configuration**: coloque o link do seu site/landing page em *Site URL*
  (é para onde o link de confirmação de e-mail leva).
- **Authentication → Providers → Email**: se quiser que a pessoa entre sem confirmar e-mail,
  desative *Confirm email* (mais conversão; menos verificação).

---

## 🌐 Site
O site de divulgação fica em **https://biellog.github.io/fica-sobrio/**. Ele tem botão de download
direto do APK, o jogo jogável no navegador, uma calculadora de gastos, FAQ e a política de
privacidade (exigida pela Play Store). Ele é publicado sozinho pelo workflow **🌐 Publicar site**
sempre que algo muda na pasta `site/`.

## 🧱 Estrutura

```
lib/
  main.dart                 # inicia Supabase e decide login/onboarding/início
  config.dart               # nome, slogan, chaves via --dart-define
  data/repo.dart            # todas as chamadas ao Supabase + registro de eventos
  logic/progresso.dart      # níveis, conquistas, frases, dinheiro
  games/                    # os 3 jogos (Tempestade, Bolhas, Memória)
  data/musica.dart          # música de fundo (assets/musica/)
  data/atualizacao.dart     # verifica versão nova no Supabase
  data/notificacoes.dart    # notificação de atualização + verificação em segundo plano
  screens/                  # login, onboarding, início, jogo, SOS, perfil, check-in
supabase/migrations/        # estrutura do banco (aplicada pelo GitHub Actions)
.github/workflows/apk.yml   # compila e publica o APK
.github/workflows/supabase.yml  # cria/atualiza o banco
site/                       # site de divulgação (GitHub Pages)
.github/workflows/site.yml  # publica o site
```

## ⚠️ Aviso importante
O Fica Sóbrio é uma ferramenta de apoio e **não substitui tratamento**. Parar de beber de forma
abrupta após uso intenso pode causar abstinência grave — procure um médico ou o CAPS AD
(Disque Saúde 136). Em sofrimento emocional, ligue **188 (CVV)**. Emergência: **192**.
