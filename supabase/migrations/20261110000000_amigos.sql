-- =============================================================
-- Amigos: adicionar pelo código (o mesmo código de convite do perfil),
-- aceitar/recusar pedidos e ver a lista. Tudo por funções do servidor.
-- Privacidade: o amigo só vê o primeiro nome e o nível (XP), nunca dias
-- sóbrio, recaídas, diário ou SOS.
-- =============================================================

create table if not exists public.amizades (
  de        uuid not null references auth.users (id) on delete cascade,
  para      uuid not null references auth.users (id) on delete cascade,
  status    text not null default 'pendente' check (status in ('pendente', 'aceito')),
  criado_em timestamptz not null default now(),
  primary key (de, para),
  check (de <> para)
);
create index if not exists amizades_para on public.amizades (para);
alter table public.amizades enable row level security;
revoke all on public.amizades from anon, authenticated;

-- ---------- pedir amizade pelo código ----------
create or replace function public.pedir_amizade(p_codigo text)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  outro uuid;
  c text := upper(btrim(coalesce(p_codigo, '')));
begin
  if u is null then return 'sem_login'; end if;
  if c !~ '^[A-Z0-9]{4,12}$' then return 'nao_encontrado'; end if;
  select id into outro from public.perfis where codigo_convite = c;
  if outro is null then return 'nao_encontrado'; end if;
  if outro = u then return 'voce_mesmo'; end if;
  if exists (select 1 from public.amizades
              where ((de = u and para = outro) or (de = outro and para = u)) and status = 'aceito') then
    return 'ja_amigos';
  end if;
  -- a outra pessoa já tinha me pedido: vira amizade na hora
  if exists (select 1 from public.amizades where de = outro and para = u) then
    update public.amizades set status = 'aceito' where de = outro and para = u;
    return 'aceito';
  end if;
  if exists (select 1 from public.amizades where de = u and para = outro) then return 'enviado'; end if;
  if (select count(*) from public.amizades where de = u or para = u) >= 200 then return 'limite'; end if;
  if (select count(*) from public.amizades where de = u and criado_em > now() - interval '1 day') >= 30 then
    return 'limite';
  end if;
  insert into public.amizades (de, para) values (u, outro);
  return 'enviado';
end;
$$;

-- ---------- aceitar ou recusar um pedido recebido ----------
create or replace function public.responder_amizade(p_de uuid, p_aceitar boolean)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
begin
  if u is null then return false; end if;
  if p_aceitar then
    update public.amizades set status = 'aceito' where de = p_de and para = u and status = 'pendente';
  else
    delete from public.amizades where de = p_de and para = u and status = 'pendente';
  end if;
  return found;
end;
$$;

-- ---------- desfazer amizade (ou cancelar pedido enviado) ----------
create or replace function public.remover_amizade(p_outro uuid)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
begin
  if u is null then return false; end if;
  delete from public.amizades where (de = u and para = p_outro) or (de = p_outro and para = u);
  return found;
end;
$$;

-- ---------- minha lista (amigos e pedidos) ----------
create or replace function public.meus_amigos()
returns table (id uuid, nome text, xp integer, status text, enviado_por_mim boolean)
language sql stable security definer set search_path = ''
as $$
  select p.id,
         coalesce(nullif(split_part(btrim(coalesce(p.nome, '')), ' ', 1), ''), 'Amigo'),
         p.xp,
         a.status,
         a.de = auth.uid()
    from public.amizades a
    join public.perfis p on p.id = case when a.de = auth.uid() then a.para else a.de end
   where auth.uid() is not null and (a.de = auth.uid() or a.para = auth.uid())
   order by a.status, p.nome
   limit 300;
$$;

-- ---------- convites para jogar (só entre amigos; só quem recebe consegue ler) ----------
create table if not exists public.convites_jogo (
  id        bigint generated always as identity primary key,
  de        uuid not null references auth.users (id) on delete cascade,
  para      uuid not null references auth.users (id) on delete cascade,
  de_nome   text not null check (char_length(de_nome) <= 30),
  jogo      text not null check (jogo in ('brilha', 'suco')),
  codigo    text not null check (codigo ~ '^[A-Z0-9]{4,12}$'),
  detalhe   text not null default '' check (char_length(detalhe) <= 30),
  criado_em timestamptz not null default now()
);
create index if not exists convites_jogo_para on public.convites_jogo (para, criado_em);
alter table public.convites_jogo enable row level security;
revoke all on public.convites_jogo from anon, authenticated;
grant select on public.convites_jogo to authenticated;
drop policy if exists "ver convites para mim" on public.convites_jogo;
create policy "ver convites para mim" on public.convites_jogo
  for select to authenticated using (para = auth.uid());

-- entrega ao vivo para o app de quem recebe (Realtime respeita a regra acima)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'convites_jogo') then
    alter publication supabase_realtime add table public.convites_jogo;
  end if;
end;
$$;

create or replace function public.convidar_amigo(p_para uuid, p_jogo text, p_codigo text, p_detalhe text default '')
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  meu_nome text;
begin
  if u is null or p_para is null or p_para = u then return false; end if;
  if not exists (select 1 from public.amizades
                  where ((de = u and para = p_para) or (de = p_para and para = u)) and status = 'aceito') then
    return false;
  end if;
  if (select count(*) from public.convites_jogo where de = u and criado_em > now() - interval '1 minute') >= 6 then
    return false;
  end if;
  select coalesce(nullif(split_part(btrim(coalesce(nome, '')), ' ', 1), ''), 'Um amigo') into meu_nome
    from public.perfis where id = u;
  delete from public.convites_jogo where criado_em < now() - interval '1 day';
  insert into public.convites_jogo (de, para, de_nome, jogo, codigo, detalhe)
  values (u, p_para, left(coalesce(meu_nome, 'Um amigo'), 30), p_jogo, upper(btrim(p_codigo)),
          left(regexp_replace(coalesce(p_detalhe, ''), '[\x00-\x1F<>]', '', 'g'), 30));
  return true;
exception when check_violation then
  return false;
end;
$$;

revoke execute on function public.convidar_amigo(uuid, text, text, text) from public, anon;
grant execute on function public.convidar_amigo(uuid, text, text, text) to authenticated;

revoke execute on function public.pedir_amizade(text) from public, anon;
revoke execute on function public.responder_amizade(uuid, boolean) from public, anon;
revoke execute on function public.remover_amizade(uuid) from public, anon;
revoke execute on function public.meus_amigos() from public, anon;
grant execute on function public.pedir_amizade(text) to authenticated;
grant execute on function public.responder_amizade(uuid, boolean) to authenticated;
grant execute on function public.remover_amizade(uuid) to authenticated;
grant execute on function public.meus_amigos() to authenticated;
