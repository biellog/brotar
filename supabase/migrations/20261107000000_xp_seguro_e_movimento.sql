-- =============================================================
-- Fica Sóbrio — XP à prova de trapaça + atividades de movimento
-- =============================================================

-- ---------- Registro de todo XP ganho (para aplicar limites) ----------
create table if not exists public.xp_log (
  id        bigint generated always as identity primary key,
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  motivo    text not null default 'outro',
  qtd       integer not null,
  criado_em timestamptz not null default now()
);
create index if not exists xp_log_user_idx on public.xp_log (user_id, criado_em desc);
alter table public.xp_log enable row level security;
drop policy if exists "xp_log_ler" on public.xp_log;
create policy "xp_log_ler" on public.xp_log
  for select to authenticated using (user_id = (select auth.uid()));
grant select on public.xp_log to authenticated;
-- (ninguém grava direto: só as funções abaixo)

-- Início do dia no horário de Brasília (o limite diário vira à meia-noite daqui)
create or replace function public._inicio_do_dia()
returns timestamptz
language sql stable set search_path = ''
as $$ select (date_trunc('day', now() at time zone 'America/Sao_Paulo')) at time zone 'America/Sao_Paulo'; $$;

-- Quanto de XP a pessoa já ganhou hoje (total ou por motivo)
create or replace function public._xp_hoje(u uuid, m text default null)
returns integer
language sql stable security definer set search_path = ''
as $$
  select coalesce(sum(qtd), 0)::int from public.xp_log
   where user_id = u and criado_em >= public._inicio_do_dia()
     and (m is null or motivo = m);
$$;

-- Limites diários por motivo (o resto cai no limite geral)
create or replace function public._limite_xp(m text)
returns integer
language sql immutable set search_path = ''
as $$
  select case m
    when 'checkin'   then 20
    when 'agua'      then 5
    when 'recaida'   then 10
    when 'jogo'      then 400
    when 'movimento' then 300
    when 'onboarding' then 50
    else 800
  end;
$$;

-- Substitui o somar_xp antigo: agora com motivo e limite por dia.
-- Chamadas antigas somar_xp(qtd) continuam funcionando (motivo = 'outro').
drop function if exists public.somar_xp(integer);
create or replace function public.somar_xp(qtd integer, motivo text default 'outro')
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  pedido integer := greatest(0, least(qtd, 500));
  dado integer;
  total integer;
begin
  if u is null then return 0; end if;
  dado := least(
    pedido,
    greatest(0, public._limite_xp(motivo) - public._xp_hoje(u, motivo)),
    greatest(0, 1500 - public._xp_hoje(u))          -- teto geral do dia
  );
  if dado > 0 then
    insert into public.xp_log (user_id, motivo, qtd) values (u, motivo, dado);
    update public.perfis set xp = xp + dado, atualizado_em = now() where id = u;
  end if;
  select xp into total from public.perfis where id = u;
  return coalesce(total, 0);
end;
$$;

-- ---------- SOS: o +50 XP de "venci a fissura" agora tem regras ----------
alter table public.fissuras add column if not exists xp_ganho integer not null default 0;

-- Registra o momento de fissura e devolve quanto XP foi dado (0 ou 50).
-- Regras: ficar pelo menos 90 s surfando a onda, no máximo 3 vezes por dia
-- e com 30 minutos de intervalo entre uma recompensa e outra.
create or replace function public.vencer_fissura(
  intensidade integer, gatilho text, superou boolean, duracao_seg integer
)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  premio integer := 0;
  hoje integer;
  ultimo timestamptz;
begin
  if u is null then return 0; end if;
  if superou and duracao_seg >= 90 then
    select count(*), max(criado_em) into hoje, ultimo
      from public.fissuras
     where user_id = u and xp_ganho > 0 and criado_em >= public._inicio_do_dia();
    if hoje < 3 and (ultimo is null or ultimo < now() - interval '30 minutes') then
      premio := 50;
    end if;
  end if;

  insert into public.fissuras (user_id, intensidade, gatilho, superou, duracao_seg, xp_ganho)
  values (u, greatest(0, least(intensidade, 10)), gatilho, superou, greatest(0, duracao_seg), premio);

  if premio > 0 then
    insert into public.xp_log (user_id, motivo, qtd) values (u, 'sos', premio);
    update public.perfis set xp = xp + premio, atualizado_em = now() where id = u;
  end if;
  return premio;
end;
$$;

-- ---------- Atividades de movimento (caminhada, corrida, alongamento, treino) ----------
create table if not exists public.atividades (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tipo        text not null,
  duracao_seg integer not null default 0,
  passos      integer not null default 0,
  criado_em   timestamptz not null default now()
);
create index if not exists atividades_user_idx on public.atividades (user_id, criado_em desc);
alter table public.atividades enable row level security;
drop policy if exists "atividades_proprias" on public.atividades;
create policy "atividades_proprias" on public.atividades
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
grant select, insert on public.atividades to authenticated;

revoke execute on function public.somar_xp(integer, text) from public, anon;
revoke execute on function public.vencer_fissura(integer, text, boolean, integer) from public, anon;
revoke execute on function public._xp_hoje(uuid, text) from public, anon, authenticated;
grant  execute on function public.somar_xp(integer, text) to authenticated;
grant  execute on function public.vencer_fissura(integer, text, boolean, integer) to authenticated;
