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
