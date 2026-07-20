-- ============================================================
-- APSIA — Dashboard de pilotage · schéma Supabase
-- ============================================================
-- À exécuter UNE SEULE FOIS dans Supabase :
--   Dashboard → SQL Editor → New query → coller ce fichier → Run
--
-- Cette table stocke le statut partagé de chaque action du plan.
-- Le dashboard (index.html) la lit, l'écrit et s'abonne à ses
-- changements en temps réel pour synchroniser les trois associés.
-- ============================================================

-- 1) Table des statuts (une ligne par action : S1, T1, J1, ...)
create table if not exists public.task_status (
  task_id    text primary key,
  status     text not null default 'todo'
             check (status in ('todo','wip','done','block')),
  updated_at timestamptz not null default now()
);

-- 2) Row Level Security
--    Dashboard interne aux 3 Parties, sans système de connexion :
--    la clé publishable (rôle "anon") a un accès complet à CETTE
--    table uniquement. L'URL du dashboard fait office de secret.
alter table public.task_status enable row level security;

drop policy if exists "anon read"   on public.task_status;
drop policy if exists "anon insert" on public.task_status;
drop policy if exists "anon update" on public.task_status;
drop policy if exists "anon delete" on public.task_status;

create policy "anon read"   on public.task_status for select using (true);
create policy "anon insert" on public.task_status for insert with check (true);
create policy "anon update" on public.task_status for update using (true) with check (true);
create policy "anon delete" on public.task_status for delete using (true);

-- 3) Temps réel : diffuser les changements de cette table
--    (ignore l'erreur si la table y est déjà)
do $$
begin
  alter publication supabase_realtime add table public.task_status;
exception when duplicate_object then
  null;
end $$;


-- ============================================================
-- 4) Catégories ajoutées depuis le dashboard (en plus de celles du code)
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

create policy "anon read cat"   on public.categories for select using (true);
create policy "anon insert cat" on public.categories for insert with check (true);
create policy "anon update cat" on public.categories for update using (true) with check (true);
create policy "anon delete cat" on public.categories for delete using (true);

do $$
begin
  alter publication supabase_realtime add table public.categories;
exception when duplicate_object then
  null;
end $$;


-- ============================================================
-- 5) Actions ajoutées depuis le dashboard (en plus de celles du code)
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

create policy "anon read task"   on public.tasks for select using (true);
create policy "anon insert task" on public.tasks for insert with check (true);
create policy "anon update task" on public.tasks for update using (true) with check (true);
create policy "anon delete task" on public.tasks for delete using (true);

do $$
begin
  alter publication supabase_realtime add table public.tasks;
exception when duplicate_object then
  null;
end $$;
