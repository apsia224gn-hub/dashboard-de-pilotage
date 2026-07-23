import {readFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';

const root=resolve(import.meta.dirname,'..');
const html=readFileSync(resolve(root,'index.html'),'utf8');
const schema=readFileSync(resolve(root,'supabase/schema.sql'),'utf8');
const failures=[];
const check=(condition,message)=>{if(!condition)failures.push(message)};

// Le JavaScript applicatif embarqué doit rester syntaxiquement valide.
const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)]
  .map(match=>match[1]).filter(Boolean);
for(const script of scripts){
  try{new Function(script)}catch(error){failures.push(`JavaScript invalide : ${error.message}`)}
}

// Les identifiants HTML doivent être uniques et les labels pointer vers un champ existant.
const ids=[...html.matchAll(/\sid="([^"]+)"/g)].map(match=>match[1]);
const duplicateIds=ids.filter((id,index)=>ids.indexOf(id)!==index);
check(duplicateIds.length===0,`Identifiants HTML dupliqués : ${[...new Set(duplicateIds)].join(', ')}`);
for(const [,target] of html.matchAll(/<label[^>]*\sfor="([^"]+)"/g)){
  check(ids.includes(target),`Label associé à un identifiant absent : ${target}`);
}

// Chaque bouton de navigation doit cibler une vue existante.
for(const [,view] of html.matchAll(/class="nav-btn[^"]*"[^>]*data-view="([^"]+)"/g)){
  check(ids.includes(`view-${view}`),`Vue de navigation absente : view-${view}`);
}

// Les ressources locales déclarées dans l'en-tête doivent exister.
for(const [,asset] of html.matchAll(/<(?:link|img)[^>]+(?:href|src)="([^"/:]+)"/g)){
  check(existsSync(resolve(root,asset)),`Ressource locale absente : ${asset}`);
}

// Garde-fous fonctionnels et SQL propres au dashboard APSIA.
const dashboard=html.match(/<section class="view on" id="view-dashboard">([\s\S]*?)<\/section>/)?.[1]||'';
check(!/(?:onclick|onchange)="(?:setPlanStatus|editTask|delTask|openTask|saveTask)/.test(dashboard),'Le Dashboard ne doit contenir aucune commande de modification');
check(!/\bbegina\b/i.test(schema),'Faute SQL détectée : « begina »');
for(const table of ['profiles','task_status','categories','tasks','activity_log','task_requests','personal_tasks']){
  check(schema.includes(`public.${table}`),`Table absente du schéma : ${table}`);
}
check(schema.includes('public.respond_task_request'),'Fonction respond_task_request absente du schéma');

if(failures.length){
  console.error(`Audit en échec (${failures.length})`);
  failures.forEach(failure=>console.error(`- ${failure}`));
  process.exit(1);
}

console.log('Audit APSIA réussi : JavaScript, HTML, navigation, ressources et schéma SQL vérifiés.');
