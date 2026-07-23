-- APSIA — Ajout des catégories aux tâches personnelles et aux demandes
-- À exécuter dans Supabase SQL Editor sur une installation déjà existante.
-- Le script est réexécutable sans supprimer les données.

alter table public.task_requests
  add column if not exists category_id text not null default 'GEN';

alter table public.personal_tasks
  add column if not exists category_id text not null default 'GEN';

-- Reclassement prudent des anciennes tâches selon leur intitulé et leur description.
-- Seules les lignes encore classées « Général » sont concernées.
update public.task_requests
set category_id = case
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(sécur|secur|mot de passe|authent|accès|acces|vulnér|vulner|clé|cle)' then 'SEC'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(paiement|intouch|kkiapay|encaissement|mobile money)' then 'PAY'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(contrat|jurid|rccm|nif|oapi|cgu|confidentialité|confidentialite)' then 'JUR'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(logo|design|visuel|charte|maquette|interface)' then 'DES'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(test|recette|qualité|qualite|audit|validation)' then 'QUA'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(api|code|bug|serveur|déploiement|deploiement|technique|pwa|application|développement|developpement)' then 'TEC'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(budget|finance|dépense|depense|trésorerie|tresorerie|facture)' then 'FIN'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(partenariat|partenaire|fournisseur)' then 'PAR'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(commercial|marketing|campagne|réseau social|reseau social|client|école|ecole|vente|prospect)' then 'COM'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(documentation|document|guide|procédure|procedure|manuel)' then 'DOC'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(support|utilisateur|ticket|assistance|retour client)' then 'SUP'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(donnée|donnee|statistique|indicateur|reporting|tableau de bord)' then 'DAT'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(équipe|equipe|ressource humaine|rôle|role|recrutement)' then 'RH'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(opération|operation|logistique|terrain|coordination)' then 'OPS'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(pilotage|gouvernance|réunion|reunion|décision|decision|planning)' then 'PIL'
  else 'GEN'
end
where category_id = 'GEN';

update public.personal_tasks
set category_id = case
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(sécur|secur|mot de passe|authent|accès|acces|vulnér|vulner|clé|cle)' then 'SEC'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(paiement|intouch|kkiapay|encaissement|mobile money)' then 'PAY'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(contrat|jurid|rccm|nif|oapi|cgu|confidentialité|confidentialite)' then 'JUR'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(logo|design|visuel|charte|maquette|interface)' then 'DES'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(test|recette|qualité|qualite|audit|validation)' then 'QUA'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(api|code|bug|serveur|déploiement|deploiement|technique|pwa|application|développement|developpement)' then 'TEC'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(budget|finance|dépense|depense|trésorerie|tresorerie|facture)' then 'FIN'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(partenariat|partenaire|fournisseur)' then 'PAR'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(commercial|marketing|campagne|réseau social|reseau social|client|école|ecole|vente|prospect)' then 'COM'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(documentation|document|guide|procédure|procedure|manuel)' then 'DOC'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(support|utilisateur|ticket|assistance|retour client)' then 'SUP'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(donnée|donnee|statistique|indicateur|reporting|tableau de bord)' then 'DAT'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(équipe|equipe|ressource humaine|rôle|role|recrutement)' then 'RH'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(opération|operation|logistique|terrain|coordination)' then 'OPS'
  when lower(coalesce(title,'') || ' ' || coalesce(subtitle,'')) ~ '(pilotage|gouvernance|réunion|reunion|décision|decision|planning)' then 'PIL'
  else 'GEN'
end
where category_id = 'GEN';

-- Une demande acceptée conserve désormais sa catégorie dans la tâche créée.
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
