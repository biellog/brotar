-- =============================================================
-- Fica Sóbrio — vários jogos + aviso de atualização do app
-- =============================================================

-- Qual jogo gerou cada partida (recorde separado por jogo)
alter table public.partidas
  add column if not exists jogo text not null default 'tempestade';

create index if not exists partidas_jogo_idx
  on public.partidas (user_id, jogo, pontos desc);

-- Versões publicadas do app (preenchida automaticamente pelo GitHub Actions)
create table if not exists public.versoes_app (
  versao_codigo integer primary key,
  versao_nome   text not null,
  url           text not null,
  notas         text not null default '',
  obrigatoria   boolean not null default false,
  criado_em     timestamptz not null default now()
);

alter table public.versoes_app enable row level security;

-- Qualquer pessoa (até antes do login) pode ver qual é a versão mais nova
drop policy if exists "versoes_publicas" on public.versoes_app;
create policy "versoes_publicas" on public.versoes_app
  for select to anon, authenticated using (true);

grant select on public.versoes_app to anon, authenticated;
