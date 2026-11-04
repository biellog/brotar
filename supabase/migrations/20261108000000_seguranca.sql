-- =============================================================
-- Fica Sóbrio — revisão de segurança
-- Fecha brechas em que o celular podia mexer direto no banco.
-- =============================================================

-- ---------- 1. Perfil: o app só pode editar os campos "de cadastro" ----------
-- Antes: o celular podia fazer UPDATE perfis SET xp = 999999 direto pela API.
revoke insert, update, delete on public.perfis from authenticated, anon;
grant update (nome, motivo, gasto_diario, data_inicio, onboarding_ok, atualizado_em)
  on public.perfis to authenticated;

alter table public.perfis drop constraint if exists perfis_limites;
alter table public.perfis add constraint perfis_limites check (
  char_length(coalesce(nome, '')) <= 60
  and char_length(coalesce(motivo, '')) <= 300
  and gasto_diario between 0 and 100000
) not valid;

-- data de início nunca no futuro (dias "sóbrios" inventados)
create or replace function public._proteger_perfil()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if new.data_inicio > now() then
    new.data_inicio := now();
  end if;
  return new;
end;
$$;
drop trigger if exists proteger_perfil on public.perfis;
create trigger proteger_perfil before update on public.perfis
  for each row execute function public._proteger_perfil();

-- recaída mexe em colunas protegidas: passa a rodar com permissão própria
alter function public.registrar_recaida() security definer;

-- ---------- 2. SOS: histórico de fissuras só pelo servidor ----------
-- Antes: dava para apagar/editar as fissuras e "zerar" o limite de 3 por dia.
revoke insert, update, delete on public.fissuras from authenticated, anon;

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
    -- o limite agora é contado no xp_log, que ninguém consegue editar
    select count(*), max(criado_em) into hoje, ultimo
      from public.xp_log
     where user_id = u and motivo = 'sos' and criado_em >= public._inicio_do_dia();
    if hoje < 3 and (ultimo is null or ultimo < now() - interval '30 minutes') then
      premio := 50;
    end if;
  end if;

  insert into public.fissuras (user_id, intensidade, gatilho, superou, duracao_seg, xp_ganho)
  values (u, greatest(0, least(intensidade, 10)), left(gatilho, 40), superou,
          greatest(0, least(duracao_seg, 86400)), premio);

  if premio > 0 then
    insert into public.xp_log (user_id, motivo, qtd) values (u, 'sos', premio);
    update public.perfis set xp = xp + premio, atualizado_em = now() where id = u;
  end if;
  return premio;
end;
$$;

-- ---------- 3. XP: motivos desconhecidos caem todos no mesmo balde ----------
-- Antes: inventar motivos ("a", "b", "c"...) dava 800 XP para cada um (até o teto de 1.500).
create or replace function public.somar_xp(qtd integer, motivo text default 'outro')
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  m text := case when motivo in ('checkin', 'agua', 'recaida', 'jogo', 'movimento',
                                 'onboarding', 'conquista') then motivo else 'outro' end;
  pedido integer := greatest(0, least(qtd, 500));
  dado integer;
  total integer;
begin
  if u is null then return 0; end if;
  dado := least(
    pedido,
    greatest(0, public._limite_xp(m) - public._xp_hoje(u, m)),
    greatest(0, 1500 - public._xp_hoje(u))
  );
  if dado > 0 then
    insert into public.xp_log (user_id, motivo, qtd) values (u, m, dado);
    update public.perfis set xp = xp + dado, atualizado_em = now() where id = u;
  end if;
  select xp into total from public.perfis where id = u;
  return coalesce(total, 0);
end;
$$;

create or replace function public._limite_xp(m text)
returns integer
language sql immutable set search_path = ''
as $$
  select case m
    when 'checkin'    then 20
    when 'agua'       then 5
    when 'recaida'    then 10
    when 'jogo'       then 400
    when 'movimento'  then 300
    when 'onboarding' then 50
    when 'conquista'  then 800
    else 200
  end;
$$;

-- ---------- 4. Convites: limite contra contas falsas ----------
-- Quem indica ganha XP por no máximo 3 amigos por dia e 20 no total.
create or replace function public.usar_convite(codigo text)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  u uuid := auth.uid();
  dono uuid;
  ja_hoje integer;
  ja_total integer;
begin
  if u is null then return false; end if;
  select id into dono from public.perfis
   where codigo_convite = upper(trim(left(codigo, 12))) and id <> u;
  if dono is null then return false; end if;

  update public.perfis set convidado_por = dono where id = u and convidado_por is null;
  if not found then return false; end if;

  insert into public.xp_log (user_id, motivo, qtd) values (u, 'convite', 100);
  update public.perfis set xp = xp + 100 where id = u;

  select count(*) filter (where criado_em >= public._inicio_do_dia()), count(*)
    into ja_hoje, ja_total
    from public.xp_log where user_id = dono and motivo = 'convite_indicou';
  if ja_hoje < 3 and ja_total < 20 then
    insert into public.xp_log (user_id, motivo, qtd) values (dono, 'convite_indicou', 200);
    update public.perfis set xp = xp + 200 where id = dono;
  end if;
  return true;
end;
$$;

-- ---------- 5. Eventos: tamanho máximo e limite de 120 por minuto ----------
alter table public.eventos drop constraint if exists eventos_limites;
alter table public.eventos add constraint eventos_limites check (
  char_length(tipo) <= 60
  and pg_column_size(dados) <= 4096
  and pg_column_size(dispositivo) <= 2048
) not valid;

create or replace function public._limitar_eventos()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if (select count(*) from public.eventos
       where user_id = new.user_id and criado_em > now() - interval '1 minute') >= 120 then
    return null; -- descarta em silêncio (o app não depende disso)
  end if;
  return new;
end;
$$;
drop trigger if exists limitar_eventos on public.eventos;
create trigger limitar_eventos before insert on public.eventos
  for each row execute function public._limitar_eventos();

-- ---------- 6. Limites de valores nas outras tabelas ----------
revoke update, delete on public.partidas, public.conquistas from authenticated, anon;

alter table public.partidas drop constraint if exists partidas_limites;
alter table public.partidas add constraint partidas_limites check (
  pontos between 0 and 10000000 and duracao_seg between 0 and 86400 and char_length(jogo) <= 30
) not valid;

alter table public.atividades drop constraint if exists atividades_limites;
alter table public.atividades add constraint atividades_limites check (
  tipo in ('caminhada', 'corrida', 'alongamento', 'treino')
  and passos between 0 and 200000 and duracao_seg between 0 and 86400
) not valid;

alter table public.checkins drop constraint if exists checkins_limites;
alter table public.checkins add constraint checkins_limites check (
  char_length(coalesce(nota, '')) <= 2000
) not valid;

alter table public.conquistas drop constraint if exists conquistas_limites;
alter table public.conquistas add constraint conquistas_limites check (char_length(codigo) <= 30) not valid;

-- ---------- 7. Funções internas: ninguém chama direto pela API ----------
revoke execute on function public._proteger_perfil() from public, anon, authenticated;
revoke execute on function public._limitar_eventos() from public, anon, authenticated;
revoke execute on function public._limite_xp(text) from public, anon;
revoke execute on function public._inicio_do_dia() from public, anon;
revoke execute on function public.criar_perfil_novo_usuario() from public, anon, authenticated;
