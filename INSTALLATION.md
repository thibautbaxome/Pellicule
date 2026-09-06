# Installer Pellicule sur un iPhone

L'application n'est pas sur l'App Store et n'y sera pas : la publier suppose un
compte de développeur Apple à 99 € par an, ce que le projet refuse. Elle
s'installe donc autrement, gratuitement, en la **signant avec votre propre
compte Apple** — c'est ce qu'on appelle le chargement latéral (*sideloading*).

## Ce que ça implique, dit franchement

Une application signée avec un compte Apple gratuit **expire au bout de sept
jours**. C'est une règle d'Apple, aucun outil ne la contourne. Passé ce délai,
l'icône refuse de s'ouvrir tant que l'application n'a pas été re-signée.

Ce qui change d'un outil à l'autre, c'est **qui s'occupe de la re-signer** :

| Méthode | Ordinateur | Re-signature | Visibilité de l'échéance |
|---|---|---|---|
| **AltStore** (recommandé) | Un Mac ou un PC, souvent allumé | Automatique, par le Wi-Fi, tant que l'ordinateur est allumé sur le même réseau | Dans AltStore et dans Pellicule |
| Un outil de chargement sur l'ordinateur (iLoader, Sideloadly…) | Un Mac ou un PC | À la main, au câble, chaque semaine | Dans Pellicule |
| **SideStore** | Une seule fois, pour la mise en place | Automatique, sans ordinateur | Dans SideStore et dans Pellicule |

Dans tous les cas :

- **Pellicule affiche elle-même la date d'expiration** de sa signature, dans
  *Réglages → À propos*. Vous n'êtes jamais devant une icône muette sans
  avoir été prévenu.
- **Réinstaller ne perd rien.** Le carnet vit dans les documents de
  l'application, pas dans son code : réinstaller le même fichier par-dessus
  remet le compteur à sept jours et garde tout.
- **Trois applications au maximum** peuvent être signées avec un compte
  Apple gratuit.
- L'outil, quel qu'il soit, signe avec **votre** identifiant Apple et vous le
  demande donc. Le projet n'a aucun moyen de vérifier ce que l'outil en fait ;
  un identifiant Apple créé pour l'occasion est une précaution raisonnable.

## Méthode recommandée : AltStore

Deux logiciels : **AltServer** sur l'ordinateur, **AltStore** sur l'iPhone.
Guide officiel, à jour : **<https://altstore.io>** (bouton *Download*, puis
les instructions pour macOS ou Windows). Comptez vingt minutes la première fois.

### 1. Mettre AltStore en place, une fois

1. Installer **AltServer** sur l'ordinateur. Il ne vit que dans la barre des
   menus (macOS) ou la barre des tâches (Windows).
2. Brancher l'iPhone au câble, le déverrouiller, accepter « Se fier à cet
   ordinateur ». Sur macOS, dans le Finder, cocher **« Afficher cet iPhone
   lorsqu'il est en Wi-Fi »** : c'est ce qui permettra la re-signature sans
   câble.
3. Dans le menu AltServer : *Install AltStore → votre iPhone*, puis saisir
   votre identifiant Apple et son mot de passe (la validation à deux facteurs
   est demandée).
4. Sur l'iPhone : *Réglages → Général → VPN et gestion de l'appareil*, faire
   confiance au profil de votre compte. Si iOS le demande, activer le **mode
   développeur** (*Réglages → Confidentialité et sécurité*, puis redémarrage).
5. Ouvrir AltStore. L'onglet *My Apps* liste ce qu'il gère, avec les jours
   restants.

### 2. Installer Pellicule

1. Sur l'iPhone, ouvrir la page des versions :
   **<https://github.com/thibautbaxome/Pellicule/releases>** et télécharger le
   fichier `Pellicule.ipa` de la version la plus récente.
2. Dans AltStore, onglet *My Apps* : bouton **+**, puis choisir le fichier
   téléchargé (il est dans *Fichiers → Téléchargements*).
3. Attendre la fin de la signature. L'icône apparaît sur l'écran d'accueil.

### 3. Ensuite, rien

AltStore re-signe Pellicule tout seul, en tâche de fond, dès que l'iPhone et
l'ordinateur allumé partagent le même Wi-Fi. Si l'ordinateur est resté éteint
une semaine, ouvrez AltStore et touchez *Refresh All* — au Wi-Fi ou au câble.

### 4. Mettre à jour

Télécharger le nouvel `.ipa`, puis dans AltStore : **+** et le choisir. Il
s'installe par-dessus, **le carnet est conservé**.

Par prudence avant une mise à jour : *Réglages → Sauvegarde → Exporter le
carnet*. Le fichier obtenu vous appartient, et se relit avec « Importer un
carnet ».

## Autre méthode : un outil de chargement sur l'ordinateur

iLoader, Sideloadly et leurs semblables font la même chose qu'AltServer, en
une fois : ils signent l'`.ipa` et l'installent sur l'iPhone branché. C'est la
méthode la plus directe — c'est celle qui a servi à installer la version 0.2 —
mais rien ne re-signe l'application ensuite.

1. Télécharger `Pellicule.ipa` sur l'ordinateur depuis
   <https://github.com/thibautbaxome/Pellicule/releases>.
2. Brancher l'iPhone, le déverrouiller, accepter « Se fier à cet ordinateur ».
3. Dans l'outil : se connecter avec l'identifiant Apple, désigner le fichier,
   installer.
4. La première fois, sur l'iPhone : faire confiance au profil dans *Réglages →
   Général → VPN et gestion de l'appareil*, et activer le mode développeur
   si iOS le demande.

**Chaque semaine**, refaire les étapes 2 et 3 avec le même fichier : la
signature repart pour sept jours et le carnet reste en place. Pellicule vous
dit la date dans *Réglages → À propos* ; n'attendez pas le dernier jour. Une
mise à jour, c'est le même geste avec le nouvel `.ipa`.

Attention si vous passez ensuite à AltStore : il ne re-signe que ce qu'il a
installé lui-même. Exportez le carnet, installez Pellicule par AltStore, puis
importez le carnet si l'application repart vide.

## Option : SideStore, sans ordinateur

SideStore est un dérivé d'AltStore qui se re-signe **sans ordinateur**, par un
VPN local. C'est séduisant, mais sa connexion au compte Apple est capricieuse
— serveurs d'authentification tiers, échecs fréquents et peu explicites. Si
AltStore vous convient, restez-y. Sinon : **<https://docs.sidestore.io>**, puis
dans SideStore le même geste : **+**, choisir `Pellicule.ipa`.

## Si l'application refuse de s'ouvrir

Le plus souvent, la signature a expiré : réinstallez par la méthode que vous
employez, **le carnet est intact**.

Il reste de toute façon accessible en dehors de l'application. Ouvrez
**Fichiers**, *Sur mon iPhone*, dossier *Pellicule* : `carnet.json` s'y
trouve. Copiez-le avant toute autre manipulation.

L'application est écrite pour ne jamais écraser un carnet qu'elle n'a pas su
relire : en cas de problème de lecture, elle se bloque volontairement plutôt que
de repartir d'un carnet vide.

## Et sur Android, ou sur ordinateur ?

Rien pour l'instant. Le projet a délibérément abandonné sa version web pour
pouvoir mesurer la lumière avec la caméra et écrire les métadonnées directement
dans les scans, deux choses qu'un navigateur interdit. Le noyau de calcul est
séparé de l'interface et ne dépend d'aucune bibliothèque Apple : un portage
resterait possible, mais personne n'y travaille.
