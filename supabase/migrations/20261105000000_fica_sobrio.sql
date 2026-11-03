-- =============================================================
-- Fica Sóbrio — estrutura do banco
-- Aplicado automaticamente pelo GitHub Actions (supabase db push).
-- Você NÃO precisa abrir o SQL Editor do Supabase.
-- =============================================================

-- ---------- PERFIS ----------
create table if not exists public.perfis (
  id                    uuid primary key references auth.users(id) on delete cascade,
  nome                  text,
  data_inicio           timestamptz not null default now(),
  motivo                text,
  gasto_diario          numeric(10,2) not null default 0,
  xp                    integer not null default 0,
  recaidas              integer not null default 0,
  melhor_sequencia_dias integer not null default 0,
  codigo_convite        text unique default upper(substr(md5(gen_random_uuid()::text), 1, 6)),
  convidado_por         uuid references public.perfis(id) on delete set null,
  consentimento_lgpd    timestamptz,
  onboarding_ok         boolean not null default false,
  criado_em             timestamptz not null default now(),
  atualizado_em         timestamptz not null default now()
);

-- ---------- CHECK-INS DIÁRIOS ----------
create table if not exists public.checkins (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data      date not null default current_date,
  humor     smallint not null check (humor between 1 and 5),
  fissura   smallint not null default 0 check (fissura between 0 and 10),
  sobrio    boolean not null default true,
  nota      text,
  criado_em timestamptz not null default now(),
  unique (user_id, data)
);

-- ---------- MOMENTOS DE FISSURA (botão SOS) ----------
create table if not exists public.fissuras (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  intensidade  smallint not null default 5 check (intensidade between 0 and 10),
  gatilho      text,
  superou      boolean not null default true,
  duracao_seg  integer not null default 0,
  criado_em    timestamptz not null default now()
);

-- ---------- PARTIDAS DO JOGO ----------
create table if not exists public.partidas (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  pontos       integer not null default 0,
  duracao_seg  integer not null default 0,
  criado_em    timestamptz not null default now()
);

-- ---------- CONQUISTAS ----------
create table if not exists public.conquistas (
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  codigo    text not null,
  criado_em timestamptz not null default now(),
  primary key (user_id, codigo)
);

-- ---------- EVENTOS (tudo que a pessoa faz no app + dados do aparelho) ----------
create table if not exists public.eventos (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tipo        text not null,
  dados       jsonb not null default '{}'::jsonb,
  dispositivo jsonb not null default '{}'::jsonb,
  criado_em   timestamptz not null default now()
);

create index if not exists checkins_user_idx   on public.checkins (user_id, data desc);
create index if not exists fissuras_user_idx   on public.fissuras (user_id, criado_em desc);
create index if not exists partidas_user_idx   on public.partidas (user_id, pontos desc);
create index if not exists eventos_user_idx    on public.eventos  (user_id, criado_em desc);
create index if not exists eventos_tipo_idx    on public.eventos  (tipo, criado_em desc);

-- ---------- SEGURANÇA (RLS): cada pessoa só vê os próprios dados ----------
alter table public.perfis     enable row level security;
alter table public.checkins   enable row level security;
alter table public.fissuras   enable row level security;
alter table public.partidas   enable row level security;
alter table public.conquistas enable row level security;
alter table public.eventos    enable row level security;

create policy "perfil_proprio" on public.perfis
  for all to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "checkins_proprios" on public.checkins
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "fissuras_proprias" on public.fissuras
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "partidas_proprias" on public.partidas
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "conquistas_proprias" on public.conquistas
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- eventos: a pessoa registra e lê, mas não apaga/edita o histórico pelo app
create policy "eventos_inserir" on public.eventos
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "eventos_ler" on public.eventos
  for select to authenticated using (user_id = (select auth.uid()));

grant select, insert, update, delete on
  public.perfis, public.checkins, public.fissuras, public.partidas, public.conquistas
  to authenticated;
grant select, insert on public.eventos to authenticated;

-- ---------- Cria o perfil automaticamente no cadastro ----------
create or replace function public.criar_perfil_novo_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.perfis (id, nome, consentimento_lgpd)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nome', split_part(new.email, '@', 1)),
    case when (new.raw_user_meta_data ->> 'consentimento') = 'true' then now() end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario
  after insert on auth.users
  for each row execute function public.criar_perfil_novo_usuario();

-- ---------- Somar XP de forma atômica ----------
create or replace function public.somar_xp(qtd integer)
returns integer
language sql
security invoker
set search_path = ''
as $$
  update public.perfis
     set xp = xp + greatest(0, least(qtd, 500)),
         atualizado_em = now()
   where id = auth.uid()
  returning xp;
$$;

-- ---------- Programa de indicação (marketing): quem indica ganha 200 XP, quem entra ganha 100 ----------
create or replace function public.usar_convite(codigo text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  dono uuid;
begin
  select id into dono
    from public.perfis
   where codigo_convite = upper(trim(codigo))
     and id <> auth.uid();

  if dono is null then
    return false;
  end if;

  update public.perfis
     set convidado_por = dono
   where id = auth.uid() and convidado_por is null;

  if not found then
    return false;
  end if;

  update public.perfis set xp = xp + 200 where id = dono;
  update public.perfis set xp = xp + 100 where id = auth.uid();
  return true;
end;
$$;

-- ---------- Recaída: recomeça a contagem sem perder XP nem conquistas ----------
create or replace function public.registrar_recaida()
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  dias integer;
begin
  select floor(extract(epoch from (now() - data_inicio)) / 86400)::int
    into dias
    from public.perfis where id = auth.uid();

  update public.perfis
     set melhor_sequencia_dias = greatest(melhor_sequencia_dias, coalesce(dias, 0)),
         recaidas = recaidas + 1,
         data_inicio = now(),
         atualizado_em = now()
   where id = auth.uid();
end;
$$;

-- ---------- Excluir conta (exigência da LGPD e do Google Play) ----------
create or replace function public.excluir_minha_conta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.somar_xp(integer)      from public, anon;
revoke execute on function public.usar_convite(text)     from public, anon;
revoke execute on function public.registrar_recaida()    from public, anon;
revoke execute on function public.excluir_minha_conta()  from public, anon;
grant  execute on function public.somar_xp(integer)      to authenticated;
grant  execute on function public.usar_convite(text)     to authenticated;
grant  execute on function public.registrar_recaida()    to authenticated;
grant  execute on function public.excluir_minha_conta()  to authenticated;
