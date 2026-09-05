# Pellicule

Carnet de prise de vue argentique pour iPhone. Application native, hors ligne,
sans compte ni serveur : les données restent dans le téléphone.

Format pris en charge : **135 (24×36)**.

## État du projet

**Première version installable.** De quoi tenir un rouleau de bout en bout —
déclarer un boîtier, charger une pellicule, noter ses vues, suivre le rouleau
jusqu'à l'archive, exporter le carnet.

| | |
|---|---|
| Calculs argentiques, banques de matériel, assistant | **fait**, 79 tests |
| Stockage du carnet, import et export | **fait** |
| Écrans : rouleaux, vues, matériel, réglages | **fait** |
| Écran d'assistance à la prise de vue | à venir |
| Posemètre par la caméra | à venir |
| Rapprochement des scans du laboratoire | à venir |

L'installation passe par SideStore, et non par l'App Store : voir
[INSTALLATION.md](INSTALLATION.md), qui dit aussi ce que ça coûte.

## Ce que l'application fait

**Matériel.** Boîtiers (monture, numéro de série, décalage du posemètre, plage
de vitesses) et objectifs (focale, ouvertures extrêmes, diamètre de filtre). Les
caractéristiques déclarées bornent tout ce que l'application propose ensuite.

**Pellicules.** Une cinquantaine d'émulsions 135 préchargées — noir et blanc,
négatif couleur, diapositive — avec sensibilité nominale, procédé, courbe de
réciprocité et, pour les principales, des temps de développement de référence.

**Rouleaux.** Chargement, suivi du cycle de vie — chargé, en cours, terminé, au
labo, développé, scanné, archivé — référence d'archive, laboratoire, coûts. Le
push/pull se déduit de l'écart entre la sensibilité employée et l'ISO de la
boîte.

**Vues.** Vitesse, ouverture, objectif, focale, correction d'exposition, sujet,
notes. Les graduations sont bornées par le matériel : les vitesses sont celles
du boîtier, les ouvertures celles de l'objectif monté — proposer un 1/4000 sur
un boîtier qui plafonne à 1/1000, c'est offrir de consigner un réglage qui n'a
jamais existé. D'une vue à l'autre les réglages sont repris, le sujet non.

**Assistant de prise de vue** *(le moteur est écrit et testé, l'écran reste à
faire)*. Le cœur de l'aide à la décision. On déclare une intention — portrait,
paysage, rue, mouvement, filé, basse lumière, pose longue — et une condition de
lumière ; l'application en déduit le couple vitesse/ouverture, la zone de
netteté et l'hyperfocale.

Tout est borné par le matériel réellement déclaré. Quand la scène sort de ces
limites, l'application ne se contente pas de le signaler : elle propose la
correction applicable et explique ce qui coince — un film trop rapide pour la
lumière, un besoin de filtre gris neutre, un risque de flou de bougé au regard
de la règle du 1/focale.

**Développement** *(à venir dans l'application)*. Révélateur, dilution, temps,
température, agitation. Le temps se déduit des données du film, de la
température du bain et du push/pull du rouleau.

**Métadonnées des scans** *(à venir dans l'application)*. Un scan de laboratoire
arrive nu : ni date de prise de vue, ni boîtier, ni réglages. Le carnet sait
reconstituer tout cela et l'écrire dans les fichiers, qui se comportent dès lors
comme des photos numériques dans n'importe quelle photothèque.

**Sauvegarde.** Le carnet *est* un fichier JSON lisible, et il appartient au
photographe. Il n'y a pas de base de données à côté : exporter revient à en
copier une, importer à la relire. Le fichier apparaît dans l'application
Fichiers, sous « Sur mon iPhone » — récupérable même si l'application refuse de
s'ouvrir.

## Le noyau

`PelliculeCore/` contient tout ce qui calcule et tout ce qui se range : échelles
d'exposition, réciprocité, profondeur de champ, temps de développement, moteur
de l'assistant, banques de matériel, carnet, persistance, métadonnées.
`App/` ne contient que des écrans.

Il ne dépend d'**aucun SDK Apple**, ce qui a une conséquence pratique
importante : il se compile et se teste sur Linux comme sur macOS, en une
dizaine de secondes, sans simulateur. Toute la partie du projet où une erreur
coûte un rouleau de pellicule est donc vérifiable partout.

```sh
cd PelliculeCore && swift test
```

L'intégration continue les rejoue sur Linux à chaque poussée, et compile le même
code pour iOS sur un runner macOS.

## Ce que l'application ne fera pas

**Aucun compte, aucun serveur, aucune télémétrie.** Il n'y a rien à héberger et
rien à collecter : le carnet vit dans le téléphone et dans les sauvegardes que
son propriétaire en fait.

## Réserves sur les calculs

Les exposants de réciprocité viennent des notices des fabricants quand elles les
publient, de l'interpolation de leurs tables sinon. La correction de température
du développement suit un coefficient de 2,5 pour 10 °C, et le push allonge
d'environ 35 % par diaphragme. Ces modèles reproduisent les tables publiées à
quelques pourcents près : ils cadrent une décision sur le terrain, ils ne
remplacent pas la notice du film ni, après quelques rouleaux, votre propre
expérience.

La règle du projet, valable aussi pour les banques de matériel : **une valeur
absente vaut mieux qu'une valeur devinée.** Un conseil faux donné avec assurance
est pire qu'un conseil manquant.

## Historique

Le carnet a d'abord existé sous forme d'application web installable, en
TypeScript. Elle fonctionnait, mais deux besoins la dépassaient : mesurer la
lumière avec la caméra, ce que WebKit interdit, et écrire les métadonnées
directement dans les scans. Le projet a donc entièrement basculé en natif.

Cette version-là n'est pas maintenue et ne fait plus partie du dépôt ; elle
reste dans l'historique Git. L'application lit ses sauvegardes, de sorte qu'un
carnet tenu avant la bascule se reprend sans rien ressaisir — c'est même l'objet
d'une partie des tests.

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md). La contribution la plus utile n'exige
aucune connaissance de Swift : compléter les banques de boîtiers, d'objectifs et
de pellicules, qui sont de simples fichiers JSON.

## Licence

[MIT](LICENSE).
