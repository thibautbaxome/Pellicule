# Contribuer

Merci d'y jeter un œil. Le projet est petit et le restera : un carnet de prise
de vue argentique qui fonctionne hors ligne, sans compte et sans serveur.

## La contribution la plus utile : enrichir les banques

Deux catalogues font tourner l'application, et ce sont de simples fichiers de
données. **Aucune connaissance de React n'est nécessaire pour les enrichir** —
si vous possédez un boîtier absent de la liste, vous êtes la bonne personne
pour l'ajouter.

### Ajouter un boîtier

`src/db/cameraCatalog.ts` :

```ts
{
  brand: 'Minolta',
  model: 'X-300',
  mount: 'Minolta SR',
  type: 'slr',
  years: '1984–1990',
  shutterFastest: '1/1000',
  shutterSlowest: '1s',
  notes: 'Priorité ouverture et manuel.',
},
```

La plage de vitesses est le champ qui compte le plus : c'est elle qui permet à
l'assistant de dire « ce réglage sort de ce que ton boîtier sait faire ».
**Dans le doute, laissez le champ vide plutôt que de deviner** — une valeur
fausse est pire qu'une valeur absente, elle donne un conseil faux avec
assurance.

Pour un compact à objectif solidaire, `mount: FIXED_MOUNT` et
`fixedLens: { focal: 35, maxAperture: 2.8 }`.

### Ajouter un objectif

`src/db/lensCatalog.ts` : marque, nom, monture, focales, ouvertures extrêmes,
diamètre de filtre. Une focale fixe a `focalMin === focalMax`.

### Ajouter une pellicule

`src/db/filmCatalog.ts`. L'identifiant est un slug **stable** : il ne doit
jamais changer, sous peine de dupliquer l'entrée chez les utilisateurs à la
mise à jour.

L'exposant de réciprocité vient de la notice du fabricant quand elle le
publie — Ilford donne directement `t_c = t^p` — ou de l'interpolation de ses
tables de correction. Citez votre source dans la pull request.

### Après avoir modifié une banque

Les trois catalogues sont aussi lus par la version native, qui les décode
depuis une projection JSON. Régénérez-la et versionnez-la avec votre
modification :

```sh
npm run catalogs
```

Les fichiers TypeScript restent la source de vérité — ils portent les
commentaires et les regroupements que JSON ne sait pas contenir. La commande
échoue si deux entrées partagent un identifiant, ce qui en ferait disparaître
une silencieusement.

## Le code

```sh
npm install
npm run dev      # serveur de développement
npm run build    # build de production
npm run lint
npm run smoke    # parcours de bout en bout, serveur de prévisualisation requis
```

Le parcours `tools/smoke.mjs` traverse l'application dans un iPhone simulé et
**échoue à la moindre erreur de console**. Il produit une capture par étape,
utile pour vérifier une modification visuelle. `tools/offline-check.mjs`
vérifie que l'application reste utilisable réseau coupé — c'est une promesse du
projet, pas un bonus.

Faites tourner les deux avant d'ouvrir une pull request.

### Le noyau natif

`native/PelliculeCore/` contient les calculs argentiques portés en Swift, pour
l'application iOS en préparation. Aucune dépendance aux SDK Apple : ils se
compilent et se testent sur Linux comme sur macOS.

```sh
cd native/PelliculeCore && swift test
```

Toute modification d'un calcul doit l'être des deux côtés, avec le même test de
part et d'autre. C'est cette redondance qui a permis de repérer un conseil
contradictoire que la version web donnait depuis des semaines.

## Conventions

- **Français** dans l'interface, les commentaires et les messages de commit.
- Les commentaires expliquent *pourquoi*, pas *quoi*. Un commentaire qui
  paraphrase la ligne suivante est du bruit ; un commentaire qui dit pourquoi
  la tolérance vaut un tiers de diaphragme vaut de l'or.
- Aucune dépendance sans raison sérieuse. L'application doit rester légère et
  précachée en entier par le service worker.
- Aucune requête sortante. La politique de sécurité du site l'interdit, et
  c'est volontaire : les données ne quittent pas l'appareil.

## Ce qui ne sera pas accepté

- Un compte, une inscription, un serveur central.
- De la télémétrie ou des mouchards, sous quelque forme que ce soit.
- Des valeurs argentiques inventées. Si vous n'êtes pas sûr d'un temps de
  développement ou d'une plage de vitesses, dites-le dans la pull request —
  on préfère un champ vide à une donnée fausse.
