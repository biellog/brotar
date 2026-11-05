-- =============================================================
-- Império do Suco em grupo: o mesmo progresso salvo para todos os amigos.
-- O código (8 letras) funciona como a "chave" do império, igual a um link de
-- convite: quem tem o link entra e joga (também pelo site, sem login).
-- Tudo passa por funções do servidor; ninguém mexe nas tabelas direto.
-- =============================================================

create table if not exists public.imperios_grupo (
  codigo        text primary key check (codigo ~ '^[A-Z2-9]{8}$'),
  nome          text not null default 'Império' check (char_length(nome) between 1 and 30),
  estado        jsonb not null default '{}'::jsonb,
  criado_por    uuid references auth.users (id) on delete set null,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
alter table public.imperios_grupo enable row level security;
revoke all on public.imperios_grupo from anon, authenticated;

create table if not exists public.imperio_membros (
  codigo   text not null references public.imperios_grupo (codigo) on delete cascade,
  user_id  uuid not null references auth.users (id) on delete cascade,
  entrou_em timestamptz not null default now(),
  primary key (codigo, user_id)
);
alter table public.imperio_membros enable row level security;
revoke all on public.imperio_membros from anon, authenticated;
grant select on public.imperio_membros to authenticated;
drop policy if exists "ver meus impérios" on public.imperio_membros;
create policy "ver meus impérios" on public.imperio_membros
  for select to authenticated using (user_id = auth.uid());

-- ---------- criar (só quem tem conta no app; até 10 por pessoa) ----------
create or replace function public.criar_imperio_grupo(p_nome text default 'Império')
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  letras constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  c text;
  nome_limpo text := left(coalesce(nullif(btrim(regexp_replace(p_nome, '[\x00-\x1F<>]', '', 'g')), ''), 'Império'), 30);
begin
  if u is null then raise exception 'precisa entrar na conta'; end if;
  if (select count(*) from public.imperios_grupo where criado_por = u) >= 10 then
    raise exception 'limite de impérios';
  end if;
  loop
    c := '';
    for k in 1..8 loop
      c := c || substr(letras, 1 + floor(random() * length(letras))::int, 1);
    end loop;
    exit when not exists (select 1 from public.imperios_grupo where codigo = c);
  end loop;
  insert into public.imperios_grupo (codigo, nome, criado_por) values (c, nome_limpo, u);
  insert into public.imperio_membros (codigo, user_id) values (c, u);
  return c;
end;
$$;

-- ---------- abrir pelo código (app ou site) ----------
create or replace function public.abrir_imperio_grupo(p_codigo text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  c text := upper(btrim(coalesce(p_codigo, '')));
  r record;
begin
  if c !~ '^[A-Z2-9]{8}$' then return null; end if;
  select nome, estado into r from public.imperios_grupo where codigo = c;
  if not found then return null; end if;
  if u is not null and (select count(*) from public.imperio_membros where user_id = u) < 30 then
    insert into public.imperio_membros (codigo, user_id) values (c, u) on conflict do nothing;
  end if;
  return jsonb_build_object('nome', r.nome, 'estado', r.estado);
end;
$$;

-- ---------- salvar (quem está rodando o jogo salva a cada ~15 s) ----------
create or replace function public.salvar_imperio_grupo(p_codigo text, p_estado jsonb)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  c text := upper(btrim(coalesce(p_codigo, '')));
begin
  if c !~ '^[A-Z2-9]{8}$' or jsonb_typeof(p_estado) <> 'object' or octet_length(p_estado::text) > 16000 then
    return false;
  end if;
  update public.imperios_grupo
     set estado = p_estado, atualizado_em = now()
   where codigo = c and atualizado_em < now() - interval '3 seconds';
  return found;
end;
$$;

-- ---------- lista "meus impérios em grupo" ----------
create or replace function public.meus_imperios_grupo()
returns table (codigo text, nome text, atualizado_em timestamptz, membros integer)
language sql stable security definer set search_path = ''
as $$
  select i.codigo, i.nome, i.atualizado_em,
         (select count(*)::int from public.imperio_membros m2 where m2.codigo = i.codigo)
    from public.imperios_grupo i
    join public.imperio_membros m on m.codigo = i.codigo
   where m.user_id = auth.uid()
   order by i.atualizado_em desc
   limit 30;
$$;

revoke execute on function public.criar_imperio_grupo(text) from public, anon;
revoke execute on function public.meus_imperios_grupo() from public, anon;
revoke execute on function public.abrir_imperio_grupo(text) from public;
revoke execute on function public.salvar_imperio_grupo(text, jsonb) from public;
grant execute on function public.criar_imperio_grupo(text) to authenticated;
grant execute on function public.meus_imperios_grupo() to authenticated;
grant execute on function public.abrir_imperio_grupo(text) to anon, authenticated;
grant execute on function public.salvar_imperio_grupo(text, jsonb) to anon, authenticated;
