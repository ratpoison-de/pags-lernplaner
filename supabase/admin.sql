-- PAGS Lernplaner: Lehrkraft-Funktionen
-- Nach schema.sql im SQL Editor ausführen.
-- Lehrkräfte werden in public.admins eingetragen. Nur sie dürfen die admin_*-Funktionen nutzen.
-- Die Funktionen zeigen nur Kontodaten (Benutzername, Datum der letzten Anmeldung),
-- niemals die Planer-Einträge der Schülerinnen und Schüler.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
-- keine Policies: Die Tabelle ist über die API weder lesbar noch änderbar.

create or replace function public.am_i_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.admins where user_id = auth.uid()); $$;

-- Liste aller Konten (ohne Planer-Inhalte)
create or replace function public.admin_list_users()
returns table (username text, created_at timestamptz, last_sign_in_at timestamptz, last_saved_at timestamptz, is_admin boolean, must_change boolean)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not exists (select 1 from public.admins a where a.user_id = auth.uid()) then
    raise exception 'Keine Berechtigung' using errcode = '42501';
  end if;
  return query
    select coalesce(u.raw_user_meta_data->>'username', split_part(u.email, '@', 1))::text,
           u.created_at, u.last_sign_in_at, p.updated_at,
           exists (select 1 from public.admins a2 where a2.user_id = u.id),
           coalesce((u.raw_user_meta_data->>'pw_reset')::boolean, false)
    from auth.users u
    left join public.planner p on p.user_id = u.id
    order by 1;
end; $$;

-- Passwort zurücksetzen: setzt ein neues Startpasswort, meldet alle Geräte ab
-- und markiert das Konto, damit beim nächsten Anmelden ein eigenes Passwort gewählt werden muss.
create or replace function public.admin_reset_password(p_username text, p_password text)
returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare v_id uuid;
begin
  if not exists (select 1 from public.admins a where a.user_id = auth.uid()) then
    raise exception 'Keine Berechtigung' using errcode = '42501';
  end if;
  if length(p_password) < 8 then
    raise exception 'Passwort zu kurz' using errcode = '22023';
  end if;
  select id into v_id from auth.users where email = lower(p_username) || '@lernplaner.pags-kuelsheim.de';
  if v_id is null then
    raise exception 'Konto nicht gefunden' using errcode = 'P0002';
  end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
         raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || '{"pw_reset": true}'::jsonb,
         updated_at = now()
   where id = v_id;
  delete from auth.sessions where user_id = v_id;
  delete from auth.refresh_tokens where user_id = v_id::text;
end; $$;

-- Konto löschen (mit allen Planer-Daten). Eigene und andere Lehrkraft-Konten sind geschützt.
create or replace function public.admin_delete_user(p_username text)
returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare v_id uuid;
begin
  if not exists (select 1 from public.admins a where a.user_id = auth.uid()) then
    raise exception 'Keine Berechtigung' using errcode = '42501';
  end if;
  select id into v_id from auth.users where email = lower(p_username) || '@lernplaner.pags-kuelsheim.de';
  if v_id is null then
    raise exception 'Konto nicht gefunden' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.admins a where a.user_id = v_id) then
    raise exception 'Lehrkraft-Konten können hier nicht gelöscht werden' using errcode = '42501';
  end if;
  delete from auth.users where id = v_id;
end; $$;

-- Nach dem Zurücksetzen: Markierung entfernen, sobald ein eigenes Passwort gesetzt wurde
create or replace function public.clear_pw_reset()
returns void
language sql volatile security definer set search_path = ''
as $$
  update auth.users set raw_user_meta_data = raw_user_meta_data - 'pw_reset' where id = auth.uid();
$$;

revoke all on function public.am_i_admin(), public.admin_list_users(), public.admin_reset_password(text, text),
                       public.admin_delete_user(text), public.clear_pw_reset() from public, anon;
grant execute on function public.am_i_admin(), public.admin_list_users(), public.admin_reset_password(text, text),
                          public.admin_delete_user(text), public.clear_pw_reset() to authenticated;

-- Lehrkraft freischalten (Benutzername anpassen):
-- insert into public.admins (user_id)
--   select id from auth.users where email = 'BENUTZERNAME@lernplaner.pags-kuelsheim.de';
