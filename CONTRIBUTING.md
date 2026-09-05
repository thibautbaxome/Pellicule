# Contribuer

Merci d'y jeter un œil. Le projet est petit et le restera : un carnet de prise
de vue argentique qui fonctionne hors ligne, sans compte et sans serveur.

## La contribution la plus utile : enrichir les banques

Trois catalogues font tourner l'application, et ce sont de simples fichiers
JSON. **Aucune connaissance de Swift n'est nécessaire pour les enrichir** — si
vous possédez un boîtier absent de la liste, vous êtes la bonne personne pour
l'ajouter.

Ils vivent dans `PelliculeCore/Sources/PelliculeCore/Resources/`.

### Ajouter un boîtier

`cameras.json` :

```json
{
  "id": "minolta-x-300",
  "brand": "Minolta",
  "model": "X-300",
  "mount": "Minolta SR",
  "type": "slr",
  "years": "1984–1990",
  "shutterFastest": "1/1000",
  "shutterSlowest": "1s",
  "notes": "Priorité ouverture et manuel."
}
```

`type` vaut `slr`, `rangefinder`, `compact` ou `viewfinder`.

La plage de vitesses est le champ qui compte le plus : c'est elle qui permet à
l'assistant de dire « ce réglage sort de ce que ton boîtier sait faire ».
**Dans le doute, omettez le champ plutôt que de deviner** — une valeur fausse
est pire qu'une valeur absente, elle donne un conseil faux avec assurance.

Pour un compact à objectif solidaire, la monture vaut `"Fixe"` et le boîtier
porte `"fixedLens": { "focal": 35, "maxAperture": 2.8 }`. Les deux vont
ensemble : l'un sans l'autre fait échouer les tests.

### Ajouter un objectif

`lenses.json` : marque, nom, monture, focales, ouvertures extrêmes, diamètre de
filtre. Une focale fixe a `focalMin` égal à `focalMax`. Attention au sens des
ouvertures : `maxAperture` est la **plus grande** ouverture, donc le plus petit
nombre — f/1.7 pour un 50 mm standard.

La monture doit exister sur un boîtier de `cameras.json`, sans quoi l'objectif
serait introuvable : le sélecteur filtre par monture.

### Ajouter une pellicule

`films.json`. L'identifiant est un slug **stable** : il ne doit jamais changer,
sous peine de dupliquer l'entrée chez les utilisateurs à la mise à jour.

L'exposant de réciprocité vient de la notice du fabricant quand elle le
publie — Ilford donne directement `t_c = t^p` — ou de l'interpolation de ses
tables de correction. Citez votre source dans la pull request.

Les temps de développement ne concernent que le noir et blanc.

### Après avoir modifié une banque

```sh
cd PelliculeCore && swift test
```

JSON n'a ni commentaire, ni type, ni contrainte : c'est
`CatalogValidationTests` qui tient lieu de garde-fou. Il refuse un identifiant
en double, des vitesses inversées, une ouverture maximale plus petite que la
minimale, un objectif dont la monture n'existe nulle part, un exposant de
réciprocité aberrant, un temps de développement invraisemblable.

Il vérifie la **cohérence**, jamais l'exactitude historique : il ne saura pas
vous dire qu'un Nikon FM2 monte à 1/4000 et non à 1/2000. Cette partie-là repose
sur vous, et c'est pourquoi un champ vide reste préférable à un champ deviné.

## Le code

```sh
cd PelliculeCore
swift test          # tous les calculs, en une dizaine de secondes
swift build
```

Le noyau ne dépend d'aucun SDK Apple : il se compile et se teste sur Linux comme
sur macOS, sans Xcode ni simulateur. C'est délibéré — toute la partie du projet
où une erreur coûte un rouleau de pellicule est vérifiable partout, et
rapidement.

Un calcul modifié se modifie avec son test. Les valeurs attendues des tests ne
sont pas des captures de la sortie courante : elles viennent des tables des
fabricants et de l'arithmétique de l'exposition. Un test qu'on ajuste jusqu'à ce
qu'il passe ne vérifie plus rien.

### L'application

`App/` ne contient que des écrans SwiftUI ; toute logique va dans le noyau, où
elle est testable. Le projet Xcode n'est pas versionné : `xcodegen generate`
le reconstitue depuis `project.yml`.

`UITests/ParcoursTests.swift` traverse l'application dans le simulateur, à
chaque poussée, et publie une capture de chaque écran sur la branche
`captures`. **Un nouvel écran doit y être ajouté** : c'est le seul regard que
l'intégration continue porte sur l'interface, et un écran qu'on ne peut pas
atteindre par ce chemin ne l'est pas davantage par un photographe.

## Conventions

- **Français** dans l'interface, les commentaires et les messages de commit.
- Les commentaires expliquent *pourquoi*, pas *quoi*. Un commentaire qui
  paraphrase la ligne suivante est du bruit ; un commentaire qui dit pourquoi
  la tolérance vaut un tiers de diaphragme vaut de l'or.
- Aucune dépendance sans raison sérieuse.
- Aucune requête sortante. Les données ne quittent pas l'appareil.

## Ce qui ne sera pas accepté

- Un compte, une inscription, un serveur central.
- De la télémétrie ou des mouchards, sous quelque forme que ce soit.
- Des valeurs argentiques inventées. Si vous n'êtes pas sûr d'un temps de
  développement ou d'une plage de vitesses, dites-le dans la pull request —
  on préfère un champ vide à une donnée fausse.
