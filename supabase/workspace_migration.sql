-- APSIA — Migration unique « Mon espace / Demandes »
-- Pré-requis : profiles et activity_log existent déjà.

create table if not exists public.task_requests (
  id uuid primary key default gen_random_uuid(),
  requester_user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  requester_actor text not null check (requester_actor in ('MD','MK','MH')),
  recipient_actor text not null check (recipient_actor in ('MD','MK','MH')),
  category_id text not null default 'GEN',
  title text not null,
  subtitle text default '',
  due_date date,
  priority text not null default 'norm' check (priority in ('crit','haut','norm')),
  status text not null default 'pending' check (status in ('pending','waiting','accepted','refused')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_actor <> recipient_actor)
);

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

create table if not exists public.personal_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  source_request_id uuid unique references public.task_requests(id) on delete set null,
  category_id text not null default 'GEN',
  title text not null,
  subtitle text default '',
  due_date date,
  priority text not null default 'norm' check (priority in ('crit','haut','norm')),
  status text not null default 'todo' check (status in ('todo','wip','done','block')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.personal_tasks
  add column if not exists category_id text not null default 'GEN';

create index if not exists personal_tasks_user_idx
  on public.personal_tasks (user_id,created_at desc);

alter table public.personal_tasks enable row level security;
drop policy if exists "owner read personal tasks" on public.personal_tasks;
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

-- Les deux tables sont nouvelles : cet ALTER est volontairement direct afin
-- d'éviter le bloc DO problématique dans le SQL Editor.
alter publication supabase_realtime
  add table public.task_requests, public.personal_tasks;

create or replace function public.respond_task_request(p_request_id uuid,p_response text)
returns uuid
language plpgsql
security definer set search_path = public
as $function$
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
$function$;

revoke all on function public.respond_task_request(uuid,text) from public;
grant execute on function public.respond_task_request(uuid,text) to authenticated;
