# Audit UX, fonctionnel et responsive — APSIA

Date : 23 juillet 2026

## Périmètre contrôlé

- navigation et hiérarchie des cinq espaces ;
- authentification et cohérence des libellés ;
- lecture du Dashboard, filtres et états vides ;
- gestion des actions du plan, tâches personnelles et tâches communes ;
- demandes reçues/envoyées et journal d'activité ;
- comportement en cas d'erreur réseau ;
- affichage desktop (1440 × 1000) et mobile (390 × 844) ;
- structure HTML, syntaxe JavaScript, ressources locales et schéma Supabase ;
- disponibilité en lecture des sept tables Supabase et configuration de confirmation des e-mails.

## Résultat

L'audit automatisé local passe. Les sept routes REST Supabase répondent avec un code HTTP 200 et
restent protégées par les politiques RLS sans session. La configuration Auth répond également avec
un code HTTP 200 et `mailer_autoconfirm` est activé : aucune confirmation d'e-mail n'est demandée.

Les captures desktop et mobile de l'écran d'authentification, du Dashboard rempli et de « Mon espace »
ne montrent ni débordement de page, ni champ ou carte tronqué. La navigation et les groupes de filtres
mobiles restent volontairement balayables horizontalement pour conserver leurs libellés compréhensibles.

Les parcours nécessitant un compte connecté ont été contrôlés statiquement jusqu'aux requêtes Supabase,
mais aucun ajout réel n'a été effectué dans les données de production pendant cet audit.

## Corrections et améliorations réalisées

- nouvelle hiérarchie visuelle, fond plus lisible, cartes et espacements harmonisés ;
- titre explicite et badge « Lecture seule » sur le Dashboard ;
- filtres regroupés par responsable, statut et priorité, avec compteur et remise à zéro ;
- ajout du filtre « Faites », auparavant absent du Dashboard ;
- état vide global lorsqu'aucune action ne correspond aux filtres ;
- résumé personnel : tâches actives, priorités critiques et échéances dépassées ;
- tri de « Mon espace » par priorité puis par échéance ;
- filtre de statut ajouté à « Mon espace » ;
- sélection directe d'un statut, plus explicite que l'ancien changement cyclique ;
- catégorie et urgence d'échéance affichées sur les actions du plan ;
- priorité et urgence ajoutées aux cartes de demandes ;
- demandes triées par état, priorité puis échéance ;
- notifications discrètes à la place des fenêtres d'alerte bloquantes ;
- prévention des doubles enregistrements dans les dialogues ;
- restauration du statut précédent si la synchronisation échoue ;
- attente de la confirmation Supabase avant de masquer un ajout ou une suppression ;
- labels de formulaires, navigation courante, focus clavier, lien d'accès direct et zone `aria-live` ;
- correction de la faute SQL bloquante `begina` dans `supabase/schema.sql` ;
- ajout de `scripts/audit.mjs` pour détecter automatiquement les régressions principales.

## Recommandations suivantes

1. **Atomicité des actions partagées** — déplacer les modifications/suppressions et leur journalisation
   dans des fonctions SQL transactionnelles, comme cela est déjà fait pour l'acceptation d'une demande.
2. **Autorisations plus fines** — décider si une action du plan peut être modifiée par les trois associés
   ou seulement par son responsable, puis traduire cette règle dans la base plutôt que dans l'interface.
3. **Gestion du compte** — ajouter « Mot de passe oublié » et la modification du mot de passe.
4. **Historique avancé** — ajouter recherche, filtres par associé/type/date et pagination au-delà des
   200 événements chargés actuellement.
5. **Données du plan** — migrer progressivement les actions de base codées dans `index.html` vers Supabase
   afin de simplifier les évolutions et les sauvegardes.
6. **Mode hors ligne réel** — ajouter un service worker et une file de synchronisation avant de présenter
   le cache local comme un mode hors ligne complet.

## Rejouer le contrôle local

```bash
node scripts/audit.mjs
```
