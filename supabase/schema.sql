-- ============================================================
-- APSIA — Dashboard de pilotage · schéma Supabase
-- ============================================================
-- À exécuter dans Supabase lors de l'installation, puis après chaque évolution du schéma :
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

-- Rattrapage des comptes éventuellement créés avant l'installation du trigger.
insert into public.profiles (user_id,actor,full_name)
select
  id,
  raw_user_meta_data ->> 'actor_code',
  case raw_user_meta_data ->> 'actor_code'
    when 'MD' then 'Mohamed DIAWARA'
    when 'MK' then 'Mamadou Cellou KANTÉ'
    when 'MH' then 'Mohamed HADY'
  end
from auth.users
where raw_user_meta_data ->> 'actor_code' in ('MD','MK','MH')
on conflict do nothing;

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


-- ============================================================
-- 8) Demandes de tâches entre associés
-- ============================================================
create table if not exists public.task_requests (
  id                uuid primary key default gen_random_uuid(),
  requester_user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  requester_actor   text not null check (requester_actor in ('MD','MK','MH')),
  recipient_actor   text not null check (recipient_actor in ('MD','MK','MH')),
  category_id       text not null default 'GEN',
  title             text not null,
  subtitle          text default '',
  due_date          date,
  priority          text not null default 'norm' check (priority in ('crit','haut','norm')),
  status            text not null default 'pending' check (status in ('pending','waiting','accepted','refused')),
  created_at        timestamptz not null default now(),
  responded_at      timestamptz,
  check (requester_actor <> recipient_actor)
);

-- Ajoute la catégorie aux installations créées avec une version antérieure.
alter table public.task_requests
  add column if not exists category_id text not null default 'GEN';

create index if not exists task_requests_recipient_idx
  on public.task_requests (recipient_actor,status,created_at desc);

alter table public.task_requests enable row level security;

drop policy if exists "team read related requests" on public.task_requests;
drop policy if exists "team create requests" on public.task_requests;

create policy "team read related requests" on public.task_requests
  for select to authenticated using (
    requester_user_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.actor = task_requests.recipient_actor
    )
  );

create policy "team create requests" on public.task_requests
  for insert to authenticated with check (
    requester_user_id = auth.uid()
    and requester_actor <> recipient_actor
    and exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.actor = task_requests.requester_actor
    )
  );

do $$
begin
  alter publication supabase_realtime add table public.task_requests;
exception when duplicate_object then
  null;
end $$;


-- ============================================================
-- 9) Tâches personnelles privées
-- ============================================================
create table if not exists public.personal_tasks (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null default auth.uid() references auth.users(id) on delete cascade,
  source_request_id uuid unique references public.task_requests(id) on delete set null,
  category_id       text not null default 'GEN',
  title             text not null,
  subtitle          text default '',
  due_date          date,
  priority          text not null default 'norm' check (priority in ('crit','haut','norm')),
  status            text not null default 'todo' check (status in ('todo','wip','done','block')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- Les tâches personnelles déjà présentes sont conservées et classées « Général ».
alter table public.personal_tasks
  add column if not exists category_id text not null default 'GEN';

create index if not exists personal_tasks_user_idx
  on public.personal_tasks (user_id,created_at desc);

alter table public.personal_tasks enable row level security;

drop policy if exists "owner read personal tasks"   on public.personal_tasks;
drop policy if exists "owner create personal tasks" on public.personal_tasks;
drop policy if exists "owner update personal tasks" on public.personal_tasks;
drop policy if exists "owner delete personal tasks" on public.personal_tasks;

create policy "owner read personal tasks" on public.personal_tasks
  for select to authenticated using (user_id = auth.uid());
create policy "owner create personal tasks" on public.personal_tasks
  for insert to authenticated with check (user_id = auth.uid());
create policy "owner update personal tasks" on public.personal_tasks
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "owner delete personal tasks" on public.personal_tasks
  for delete to authenticated using (user_id = auth.uid());

do $$
begin
  alter publication supabase_realtime add table public.personal_tasks;
exception when duplicate_object then
  null;
end $$;


-- Réponse atomique : la demande est traitée et, si elle est acceptée,
-- la tâche personnelle du destinataire est créée dans la même transaction.
create or replace function public.respond_task_request(p_request_id uuid,p_response text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  req public.task_requests%rowtype;
  current_actor text;
  new_task_id uuid;
begin
  if p_response not in ('accepted','refused','waiting') then
    raise exception 'Réponse invalide';
  end if;

  select actor into current_actor from public.profiles where user_id = auth.uid();
  select * into req from public.task_requests where id = p_request_id for update;

  if req.id is null or current_actor is null or req.recipient_actor <> current_actor then
    raise exception 'Demande introuvable ou accès refusé';
  end if;
  if req.status not in ('pending','waiting') then
    raise exception 'Cette demande a déjà été traitée';
  end if;

  if p_response = 'accepted' then
    insert into public.personal_tasks
      (user_id,source_request_id,category_id,title,subtitle,due_date,priority,status)
    values
      (auth.uid(),req.id,req.category_id,req.title,req.subtitle,req.due_date,req.priority,'todo')
    returning id into new_task_id;
  end if;

  update public.task_requests
    set status = p_response,
        responded_at = case when p_response = 'waiting' then null else now() end
    where id = req.id;

  insert into public.activity_log
    (actor,action,entity_type,entity_id,entity_title,from_value,to_value)
  values
    (current_actor,'request_' || p_response,'task_request',req.id::text,req.title,req.status,p_response);

  return new_task_id;
end;
$$;

revoke all on function public.respond_task_request(uuid,text) from public;
grant execute on function public.respond_task_request(uuid,text) to authenticated;
