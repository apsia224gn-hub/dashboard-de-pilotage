# APSIA — Dashboard de pilotage

Dashboard interne de suivi du plan d'action APSIA (21 juil. → 5 oct. 2026),
partagé **en temps réel** entre les trois Parties via Supabase et déployé sur Vercel.

Chaque associé ouvre l'URL en ligne, met à jour / ajoute / modifie les actions,
et les autres voient les changements instantanément — sur n'importe quel appareil.

## Architecture

- **`index.html`** — application complète en un seul fichier (HTML + CSS + JS, aucune étape de build).
- **Supabase Auth** — comptes individuels par e-mail et mot de passe.
- **Supabase** — cinq tables :
  - `profiles` : lie chaque compte à l'un des trois associés APSIA ;
  - `task_status` : statut partagé de chaque action (à faire / en cours / fait / bloqué) ;
  - `categories` : catégories ajoutées ou modifiées depuis le dashboard ;
  - `tasks` : actions ajoutées, et modifications des actions du plan de base (surcharges).
  - `activity_log` : journal append-only indiquant qui a créé, modifié, supprimé ou changé un statut.
  - + diffusion **temps réel** des quatre tables.
- **Vercel** — hébergement statique du fichier `index.html`.
- **`localStorage`** — cache local : affichage instantané au chargement et repli si le réseau est coupé.

Le plan de base (catégories et actions) est défini dans le code. Les ajouts et
modifications faits depuis l'écran sont enregistrés dans Supabase et **fusionnés** par-dessus
le plan de base : une entrée Supabase de même identifiant remplace/édite celle du code.

## Mise en place (une seule fois)

### 1. Créer les tables dans Supabase

Dashboard Supabase → **SQL Editor** → **New query** → coller le contenu de
[`supabase/schema.sql`](supabase/schema.sql) → **Run**.

Le script crée les tables `profiles`, `task_status`, `categories`, `tasks` et `activity_log`, active les politiques
d'accès (RLS) et le temps réel. Il est **idempotent** : si vous aviez déjà exécuté une
version précédente, ré-exécutez-le simplement pour ajouter les tables manquantes — rien
n'est perdu. **Exécutez ce schéma avant de créer le premier compte.**

Dans Supabase → **Authentication → Providers → Email**, laisser le fournisseur Email activé.
Le projet demande actuellement une confirmation par e-mail : chaque associé doit cliquer sur
le lien reçu avant sa première connexion. Dans **Authentication → URL Configuration**, ajouter
l'URL Vercel du dashboard aux Redirect URLs.

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
- **Naviguer** : le menu sépare le `Dashboard`, les liens vers les `Dossiers` Drive et
  l'`Historique` partagé indiquant qui a fait quoi et à quelle heure.
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

## Sécurité

Le dashboard utilise Supabase Auth. Les politiques RLS refusent l'accès aux données partagées
tant qu'aucune session authentifiée n'est active. Le journal vérifie également que l'auteur
enregistré correspond au profil lié au compte connecté. La clé publishable reste publique,
mais ne permet plus à elle seule de lire ou modifier les tables.
