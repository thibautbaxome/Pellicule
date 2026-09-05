# Pellicule

Carnet de prise de vue argentique pour iPhone. Application web installable sur
l'écran d'accueil, entièrement hors ligne, sans compte ni serveur : toutes les
données restent dans le téléphone.

Format pris en charge : **135 (24×36)**.

## Pourquoi une application web

Une application iOS compilée avec un compte Apple gratuit doit être réinstallée
tous les sept jours depuis un Mac. Une application web installée depuis Safari
via « Sur l'écran d'accueil » n'expire jamais, ne demande ni Mac, ni Xcode, ni
signature, et se met à jour au simple déploiement. Elle obtient une icône, le
plein écran sans barre de navigation, l'accès à l'appareil photo et à la
géolocalisation, et un stockage local persistant.

## Ce que l'application fait

**Matériel.** Boîtiers (monture, numéro de série, décalage du posemètre) et
objectifs (focale, ouvertures extrêmes, diamètre de filtre). Les ouvertures
extrêmes restreignent la graduation proposée à la saisie.

**Pellicules.** Une cinquantaine d'émulsions 135 préchargées — noir et blanc,
négatif couleur, diapositive — avec sensibilité nominale, procédé, courbe de
réciprocité et, pour les principales, des temps de développement de référence.
Le catalogue est modifiable et extensible ; les entrées livrées portent un
identifiant stable, de sorte qu'une mise à jour de l'application n'écrase jamais
une fiche retouchée.

**Rouleaux.** Chargement (pellicule, boîtier, sensibilité employée, nombre de
poses), suivi du cycle de vie — chargé, en cours, terminé, au labo, développé,
scanné, archivé — référence d'archive, laboratoire, coûts détaillés.
Le push/pull est calculé automatiquement à partir de l'écart entre la
sensibilité employée et l'ISO de la boîte.

**Vues.** Saisie en deux gestes : graduations de vitesse et d'ouverture qui
défilent sous le pouce, réglages de la vue précédente repris par défaut,
numérotation automatique. Un bouton déplie le reste : correction d'exposition,
filtre, distance, flash, mesure, conditions de lumière, mots-clés, notes. La
position GPS est relevée automatiquement, et une photo de repérage prise à
l'iPhone peut être jointe pour se rappeler le cadrage. Une pose longue affiche
immédiatement la correction de réciprocité du film chargé.

**Développement.** Journal par rouleau : révélateur, dilution, temps,
température, agitation. Le temps est suggéré à partir des données du film, de
la température du bain et du push/pull du rouleau.

**Assistant de prise de vue.** L'écran central de l'aide à la décision. On y
déclare une intention — portrait, paysage, rue, mouvement, filé, basse lumière,
pose longue — et une condition de lumière ; l'application en déduit le couple
vitesse/ouverture et l'affiche en gros, épinglé en haut de l'écran. Les
curseurs d'ouverture, de distance et de focale le recalculent en direct, avec
la zone de netteté représentée sur une échelle logarithmique.

Tout est borné par le matériel réellement déclaré : les vitesses proposées sont
celles du boîtier, les ouvertures celles de l'objectif. Quand la scène sort de
ces limites, l'application ne se contente pas de le signaler — elle propose la
correction, applicable d'un geste, et explique ce qui coince : un film trop
rapide pour la lumière, un besoin de filtre gris neutre, un risque de flou de
bougé au regard de la règle du 1/focale.

**Calculateurs.** Derrière l'assistant, le détail : règle du f/16, correction de
réciprocité, profondeur de champ et hyperfocale, facteurs de filtre cumulés,
correction du temps de développement.

**Banques de matériel.** Plus de 150 boîtiers 135 référencés — reflex,
télémétriques, compacts — avec monture, plage de vitesses et objectif solidaire,
plus un catalogue d'objectifs filtré par monture. On cherche son appareil, on le
sélectionne, les caractéristiques se remplissent. Rien n'est imposé : un modèle
absent se déclare à la main comme avant.

**Export vers les scans.** Un CSV pour `exiftool`, un script shell prêt à
lancer, ou un CSV lisible dans un tableur. Les scans du laboratoire récupèrent
ainsi le boîtier, l'objectif, la focale, la vitesse, l'ouverture, la date et le
lieu réels de la prise de vue, et se comportent dès lors comme des photos
numériques dans n'importe quelle photothèque.

**Sauvegarde.** Fichier JSON complet, photos comprises ou non, à déposer dans
iCloud Drive par la feuille de partage. Restauration au choix par remplacement
ou par fusion.

## Parti pris visuel

Néo-rétro argentique : le vocabulaire graphique vient du matériel lui-même —
noir chaud des boîtiers en peinture martelée, blanc cassé du papier baryté,
ambre de la lampe inactinique, perforations 135 comme motif structurant, voile
de grain sur l'ensemble.

Deux règles portent le système : les valeurs chiffrées sont en monospace
tabulaire, espacées comme les graduations gravées d'une bague d'objectif ; les
micro-libellés sont en capitales largement interlettrées, à la manière des
mentions imprimées sur une boîte de film.

Les polices — Space Grotesk pour l'interface, Space Mono pour les chiffres —
sont auto-hébergées dans `src/fonts/`, sans quoi l'application ne s'afficherait
pas correctement hors ligne. Les icônes sont dessinées dans
`src/components/icons.tsx` : le vocabulaire dont l'application a besoin — une
amorce de pellicule, un diaphragme, une cellule — n'existe dans aucune
bibliothèque.

Quatre thèmes : sombre par défaut, clair en planche contact sur papier crème,
automatique, et chambre noire entièrement rouge.

## Développement

```sh
npm install
npm run dev          # serveur de développement
npm run build        # build de production dans dist/
npm run preview      # sert le build sur http://127.0.0.1:4173
npm run lint
```

Parcours de bout en bout dans un iPhone simulé, avec captures d'écran à chaque
étape et échec à la moindre erreur de console — le serveur de prévisualisation
doit tourner :

```sh
npm run smoke
```

Régénérer les icônes après modification du motif :

```sh
python3 tools/make-icons.py
```

## Déploiement

L'application est un site statique : `npm run build` produit `dist/`, qu'il
suffit de servir en HTTPS. Aucune base, aucune API, rien à configurer côté
serveur — l'hébergement ne livre que le code, jamais les données.

Le plus simple est **Cloudflare Pages** connecté au dépôt : commande de build
`npm run build`, dossier de sortie `dist`, chaque poussée redéploie. Netlify et
Vercel fonctionnent à l'identique. Le fichier `public/_headers` règle déjà les
en-têtes de cache — le service worker ne doit jamais être mis en cache, faute
de quoi les appareils déjà installés se figent sur une vieille version.

GitHub Pages convient aussi, mais publie le site en clair et exige un abonnement
payant pour un dépôt privé.

Pour restreindre l'accès, Cloudflare Access place le site derrière un code reçu
par courriel. À n'activer qu'en connaissance de cause : une page protégée par
authentification se marie mal avec l'installation sur l'écran d'accueil et le
fonctionnement hors ligne. Comme aucune donnée personnelle ne transite par
l'hébergeur, laisser l'URL accessible n'expose que le code source.

## Installation sur l'iPhone

1. Ouvrir l'adresse du site **dans Safari** (Chrome iOS ne sait pas installer
   de PWA).
2. Bouton Partager, puis **Sur l'écran d'accueil**.
3. Lancer l'application depuis son icône, puis, dans Réglages, **Rendre le
   stockage persistant** — iOS accorde alors la persistance sans invite et ne
   purgera plus les données après une période d'inactivité.

Une fois installée, l'application fonctionne sans réseau. Le réseau ne sert
qu'à récupérer une nouvelle version.

## Architecture

```
src/
  db/       modèle de données, base Dexie (IndexedDB), catalogue de pellicules
  lib/      calculs argentiques, formatage, export, sauvegarde, médias, GPS
  hooks/    requêtes réactives sur la base, réglages et thème
  components/  briques d'interface partagées
  screens/  un fichier par écran
tools/      génération des icônes, parcours de test
```

Aucun état global : les écrans lisent la base par `useLiveQuery`, et toute
écriture rafraîchit l'affichage. Le routage se fait par fragment d'URL
(`HashRouter`), ce qui permet d'héberger l'application n'importe où sans
réécriture côté serveur et de recharger une page profonde hors ligne.

## Ce que l'application ne peut pas faire

**Mesurer la lumière avec la caméra de l'iPhone.** Un navigateur n'a pas accès
à la luminance absolue d'une scène : la caméra corrige son exposition en
continu, si bien que la clarté moyenne d'une image reste constante quelle que
soit la lumière réelle. La seule méthode exacte consiste à lire les réglages
que la caméra a elle-même retenus — temps de pose et sensibilité. Chrome les
publie sur Android, WebKit non : sur iPhone, la mesure est donc impossible, et
l'application le dit au lieu d'afficher un chiffre inventé.

L'estimation par la scène reste fiable — c'est ainsi qu'on a exposé pendant un
siècle — et une cellule à main ou le posemètre du boîtier prennent le relais
quand la précision compte.

## Réserves sur les calculs

Les exposants de réciprocité viennent des notices des fabricants quand elles
les publient, de l'interpolation de leurs tables sinon. La correction de
température du développement suit un coefficient de 2,5 pour 10 °C, et le push
allonge d'environ 35 % par diaphragme. Ces modèles reproduisent les tables
publiées à quelques pourcents près : ils cadrent une décision sur le terrain,
ils ne remplacent pas la notice du film ni, après quelques rouleaux, vos
propres relevés.
