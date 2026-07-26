-- APSIA — Correctif des boutons Accepter / Refuser / Mettre en attente
-- À exécuter une fois dans Supabase SQL Editor.

create or replace function public.respond_task_request(p_request_id uuid,p_response text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  req public.task_requests%rowtype;
  current_user_id uuid := auth.uid();
  current_actor text;
  new_task_id uuid;
begin
  if current_user_id is null then
    raise exception 'Session utilisateur expirée';
  end if;
  if p_response not in ('accepted','refused','waiting') then
    raise exception 'Réponse invalide';
  end if;

  select actor
    into current_actor
    from public.profiles
   where user_id = current_user_id;

  select *
    into req
    from public.task_requests
   where id = p_request_id
   for update;

  if req.id is null then
    raise exception 'Demande introuvable';
  end if;
  if current_actor is null or req.recipient_actor <> current_actor then
    raise exception 'Accès refusé : seul le destinataire peut répondre';
  end if;
  if req.status not in ('pending','waiting') then
    raise exception 'Cette demande a déjà été traitée';
  end if;

  if p_response = 'accepted' then
    insert into public.personal_tasks
      (user_id,source_request_id,category_id,title,subtitle,due_date,priority,status)
    values
      (current_user_id,req.id,coalesce(req.category_id,'GEN'),req.title,req.subtitle,req.due_date,req.priority,'todo')
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
revoke execute on function public.respond_task_request(uuid,text) from anon;
grant execute on function public.respond_task_request(uuid,text) to authenticated;

-- Force PostgREST à recharger immédiatement la fonction et ses permissions.
notify pgrst, 'reload schema';
