# APSIA — Dashboard de pilotage

Dashboard interne de suivi du plan d'action APSIA (21 juil. → 5 oct. 2026),
partagé **en temps réel** entre les trois Parties via Supabase et déployé sur Vercel.

Chaque associé ouvre l'URL en ligne, met à jour / ajoute / modifie les actions,
et les autres voient les changements instantanément — sur n'importe quel appareil.

## Architecture

- **`index.html`** — application complète en un seul fichier (HTML + CSS + JS, aucune étape de build).
- **Supabase Auth** — comptes individuels par e-mail et mot de passe.
- **Supabase** — sept tables :
  - `profiles` : lie chaque compte à l'un des trois associés APSIA ;
  - `task_status` : statut partagé de chaque action (à faire / en cours / fait / bloqué) ;
  - `categories` : catégories ajoutées ou modifiées depuis le dashboard ;
  - `tasks` : actions ajoutées, et modifications des actions du plan de base (surcharges).
  - `activity_log` : journal append-only indiquant qui a créé, modifié, supprimé ou changé un statut.
  - `personal_tasks` : tâches privées accessibles uniquement à leur propriétaire ;
  - `task_requests` : demandes de tâches envoyées entre associés et état de leur traitement.
  - + diffusion **temps réel** des tables de travail.
- **Vercel** — hébergement statique du fichier `index.html`.
- **`localStorage`** — cache local : affichage instantané au chargement et repli si le réseau est coupé.

Le plan de base (catégories et actions) est défini dans le code. Les ajouts et
modifications faits depuis l'écran sont enregistrés dans Supabase et **fusionnés** par-dessus
le plan de base : une entrée Supabase de même identifiant remplace/édite celle du code.

## Mise en place (une seule fois)

### 1. Créer les tables dans Supabase

Dashboard Supabase → **SQL Editor** → **New query** → coller le contenu de
[`supabase/schema.sql`](supabase/schema.sql) → **Run**.

Le script crée les tables `profiles`, `task_status`, `categories`, `tasks`, `activity_log`,
`personal_tasks` et `task_requests`, ainsi que la fonction atomique de traitement des demandes. Il active les politiques
d'accès (RLS) et le temps réel. Il est **idempotent** : si vous aviez déjà exécuté une
version précédente, ré-exécutez-le simplement pour ajouter les tables manquantes — rien
n'est perdu. **Exécutez ce schéma avant de créer le premier compte.**

Dans Supabase → **Authentication → Providers → Email**, laisser le fournisseur Email activé,
mais désactiver **Confirm email** afin que le compte soit utilisable immédiatement après sa
création. Les trois comptes restent protégés par leur mot de passe et les politiques RLS.

### 2. Configuration du dashboard

Les identifiants du projet Supabase sont déjà renseignés dans `index.html` :

```js
const SUPABASE_URL='https://ozjhiygpzarmfxhewgmv.supabase.co';
const SUPABASE_KEY='sb_publishable_...';   // clé publishable (publique, protégée par RLS)
```

> La clé *publishable* est conçue pour être exposée côté navigateur. **Ne jamais** mettre
> ici la clé *secret* / *service_role*.

### 3. Déployer sur Vercel

Le déploiement Vercel suit le dépôt **`apsia224gn-hub/dashboard-de-pilotage`**. Comme
`index.html` est à la racine, Vercel le sert automatiquement (projet statique, aucun build).
Chaque `git push` sur la branche `main` de ce dépôt redéploie.

## Utilisation

- **Créer ses identifiants** : au premier accès, saisir son e-mail, choisir un mot de passe et
  sélectionner son profil. Chaque profil APSIA ne peut être associé qu'à un seul compte.
- **Se connecter** : utiliser ensuite le même e-mail et le même mot de passe. Le profil du compte
  est utilisé comme auteur dans l'historique et comme responsable présélectionné.
- **Dashboard** : vue collective strictement en lecture seule (indicateurs, charge et plan d'action).
- **Mon espace** : chaque associé y retrouve les actions existantes du plan qui lui sont attribuées,
  ainsi que les actions collectives. Les statuts et modifications se font depuis cet espace. Les
  filtres de priorité permettent d'isoler les tâches critiques, hautes ou normales.
- **Tâche commune** : depuis `Mon espace`, ajouter une action partagée, préattribuée aux trois Parties.
  Elle apparaît sur le Dashboard et dans l'espace de chaque associé, et sa création est historisée.
- **Tâches personnelles** : ajout, modification et suppression de tâches privées, visibles uniquement
  par leur propriétaire.
- **Demandes** : proposer une tâche à un autre associé. Le destinataire reçoit une notification
  et peut accepter, refuser ou mettre la demande en attente. Une acceptation crée automatiquement
  la tâche dans son espace personnel.
- **Changer un statut** : dans `Mon espace`, ouvrir le menu de statut d'une tâche puis choisir directement
  À faire, En cours, Fait ou Bloqué.
- **Modifier une action du plan** : utiliser le bouton `Modifier` dans `Mes actions du plan`.
- **Supprimer** : seules les tâches personnelles ou actions ajoutées peuvent être supprimées ;
  les actions de base du plan restent modifiables mais ne sont pas supprimables.
- Tout ajout / modification / suppression est **partagé en temps réel** avec les trois Parties.
- **Indicateur d'en-tête** : *Synchronisé* / *Hors ligne* / *Erreur de sync*.
- **Rapport hebdo** : bouton « Générer le rapport hebdo » → copier → coller dans le groupe WhatsApp APSIA.

## Contrôle qualité

Exécuter `node scripts/audit.mjs` pour vérifier la syntaxe JavaScript, les identifiants et labels HTML,
la navigation, les ressources locales, le caractère non modifiable du Dashboard et les éléments essentiels
du schéma SQL. Le dernier rapport détaillé est disponible dans [`AUDIT.md`](AUDIT.md).

## Sécurité

Le dashboard utilise Supabase Auth. Les politiques RLS refusent l'accès aux données partagées
tant qu'aucune session authentifiée n'est active. Le journal vérifie également que l'auteur
enregistré correspond au profil lié au compte connecté. La clé publishable reste publique,
mais ne permet plus à elle seule de lire ou modifier les tables.

Les tâches de `Mon espace` sont privées au niveau de la base. Pour assurer la traçabilité convenue,
leur intitulé et les opérations réalisées apparaissent néanmoins dans l'historique commun.
