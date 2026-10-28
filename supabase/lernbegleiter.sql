-- Lernbegleiter (Lehrkräfte): Datenbank-Einrichtung (gleiche Konten wie der Lernplaner)
-- Im Supabase-Dashboard unter "SQL Editor" einfügen und einmal ausführen.
create table if not exists public.lernbegleiter (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint lernbegleiter_size check (pg_column_size(data) < 500000)
);
alter table public.lernbegleiter enable row level security;
drop policy if exists "eigene Daten lesen"   on public.lernbegleiter;
drop policy if exists "eigene Daten anlegen" on public.lernbegleiter;
drop policy if exists "eigene Daten ändern"  on public.lernbegleiter;
drop policy if exists "eigene Daten löschen" on public.lernbegleiter;
create policy "eigene Daten lesen" on public.lernbegleiter
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "eigene Daten anlegen" on public.lernbegleiter
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "eigene Daten ändern" on public.lernbegleiter
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "eigene Daten löschen" on public.lernbegleiter
  for delete to authenticated using ((select auth.uid()) = user_id);
revoke all on public.lernbegleiter from anon;
