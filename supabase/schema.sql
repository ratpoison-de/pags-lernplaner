-- PAGS Lernplaner: Datenbank-Einrichtung
-- Im Supabase-Dashboard unter "SQL Editor" einfügen und einmal ausführen.

-- Eine Zeile pro Nutzer mit dem kompletten Planer-Stand
create table if not exists public.planner (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint planner_size check (pg_column_size(data) < 1000000)
);

-- Jede Person sieht und ändert nur ihre eigenen Daten
alter table public.planner enable row level security;

drop policy if exists "eigene Daten lesen"   on public.planner;
drop policy if exists "eigene Daten anlegen" on public.planner;
drop policy if exists "eigene Daten ändern"  on public.planner;
drop policy if exists "eigene Daten löschen" on public.planner;

create policy "eigene Daten lesen" on public.planner
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "eigene Daten anlegen" on public.planner
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "eigene Daten ändern" on public.planner
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "eigene Daten löschen" on public.planner
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Konto selbst löschen (Knopf "Konto löschen" in der App).
-- Löscht den eigenen Zugang; die Planer-Daten werden dabei automatisch mitgelöscht.
create or replace function public.delete_me()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_me() from public, anon;
grant execute on function public.delete_me() to authenticated;
