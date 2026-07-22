# APSIA — Dashboard de pilotage

Dashboard interne de suivi du plan d'action APSIA (21 juil. → 5 oct. 2026),
partagé **en temps réel** entre les trois Parties via Supabase et déployé sur Vercel.

Chaque associé ouvre l'URL en ligne, met à jour / ajoute / modifie les actions,
et les autres voient les changements instantanément — sur n'importe quel appareil.

## Architecture

- **`index.html`** — application complète en un seul fichier (HTML + CSS + JS, aucune étape de build).
- **Supabase** — trois tables :
  - `task_status` : statut partagé de chaque action (à faire / en cours / fait / bloqué) ;
  - `categories` : catégories ajoutées ou modifiées depuis le dashboard ;
  - `tasks` : actions ajoutées, et modifications des actions du plan de base (surcharges).
  - + diffusion **temps réel** des trois tables.
- **Vercel** — hébergement statique du fichier `index.html`.
- **`localStorage`** — cache local : affichage instantané au chargement et repli si le réseau est coupé.

Le plan de base (catégories et actions) est défini dans le code. Les ajouts et
modifications faits depuis l'écran sont enregistrés dans Supabase et **fusionnés** par-dessus
le plan de base : une entrée Supabase de même identifiant remplace/édite celle du code.

## Mise en place (une seule fois)

### 1. Créer les tables dans Supabase

Dashboard Supabase → **SQL Editor** → **New query** → coller le contenu de
[`supabase/schema.sql`](supabase/schema.sql) → **Run**.

Le script crée les tables `task_status`, `categories` et `tasks`, active les politiques
d'accès (RLS) et le temps réel. Il est **idempotent** : si vous aviez déjà exécuté une
version précédente (table `task_status` seule), ré-exécutez-le simplement pour ajouter
`categories` et `tasks` — rien n'est perdu.

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

- **S'identifier** : au premier accès, choisir l'un des trois associés. Le profil est mémorisé
  sur l'appareil et présélectionné comme responsable lors de la création d'une action.
- **Naviguer** : le menu sépare le `Dashboard`, les liens vers les `Dossiers` Drive et
  l'`Historique` des dernières mises à jour de statut connues dans Supabase.
- **Changer un statut** : cliquer sur le badge d'une action → À faire → En cours → Fait → Bloqué.
- **Ajouter une action** : bouton « ＋ Nouvelle action », ou le **＋** dans l'en-tête d'une catégorie
  (pré-sélectionne cette catégorie) → remplir le formulaire → **Enregistrer**.
- **Ajouter une catégorie** : bouton « ＋ Nouvelle catégorie » → titre, couleur, sous-titre.
- **Modifier** : le crayon **✎** sur une action ou une catégorie ouvre le formulaire pré-rempli.
  Toutes les actions sont modifiables, y compris celles du plan de base.
- **Supprimer** : le **×** retire une action ou une catégorie **ajoutée** (les éléments du plan
  de base ne sont pas supprimables depuis l'écran, seulement modifiables).
- Tout ajout / modification / suppression est **partagé en temps réel** avec les trois Parties.
- **Indicateur d'en-tête** : *Synchronisé* / *Hors ligne* / *Erreur de sync*.
- **Rapport hebdo** : bouton « Générer le rapport hebdo » → copier → coller dans le groupe WhatsApp APSIA.
- **Réinitialiser les statuts** : remet tous les statuts à « À faire » **pour toute l'équipe**
  (ne supprime pas les actions ajoutées).

> L'identification nominative personnalise l'interface ; ce n'est pas un mécanisme
> d'authentification. La protection d'accès reste celle décrite dans la section Sécurité.

## Sécurité

Dashboard interne aux 3 associés, sans page de connexion : l'accès repose sur la
confidentialité de l'URL. La clé publishable donne un accès complet (lecture/écriture) aux
tables du dashboard. Pour un contrôle plus strict, ajouter l'authentification Supabase
(magic link) et restreindre les politiques RLS aux utilisateurs authentifiés.



git branch --set-upstream-to=upstream/main main