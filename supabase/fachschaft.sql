-- Fachschafts-App (z. B. Fachschaft Deutsch): Datenbank-Einrichtung
-- Gleiche Konten wie der PAGS Lernplaner. Im Supabase-Dashboard unter "SQL Editor" einmal ausführen.
-- Anders als Lernplaner/Wochenstapel sind diese Daten GEMEINSAM: Alle Mitglieder einer Fachschaft
-- sehen und bearbeiten dieselben Einträge. Mitglied wird man mit dem Fachschafts-Code.

create extension if not exists pgcrypto with schema extensions;

-- Fachschaften und ihre Beitritts-Codes (nur als Hash gespeichert, über die API nicht lesbar)
create table if not exists public.fs_codes (
  fachschaft text primary key check (fachschaft ~ '^[a-z]{2,20}$'),
  code_hash  text not null,
  updated_at timestamptz not null default now()
);
alter table public.fs_codes enable row level security;

-- Mitglieder
create table if not exists public.fs_mitglieder (
  fachschaft text not null references public.fs_codes(fachschaft) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null check (char_length(name) between 2 and 60),
  rolle      text not null default 'mitglied' check (rolle in ('mitglied','leitung')),
  joined_at  timestamptz not null default now(),
  primary key (fachschaft, user_id)
);
alter table public.fs_mitglieder enable row level security;

-- Einträge (Termine, Aufgaben, Material, Lektüren, Planung, Protokolle, Vereinbarungen, Pinnwand, Einstellungen)
create table if not exists public.fs_eintraege (
  id          uuid primary key default gen_random_uuid(),
  fachschaft  text not null references public.fs_codes(fachschaft) on delete cascade,
  typ         text not null check (typ in ('termin','aufgabe','material','lektuere','plan','protokoll','vereinbarung','pinnwand','einstellung')),
  data        jsonb not null default '{}'::jsonb,
  created_by  uuid references auth.users(id) on delete set null,
  created_name text,
  updated_name text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint fs_eintraege_size check (pg_column_size(data) < 60000)
);
create index if not exists fs_eintraege_fs_idx on public.fs_eintraege (fachschaft, updated_at desc);
alter table public.fs_eintraege enable row level security;

-- Hilfsfunktionen
create or replace function public.fs_ist_mitglied(p_fachschaft text)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.fs_mitglieder m where m.fachschaft = p_fachschaft and m.user_id = auth.uid()); $$;

create or replace function public.fs_ist_leitung(p_fachschaft text)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.fs_mitglieder m where m.fachschaft = p_fachschaft and m.user_id = auth.uid() and m.rolle = 'leitung'); $$;

-- Regeln: Mitglieder
drop policy if exists "Mitglieder sehen ihre Fachschaft" on public.fs_mitglieder;
create policy "Mitglieder sehen ihre Fachschaft" on public.fs_mitglieder
  for select to authenticated using (public.fs_ist_mitglied(fachschaft));
drop policy if exists "selbst austreten" on public.fs_mitglieder;
create policy "selbst austreten" on public.fs_mitglieder
  for delete to authenticated using (user_id = (select auth.uid()) and rolle = 'mitglied');

-- Regeln: Einträge
drop policy if exists "fs lesen" on public.fs_eintraege;
drop policy if exists "fs anlegen" on public.fs_eintraege;
drop policy if exists "fs aendern" on public.fs_eintraege;
drop policy if exists "fs loeschen" on public.fs_eintraege;
create policy "fs lesen" on public.fs_eintraege
  for select to authenticated using (public.fs_ist_mitglied(fachschaft));
create policy "fs anlegen" on public.fs_eintraege
  for insert to authenticated with check (public.fs_ist_mitglied(fachschaft) and created_by = (select auth.uid()));
create policy "fs aendern" on public.fs_eintraege
  for update to authenticated using (public.fs_ist_mitglied(fachschaft)) with check (public.fs_ist_mitglied(fachschaft));
create policy "fs loeschen" on public.fs_eintraege
  for delete to authenticated using (public.fs_ist_mitglied(fachschaft));
revoke all on public.fs_eintraege, public.fs_mitglieder, public.fs_codes from anon;

-- Ersteller- und Änderungsname automatisch setzen (nicht vom Browser fälschbar)
create or replace function public.fs_eintrag_stempel()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_name text;
begin
  select m.name into v_name from public.fs_mitglieder m where m.fachschaft = new.fachschaft and m.user_id = auth.uid();
  if tg_op = 'INSERT' then
    new.created_by := auth.uid(); new.created_name := v_name; new.created_at := now();
  else
    new.created_by := old.created_by; new.created_name := old.created_name; new.created_at := old.created_at;
    new.fachschaft := old.fachschaft; new.typ := old.typ;
  end if;
  new.updated_name := v_name; new.updated_at := now();
  return new;
end; $$;
drop trigger if exists fs_eintrag_stempel on public.fs_eintraege;
create trigger fs_eintrag_stempel before insert or update on public.fs_eintraege
  for each row execute function public.fs_eintrag_stempel();

-- Beitreten mit Code (max. 10 Fehlversuche pro Stunde und Konto)
create table if not exists public.fs_fehlversuche (
  user_id uuid not null references auth.users(id) on delete cascade,
  at timestamptz not null default now()
);
alter table public.fs_fehlversuche enable row level security;

create or replace function public.fs_beitreten(p_fachschaft text, p_code text, p_name text)
returns text language plpgsql volatile security definer set search_path = ''
as $$
declare v_hash text;
begin
  if auth.uid() is null then raise exception 'Nicht angemeldet' using errcode = '42501'; end if;
  if (select count(*) from public.fs_fehlversuche f where f.user_id = auth.uid() and f.at > now() - interval '1 hour') >= 10 then
    raise exception 'Zu viele Versuche' using errcode = '54000';
  end if;
  if char_length(trim(coalesce(p_name,''))) < 2 then raise exception 'Name fehlt' using errcode = '22023'; end if;
  select c.code_hash into v_hash from public.fs_codes c where c.fachschaft = p_fachschaft;
  if v_hash is null or v_hash <> extensions.crypt(lower(trim(p_code)), v_hash) then
    insert into public.fs_fehlversuche (user_id) values (auth.uid());
    return 'falsch';
  end if;
  insert into public.fs_mitglieder (fachschaft, user_id, name)
  values (p_fachschaft, auth.uid(), left(trim(p_name), 60))
  on conflict (fachschaft, user_id) do update set name = excluded.name;
  return 'ok';
end; $$;

-- eigenen Anzeigenamen ändern
create or replace function public.fs_name_aendern(p_fachschaft text, p_name text)
returns void language plpgsql volatile security definer set search_path = ''
as $$
begin
  if char_length(trim(coalesce(p_name,''))) < 2 then raise exception 'Name fehlt' using errcode = '22023'; end if;
  update public.fs_mitglieder set name = left(trim(p_name), 60) where fachschaft = p_fachschaft and user_id = auth.uid();
end; $$;

-- Leitung: Code ändern, Rolle setzen (Entfernen über die Regel oben)
create or replace function public.fs_code_setzen(p_fachschaft text, p_code text)
returns void language plpgsql volatile security definer set search_path = ''
as $$
begin
  if not public.fs_ist_leitung(p_fachschaft) then raise exception 'Keine Berechtigung' using errcode = '42501'; end if;
  if char_length(trim(coalesce(p_code,''))) < 6 then raise exception 'Code zu kurz' using errcode = '22023'; end if;
  update public.fs_codes set code_hash = extensions.crypt(lower(trim(p_code)), extensions.gen_salt('bf')), updated_at = now()
   where fachschaft = p_fachschaft;
end; $$;

create or replace function public.fs_rolle_setzen(p_fachschaft text, p_user uuid, p_rolle text)
returns void language plpgsql volatile security definer set search_path = ''
as $$
begin
  if not public.fs_ist_leitung(p_fachschaft) then raise exception 'Keine Berechtigung' using errcode = '42501'; end if;
  if p_rolle not in ('mitglied','leitung') then raise exception 'Rolle unbekannt' using errcode = '22023'; end if;
  if p_rolle = 'mitglied' and (select count(*) from public.fs_mitglieder where fachschaft = p_fachschaft and rolle = 'leitung' and user_id <> p_user) = 0 then
    raise exception 'Mindestens eine Leitung nötig' using errcode = '22023';
  end if;
  update public.fs_mitglieder set rolle = p_rolle where fachschaft = p_fachschaft and user_id = p_user;
end; $$;

drop policy if exists "Leitung entfernt Mitglieder" on public.fs_mitglieder;
create policy "Leitung entfernt Mitglieder" on public.fs_mitglieder
  for delete to authenticated using (public.fs_ist_leitung(fachschaft) and user_id <> (select auth.uid()));

revoke all on function public.fs_beitreten(text,text,text), public.fs_name_aendern(text,text), public.fs_code_setzen(text,text),
  public.fs_rolle_setzen(text,uuid,text), public.fs_ist_mitglied(text), public.fs_ist_leitung(text)
  from public, anon;
grant execute on function public.fs_beitreten(text,text,text), public.fs_name_aendern(text,text), public.fs_code_setzen(text,text),
  public.fs_rolle_setzen(text,uuid,text), public.fs_ist_mitglied(text), public.fs_ist_leitung(text)
  to authenticated;
revoke all on function public.fs_eintrag_stempel() from public, anon, authenticated;

-- Fachschaft Deutsch anlegen (Code danach in der App unter "Fachschaft" ändern):
-- insert into public.fs_codes (fachschaft, code_hash) values ('deutsch', extensions.crypt('startcode', extensions.gen_salt('bf')));
-- Erste Leitung eintragen:
-- insert into public.fs_mitglieder (fachschaft, user_id, name, rolle)
-- select 'deutsch', id, 'Name', 'leitung' from auth.users where email = 'BENUTZERNAME@lernplaner.pags-kuelsheim.de';
