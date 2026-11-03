-- Brotar — esquema inicial
-- Princípio de segurança: o cliente NUNCA escreve pontos, itens ou datas diretamente.
-- Toda mutação passa por funções SECURITY DEFINER que validam auth.uid() e as regras do jogo.
-- As tabelas têm RLS ligado e só permitem SELECT das próprias linhas.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- tabelas
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Jardineiro' check (char_length(display_name) between 1 and 40),
  motivation   text not null default '' check (char_length(motivation) <= 280),
  sober_since  timestamptz,
  tz           text not null default 'America/Sao_Paulo' check (char_length(tz) <= 64),
  theme        text not null default 'dia',
  best_streak_days integer not null default 0 check (best_streak_days >= 0),
  created_at   timestamptz not null default now()
);

create table public.shop_items (
  id       text primary key check (id ~ '^[a-z0-9_]{1,40}$'),
  name     text not null,
  category text not null check (category in ('planta', 'decoracao', 'tema')),
  price    integer not null check (price >= 0),
  icon     text not null,
  sort     integer not null default 0
);

create table public.user_items (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  item_id    text not null references public.shop_items (id),
  bought_at  timestamptz not null default now(),
  primary key (user_id, item_id)
);

create table public.points_ledger (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  amount     integer not null check (amount <> 0),
  reason     text not null check (reason in ('checkin', 'marco', 'jogo', 'anuncio', 'compra', 'boas_vindas')),
  ref        text,
  created_at timestamptz not null default now()
);
create index points_ledger_user_idx on public.points_ledger (user_id, created_at desc);

create table public.daily_actions (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day     date not null,
  kind    text not null check (kind in ('checkin', 'jogo', 'anuncio')),
  count   integer not null default 0 check (count >= 0),
  primary key (user_id, day, kind)
);

create table public.milestones_claimed (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  milestone  integer not null,
  claimed_at timestamptz not null default now(),
  primary key (user_id, milestone)
);

create table public.relapses (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  streak_days integer not null,
  at          timestamptz not null default now()
);

-- ---------------------------------------------------------------- RLS
alter table public.profiles           enable row level security;
alter table public.shop_items         enable row level security;
alter table public.user_items         enable row level security;
alter table public.points_ledger      enable row level security;
alter table public.daily_actions      enable row level security;
alter table public.milestones_claimed enable row level security;
alter table public.relapses           enable row level security;

create policy "perfil próprio"   on public.profiles           for select to authenticated using (id = (select auth.uid()));
create policy "loja pública"     on public.shop_items         for select to anon, authenticated using (true);
create policy "itens próprios"   on public.user_items         for select to authenticated using (user_id = (select auth.uid()));
create policy "extrato próprio"  on public.points_ledger      for select to authenticated using (user_id = (select auth.uid()));
create policy "ações próprias"   on public.daily_actions      for select to authenticated using (user_id = (select auth.uid()));
create policy "marcos próprios"  on public.milestones_claimed for select to authenticated using (user_id = (select auth.uid()));
create policy "recaídas próprias" on public.relapses          for select to authenticated using (user_id = (select auth.uid()));

-- Privilégios mínimos: somente leitura. Nada de insert/update/delete direto.
revoke all on all tables in schema public from anon, authenticated;
grant select on public.shop_items to anon, authenticated;
grant select on public.profiles, public.user_items, public.points_ledger,
                public.daily_actions, public.milestones_claimed, public.relapses to authenticated;

-- ---------------------------------------------------------------- regras (espelhadas em src/lib/rules.js)
create or replace function public.milestone_bonus(m integer)
returns integer language sql immutable set search_path = '' as $$
  select case m
    when 1 then 20 when 3 then 30 when 7 then 70 when 14 then 100 when 30 then 250
    when 60 then 400 when 90 then 600 when 180 then 1000 when 365 then 2000 else 0 end
$$;

create or replace function public.checkin_points(days integer)
returns integer language sql immutable set search_path = '' as $$
  select 10 + least(greatest(days, 0), 20)
$$;

create or replace function public.game_points(score integer)
returns integer language sql immutable set search_path = '' as $$
  select least(greatest(score, 0) / 50, 20)
$$;

-- constantes de limite diário
create or replace function public.daily_limit(kind text)
returns integer language sql immutable set search_path = '' as $$
  select case kind when 'checkin' then 1 when 'jogo' then 3 when 'anuncio' then 3 else 0 end
$$;

-- ---------------------------------------------------------------- helpers internos
create or replace function public._uid()
returns uuid language plpgsql stable set search_path = '' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'não autenticado' using errcode = '28000'; end if;
  return u;
end $$;

-- trava a linha do perfil para serializar operações de pontos (evita gasto duplo em corrida)
create or replace function public._lock_profile(u uuid)
returns public.profiles language plpgsql set search_path = '' as $$
declare p public.profiles;
begin
  select * into p from public.profiles where id = u for update;
  if not found then raise exception 'perfil não encontrado' using errcode = 'P0002'; end if;
  return p;
end $$;

create or replace function public._today(p public.profiles)
returns date language sql stable set search_path = '' as $$
  select (now() at time zone p.tz)::date
$$;

create or replace function public._balance(u uuid)
returns integer language sql stable set search_path = '' as $$
  select coalesce(sum(amount), 0)::integer from public.points_ledger where user_id = u
$$;

create or replace function public._days(p public.profiles)
returns integer language sql stable set search_path = '' as $$
  select case when p.sober_since is null then 0
              else greatest(floor(extract(epoch from (now() - p.sober_since)) / 86400), 0)::integer end
$$;

-- incrementa contador diário respeitando o limite; retorna false se estourou
create or replace function public._bump(u uuid, d date, k text)
returns boolean language plpgsql set search_path = '' as $$
declare c integer;
begin
  insert into public.daily_actions (user_id, day, kind, count) values (u, d, k, 0)
  on conflict do nothing;
  update public.daily_actions set count = count + 1
   where user_id = u and day = d and kind = k and count < public.daily_limit(k)
  returning count into c;
  return c is not null;
end $$;

-- ---------------------------------------------------------------- criação automática de perfil
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  insert into public.points_ledger (user_id, amount, reason) values (new.id, 100, 'boas_vindas');
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------- API (RPC)
create or replace function public.get_state()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare u uuid := public._uid(); p public.profiles; d date;
begin
  select * into p from public.profiles where id = u;
  if not found then raise exception 'perfil não encontrado' using errcode = 'P0002'; end if;
  d := public._today(p);
  return jsonb_build_object(
    'profile', jsonb_build_object('display_name', p.display_name, 'motivation', p.motivation,
                                  'sober_since', p.sober_since, 'tz', p.tz, 'theme', p.theme,
                                  'best_streak_days', p.best_streak_days),
    'server_now', now(),
    'balance', public._balance(u),
    'items', coalesce((select jsonb_agg(item_id order by bought_at) from public.user_items where user_id = u), '[]'::jsonb),
    'milestones', coalesce((select jsonb_agg(milestone order by milestone) from public.milestones_claimed where user_id = u), '[]'::jsonb),
    'today', coalesce((select jsonb_object_agg(kind, count) from public.daily_actions where user_id = u and day = d), '{}'::jsonb)
  );
end $$;

-- define o início da jornada (só uma vez; depois apenas via reset_sobriety)
create or replace function public.start_journey(since timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid(); p public.profiles;
begin
  p := public._lock_profile(u);
  if p.sober_since is not null then raise exception 'jornada já iniciada' using errcode = '22023'; end if;
  if since is null or since > now() + interval '5 minutes' or since < now() - interval '20 years' then
    raise exception 'data inválida' using errcode = '22023';
  end if;
  update public.profiles set sober_since = least(since, now()) where id = u;
  return public.get_state();
end $$;

create or replace function public.update_profile(new_name text, new_motivation text, new_tz text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid();
begin
  perform public._lock_profile(u);
  new_name := btrim(coalesce(new_name, ''));
  if char_length(new_name) not between 1 and 40 then raise exception 'nome inválido' using errcode = '22023'; end if;
  if char_length(coalesce(new_motivation, '')) > 280 then raise exception 'motivação muito longa' using errcode = '22023'; end if;
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new_tz) then
    raise exception 'fuso inválido' using errcode = '22023';
  end if;
  update public.profiles set display_name = new_name, motivation = coalesce(new_motivation, ''), tz = new_tz where id = u;
  return public.get_state();
end $$;

create or replace function public.daily_checkin()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid(); p public.profiles; days integer; pts integer; m integer; bonus integer := 0;
begin
  p := public._lock_profile(u);
  if p.sober_since is null then raise exception 'inicie a jornada primeiro' using errcode = '22023'; end if;
  if not public._bump(u, public._today(p), 'checkin') then
    raise exception 'check-in de hoje já feito' using errcode = 'P0001';
  end if;
  days := public._days(p);
  pts := public.checkin_points(days);
  insert into public.points_ledger (user_id, amount, reason) values (u, pts, 'checkin');
  foreach m in array array[1,3,7,14,30,60,90,180,365] loop
    if days >= m and not exists (select 1 from public.milestones_claimed where user_id = u and milestone = m) then
      insert into public.milestones_claimed (user_id, milestone) values (u, m);
      insert into public.points_ledger (user_id, amount, reason, ref) values (u, public.milestone_bonus(m), 'marco', m::text);
      bonus := bonus + public.milestone_bonus(m);
    end if;
  end loop;
  update public.profiles set best_streak_days = greatest(best_streak_days, days) where id = u;
  return jsonb_build_object('points', pts, 'bonus', bonus, 'state', public.get_state());
end $$;

create or replace function public.submit_game_score(score integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid(); p public.profiles; pts integer;
begin
  p := public._lock_profile(u);
  if score is null or score < 0 or score > 100000 then raise exception 'pontuação inválida' using errcode = '22023'; end if;
  pts := public.game_points(score);
  if pts > 0 and public._bump(u, public._today(p), 'jogo') then
    insert into public.points_ledger (user_id, amount, reason) values (u, pts, 'jogo');
  else
    pts := 0;
  end if;
  return jsonb_build_object('points', pts, 'state', public.get_state());
end $$;

create or replace function public.claim_ad_reward()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid(); p public.profiles;
begin
  p := public._lock_profile(u);
  if not public._bump(u, public._today(p), 'anuncio') then
    raise exception 'limite de recompensas por anúncio atingido hoje' using errcode = 'P0001';
  end if;
  insert into public.points_ledger (user_id, amount, reason) values (u, 15, 'anuncio');
  return jsonb_build_object('points', 15, 'state', public.get_state());
end $$;

create or replace function public.buy_item(item text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid(); it public.shop_items;
begin
  perform public._lock_profile(u);
  select * into it from public.shop_items where id = item;
  if not found then raise exception 'item inexistente' using errcode = '22023'; end if;
  if exists (select 1 from public.user_items where user_id = u and item_id = item) then
    raise exception 'você já tem este item' using errcode = 'P0001';
  end if;
  if public._balance(u) < it.price then raise exception 'pontos insuficientes' using errcode = 'P0001'; end if;
  insert into public.user_items (user_id, item_id) values (u, item);
  if it.price > 0 then
    insert into public.points_ledger (user_id, amount, reason, ref) values (u, -it.price, 'compra', item);
  end if;
  return public.get_state();
end $$;

create or replace function public.equip_theme(theme_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid();
begin
  perform public._lock_profile(u);
  if theme_id <> 'dia' and not exists (
       select 1 from public.user_items ui join public.shop_items s on s.id = ui.item_id
        where ui.user_id = u and ui.item_id = theme_id and s.category = 'tema') then
    raise exception 'tema não adquirido' using errcode = 'P0001';
  end if;
  update public.profiles set theme = theme_id where id = u;
  return public.get_state();
end $$;

-- recaída: sem punição de pontos/itens, só recomeça a contagem
create or replace function public.reset_sobriety()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid(); p public.profiles; days integer;
begin
  p := public._lock_profile(u);
  days := public._days(p);
  insert into public.relapses (user_id, streak_days) values (u, days);
  update public.profiles set sober_since = now(), best_streak_days = greatest(best_streak_days, days) where id = u;
  return public.get_state();
end $$;

-- LGPD / política do Google Play: o usuário pode apagar a conta e todos os dados
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare u uuid := public._uid();
begin
  delete from auth.users where id = u;
end $$;

-- ---------------------------------------------------------------- permissões de execução
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function
  public.get_state(), public.start_journey(timestamptz), public.update_profile(text, text, text),
  public.daily_checkin(), public.submit_game_score(integer), public.claim_ad_reward(),
  public.buy_item(text), public.equip_theme(text), public.reset_sobriety(), public.delete_my_account()
to authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

-- ---------------------------------------------------------------- catálogo da loja
insert into public.shop_items (id, name, category, price, icon, sort) values
  ('girassol',   'Girassol',          'planta',    60,  '🌻', 10),
  ('tulipa',     'Tulipa',            'planta',    80,  '🌷', 11),
  ('cacto',      'Cacto resistente',  'planta',   100,  '🌵', 12),
  ('rosa',       'Rosa',              'planta',   140,  '🌹', 13),
  ('cerejeira',  'Cerejeira',         'planta',   250,  '🌸', 14),
  ('bonsai',     'Bonsai sábio',      'planta',   400,  '🪴', 15),
  ('ipe',        'Ipê amarelo',       'planta',   700,  '🌳', 16),
  ('borboleta',  'Borboletas',        'decoracao', 90,  '🦋', 20),
  ('passaro',    'Passarinho',        'decoracao',120,  '🐦', 21),
  ('cogumelo',   'Cogumelos',         'decoracao', 70,  '🍄', 22),
  ('lago',       'Laguinho',          'decoracao',300,  '🪷', 23),
  ('abelha',     'Abelhas amigas',    'decoracao',150,  '🐝', 24),
  ('arco_iris',  'Arco-íris',         'decoracao',900,  '🌈', 25),
  ('noite',      'Tema Noite estrelada','tema',   200,  '🌙', 30),
  ('outono',     'Tema Outono',       'tema',     200,  '🍂', 31),
  ('aurora',     'Tema Aurora',       'tema',     500,  '🌌', 32);
