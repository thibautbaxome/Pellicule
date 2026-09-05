# Installer Pellicule sur un iPhone

L'application n'est pas sur l'App Store et n'y sera pas : la publier suppose un
compte de développeur Apple à 99 € par an, ce que le projet refuse. Elle
s'installe donc autrement, gratuitement, avec **SideStore**.

## Ce que ça implique, dit franchement

Une application installée avec un compte Apple gratuit **expire au bout de sept
jours**. C'est une règle d'Apple, aucun outil ne la contourne.

Ce que SideStore change, c'est qui s'en occupe : il resigne l'application tout
seul, en tâche de fond, par le Wi-Fi. En pratique vous ne voyez rien — à la
différence d'Xcode, où il faut rebrancher un câble chaque semaine.

Les contraintes qui restent :

- **un ordinateur, une seule fois**, pour la mise en place initiale ;
- **trois applications au maximum** avec un compte Apple gratuit ;
- si l'iPhone reste des semaines hors du Wi-Fi, l'application peut expirer et
  demander une réinstallation. Le carnet, lui, n'est pas perdu pour autant.

## 1. Mettre SideStore en place

À faire une fois. Comptez une trentaine de minutes la première fois.

Le guide officiel fait autorité et reste à jour :
**<https://docs.sidestore.io/docs/installation/install>**

Le principe, pour savoir où vous allez :

1. Sur un ordinateur (macOS, Windows ou Linux), engendrer un **fichier
   d'appairage** de votre iPhone, et installer SideStore.
2. Sur l'iPhone, faire confiance au compte : *Réglages → Général → VPN et
   gestion de l'appareil*.
3. Activer le **mode développeur** : *Réglages → Confidentialité et sécurité*.
4. Ouvrir SideStore et s'y connecter avec votre identifiant Apple.

Un mot sur cette connexion : SideStore signe les applications avec **votre**
certificat de développeur, ce qui exige votre identifiant Apple. Le projet
n'a évidemment aucun moyen de vérifier ce que SideStore en fait — c'est un
logiciel libre largement employé, mais la confiance que vous lui accordez vous
regarde. Un identifiant Apple créé pour l'occasion est une précaution
raisonnable.

L'ordinateur ne sert plus après cette étape.

## 2. Installer Pellicule

1. Ouvrir sur l'iPhone la page des versions :
   **<https://github.com/thibautbaxome/Pellicule/releases>**
2. Télécharger le fichier `Pellicule.ipa` de la version la plus récente.
3. Dans SideStore : **+**, puis choisir le fichier téléchargé.
4. Attendre la fin de la signature. L'icône apparaît sur l'écran d'accueil.

## 3. Mettre à jour

Même chose : télécharger le nouvel `.ipa`, l'installer par-dessus. **Le carnet
est conservé** — il vit dans les documents de l'application, pas dans le code.

Par prudence avant une mise à jour : *Réglages → Sauvegarde → Exporter le
carnet*. Le fichier obtenu vous appartient, et se relit avec « Importer un
carnet ».

## Si l'application refuse de s'ouvrir

Le carnet reste accessible en dehors d'elle. Ouvrez l'application **Fichiers**,
*Sur mon iPhone*, dossier *Pellicule* : `carnet.json` s'y trouve. Copiez-le
avant toute autre manipulation.

L'application est écrite pour ne jamais écraser un carnet qu'elle n'a pas su
relire : en cas de problème de lecture, elle se bloque volontairement plutôt que
de repartir d'un carnet vide.

## Et sur Android, ou sur ordinateur ?

Rien pour l'instant. Le projet a délibérément abandonné sa version web pour
pouvoir mesurer la lumière avec la caméra et écrire les métadonnées directement
dans les scans, deux choses qu'un navigateur interdit. Le noyau de calcul est
séparé de l'interface et ne dépend d'aucune bibliothèque Apple : un portage
resterait possible, mais personne n'y travaille.
