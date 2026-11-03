-- Versões publicadas do app — usadas para avisar o usuário que há atualização.
-- Escrita: somente o CI (chave service_role, que ignora RLS). Leitura: qualquer pessoa (inclusive sem conta).

create table public.app_releases (
  id           bigint generated always as identity primary key,
  platform     text not null default 'android' check (platform in ('android')),
  version_code integer not null check (version_code > 0),
  version_name text not null check (char_length(version_name) between 1 and 40),
  notes        text not null default '' check (char_length(notes) <= 1000),
  url          text not null check (url ~ '^https://[^\s]+$' and char_length(url) <= 500),
  mandatory    boolean not null default false,
  created_at   timestamptz not null default now(),
  unique (platform, version_code)
);

alter table public.app_releases enable row level security;
create policy "versões públicas" on public.app_releases for select to anon, authenticated using (true);

revoke all on public.app_releases from anon, authenticated;
grant select on public.app_releases to anon, authenticated;

-- Realtime: o app aberto recebe o aviso na hora em que a versão é publicada.
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.app_releases;
  end if;
end $$;
