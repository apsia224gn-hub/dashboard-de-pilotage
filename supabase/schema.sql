-- ============================================================
-- APSIA — Dashboard de pilotage · schéma Supabase
-- ============================================================
-- À exécuter UNE SEULE FOIS dans Supabase :
--   Dashboard → SQL Editor → New query → coller ce fichier → Run
--
-- Le dashboard utilise Supabase Auth (e-mail + mot de passe).
-- Chaque compte est lié à l'un des trois profils contractuels APSIA.
-- ============================================================

-- 1) Profils associés aux comptes Supabase Auth
create table if not exists public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  actor      text not null unique check (actor in ('MD','MK','MH')),
  full_name  text not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "authenticated read own profile" on public.profiles;
create policy "authenticated read own profile" on public.profiles
  for select to authenticated using (user_id = auth.uid());

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  selected_actor text := new.raw_user_meta_data ->> 'actor_code';
  selected_name text;
begin
  selected_name := case selected_actor
    when 'MD' then 'Mohamed DIAWARA'
    when 'MK' then 'Mamadou Cellou KANTÉ'
    when 'MH' then 'Mohamed HADY'
    else null
  end;

  if selected_name is null then
    raise exception 'Profil APSIA invalide';
  end if;

  insert into public.profiles (user_id,actor,full_name)
  values (new.id,selected_actor,selected_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2) Table des statuts (une ligne par action : S1, T1, J1, ...)
create table if not exists public.task_status (
  task_id    text primary key,
  status     text not null default 'todo'
             check (status in ('todo','wip','done','block')),
  updated_at timestamptz not null default now()
);

-- 3) Accès réservé aux comptes authentifiés
alter table public.task_status enable row level security;

drop policy if exists "anon read"   on public.task_status;
drop policy if exists "anon insert" on public.task_status;
drop policy if exists "anon update" on public.task_status;
drop policy if exists "anon delete" on public.task_status;
drop policy if exists "team read status"   on public.task_status;
drop policy if exists "team insert status" on public.task_status;
drop policy if exists "team update status" on public.task_status;
drop policy if exists "team delete status" on public.task_status;

create policy "team read status"   on public.task_status for select to authenticated using (true);
create policy "team insert status" on public.task_status for insert to authenticated with check (true);
create policy "team update status" on public.task_status for update to authenticated using (true) with check (true);
create policy "team delete status" on public.task_status for delete to authenticated using (true);

-- 4) Temps réel : diffuser les changements de cette table
--    (ignore l'erreur si la table y est déjà)
do $$
begin
  alter publication supabase_realtime add table public.task_status;
exception when duplicate_object then
  null;
end $$;


-- ============================================================
-- 5) Catégories ajoutées depuis le dashboard (en plus de celles du code)
-- ============================================================
create table if not exists public.categories (
  id         text primary key,
  title      text not null,
  color      text not null default '#3b82f6',
  subtitle   text default '',
  position   bigint not null default 0,
  created_at timestamptz not null default now()
);

alter table public.categories enable row level security;

drop policy if exists "anon read cat"   on public.categories;
drop policy if exists "anon insert cat" on public.categories;
drop policy if exists "anon update cat" on public.categories;
drop policy if exists "anon delete cat" on public.categories;
drop policy if exists "team read cat"   on public.categories;
drop policy if exists "team insert cat" on public.categories;
drop policy if exists "team update cat" on public.categories;
drop policy if exists "team delete cat" on public.categories;

create policy "team read cat"   on public.categories for select to authenticated using (true);
create policy "team insert cat" on public.categories for insert to authenticated with check (true);
create policy "team update cat" on public.categories for update to authenticated using (true) with check (true);
create policy "team delete cat" on public.categories for delete to authenticated using (true);

do $$
begin
  alter publication supabase_realtime add table public.categories;
exception when duplicate_object then
  null;
end $$;


-- ============================================================
-- 6) Actions ajoutées depuis le dashboard (en plus de celles du code)
-- ============================================================
create table if not exists public.tasks (
  id          text primary key,
  category_id text not null,                 -- id de catégorie (code : SEC/TEC/... ou ajoutée : c_...)
  title       text not null,
  subtitle    text default '',
  owner       text not null default 'ALL'    check (owner in ('MD','MK','MH','ALL')),
  due_date    date,
  priority    text not null default 'norm'   check (priority in ('crit','haut','norm')),
  position    bigint not null default 0,
  created_at  timestamptz not null default now()
);

alter table public.tasks enable row level security;

drop policy if exists "anon read task"   on public.tasks;
drop policy if exists "anon insert task" on public.tasks;
drop policy if exists "anon update task" on public.tasks;
drop policy if exists "anon delete task" on public.tasks;
drop policy if exists "team read task"   on public.tasks;
drop policy if exists "team insert task" on public.tasks;
drop policy if exists "team update task" on public.tasks;
drop policy if exists "team delete task" on public.tasks;

create policy "team read task"   on public.tasks for select to authenticated using (true);
create policy "team insert task" on public.tasks for insert to authenticated with check (true);
create policy "team update task" on public.tasks for update to authenticated using (true) with check (true);
create policy "team delete task" on public.tasks for delete to authenticated using (true);

do $$
begin
  alter publication supabase_realtime add table public.tasks;
exception when duplicate_object then
  null;
end $$;


-- ============================================================
-- 7) Journal d'activité partagé (qui a fait quoi)
-- ============================================================
create table if not exists public.activity_log (
  id           bigint generated always as identity primary key,
  actor        text not null check (actor in ('MD','MK','MH')),
  action       text not null,
  entity_type  text not null default 'system',
  entity_id    text,
  entity_title text default '',
  from_value   text,
  to_value     text,
  created_at   timestamptz not null default now()
);

create index if not exists activity_log_created_at_idx
  on public.activity_log (created_at desc);

alter table public.activity_log enable row level security;

drop policy if exists "anon read activity"   on public.activity_log;
drop policy if exists "anon insert activity" on public.activity_log;
drop policy if exists "team read activity"   on public.activity_log;
drop policy if exists "team insert activity" on public.activity_log;

create policy "team read activity" on public.activity_log
  for select to authenticated using (true);
create policy "team insert activity" on public.activity_log
  for insert to authenticated with check (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.actor = activity_log.actor
    )
  );

-- Le journal est volontairement append-only : aucune politique client
-- d'UPDATE ou de DELETE, afin de préserver les événements enregistrés.
do $$
begin
  alter publication supabase_realtime add table public.activity_log;
exception when duplicate_object then
  null;
end $$;
