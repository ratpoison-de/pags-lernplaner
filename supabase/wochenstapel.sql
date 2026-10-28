-- Wochenstapel: Datenbank-Einrichtung (gleiche Konten wie der Lernplaner)
-- Im Supabase-Dashboard unter "SQL Editor" einfügen und einmal ausführen.
create table if not exists public.wochenstapel (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint wochenstapel_size check (pg_column_size(data) < 200000)
);
alter table public.wochenstapel enable row level security;
drop policy if exists "eigene Daten lesen"   on public.wochenstapel;
drop policy if exists "eigene Daten anlegen" on public.wochenstapel;
drop policy if exists "eigene Daten ändern"  on public.wochenstapel;
drop policy if exists "eigene Daten löschen" on public.wochenstapel;
create policy "eigene Daten lesen" on public.wochenstapel
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "eigene Daten anlegen" on public.wochenstapel
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "eigene Daten ändern" on public.wochenstapel
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "eigene Daten löschen" on public.wochenstapel
  for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.wochenstapel from anon;
