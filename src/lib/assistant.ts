/**
 * Moteur de l'assistant de prise de vue.
 *
 * Le principe tient en une équation : une fois la lumière mesurée et la
 * sensibilité connue, vitesse et ouverture sont liées. On en fixe une, l'autre
 * suit. Tout le reste — profondeur de champ, risque de flou de bougé, sortie de
 * plage du boîtier — se déduit de ce couple.
 *
 * Ce module ne décide rien à la place du photographe : il rend visibles les
 * conséquences de chaque réglage, pour qu'un débutant comprenne pourquoi il
 * ferme à f/8 plutôt que de le faire parce qu'on le lui a dit.
 */

import { apertureToAv, secondsToShutter, shutterToSeconds } from './exposure';
import { depthOfField, hyperfocalDistance, type DepthOfFieldResult } from './depthOfField';
import type { ReciprocityModel } from '../db/types';
import { correctReciprocity, type ReciprocityResult } from './reciprocity';

// ---------------------------------------------------------------------------
// Intentions
// ---------------------------------------------------------------------------

export type Intent =
  | 'portrait'
  | 'landscape'
  | 'street'
  | 'action'
  | 'motion'
  | 'lowlight'
  | 'night';

export interface IntentSpec {
  id: Intent;
  label: string;
  /** Ce que l'intention impose ; l'autre variable s'ajuste. */
  drives: 'aperture' | 'shutter';
  /**
   * Valeur visée. Pour une ouverture, `'widest'` prend la plus grande
   * ouverture de l'objectif — c'est ce qu'on veut en portrait ou en basse
   * lumière, où elle dépend du matériel.
   */
  target: number | 'widest';
  /** Distance de mise au point conseillée, en mètres, ou l'hyperfocale. */
  distance: number | 'hyperfocal';
  /** Faux quand l'intention suppose un trépied. */
  handheld: boolean;
  /** Ce que l'intention cherche à obtenir, en une phrase. */
  goal: string;
}

export const INTENTS: IntentSpec[] = [
  {
    id: 'portrait',
    label: 'Portrait',
    drives: 'aperture',
    target: 'widest',
    distance: 2,
    handheld: true,
    goal: 'Détacher le sujet d’un arrière-plan fondu.',
  },
  {
    id: 'landscape',
    label: 'Paysage',
    drives: 'aperture',
    target: 11,
    distance: 'hyperfocal',
    handheld: true,
    goal: 'Tout net, du premier plan à l’horizon.',
  },
  {
    id: 'street',
    label: 'Rue',
    drives: 'aperture',
    target: 8,
    distance: 'hyperfocal',
    handheld: true,
    goal: 'Déclencher sans mettre au point, en comptant sur la zone de netteté.',
  },
  {
    id: 'action',
    label: 'Mouvement',
    drives: 'shutter',
    target: 1 / 500,
    distance: 5,
    handheld: true,
    goal: 'Figer un sujet qui bouge.',
  },
  {
    id: 'motion',
    label: 'Filé',
    drives: 'shutter',
    target: 1 / 30,
    distance: 5,
    handheld: true,
    goal: 'Suivre le sujet pour le garder net sur un fond filant.',
  },
  {
    id: 'lowlight',
    label: 'Basse lumière',
    drives: 'aperture',
    target: 'widest',
    distance: 3,
    handheld: true,
    goal: 'Récolter le maximum de lumière sans trépied.',
  },
  {
    id: 'night',
    label: 'Pose longue',
    drives: 'shutter',
    target: 4,
    distance: 'hyperfocal',
    handheld: false,
    goal: 'Laisser le temps travailler : filés d’eau, traînées lumineuses.',
  },
];

export const intentById = (id: Intent): IntentSpec =>
  INTENTS.find((intent) => intent.id === id) ?? INTENTS[0];

// ---------------------------------------------------------------------------
// Calcul du couple vitesse / ouverture
// ---------------------------------------------------------------------------

/** Indice de lumination de la scène pour la sensibilité employée. */
export const evAtIso = (ev100: number, iso: number): number => ev100 + Math.log2(iso / 100);

/** Temps de pose théorique pour une ouverture donnée, en secondes. */
export function shutterForAperture(ev100: number, iso: number, aperture: number): number {
  return Math.pow(2, apertureToAv(aperture) - evAtIso(ev100, iso));
}

/** Ouverture théorique pour un temps de pose donné. */
export function apertureForShutter(ev100: number, iso: number, seconds: number): number {
  const av = evAtIso(ev100, iso) + Math.log2(seconds);
  return Math.pow(2, av / 2);
}

/** Valeur de la graduation la plus proche d'une valeur théorique. */
export function nearestValue(scale: number[], value: number): number {
  if (scale.length === 0) return value;
  return scale.reduce((best, candidate) =>
    Math.abs(Math.log2(candidate) - Math.log2(value)) <
    Math.abs(Math.log2(best) - Math.log2(value))
      ? candidate
      : best,
  );
}

/** Vitesse de la graduation la plus proche d'une durée théorique. */
export function nearestShutter(scale: string[], seconds: number): string | null {
  let best: string | null = null;
  let bestError = Infinity;

  for (const label of scale) {
    const candidate = shutterToSeconds(label);
    if (candidate == null) continue;
    const error = Math.abs(Math.log2(candidate) - Math.log2(seconds));
    if (error < bestError) {
      bestError = error;
      best = label;
    }
  }
  return best;
}

/**
 * Restreint la graduation complète à ce que le boîtier sait faire.
 * Les bornes inconnues laissent la graduation intacte.
 */
export function shuttersForCamera(
  scale: string[],
  fastest?: string,
  slowest?: string,
): string[] {
  const fastestSec = shutterToSeconds(fastest);
  const slowestSec = shutterToSeconds(slowest);

  return scale.filter((label) => {
    const seconds = shutterToSeconds(label);
    if (seconds == null) return false;
    if (fastestSec != null && seconds < fastestSec - 1e-9) return false;
    if (slowestSec != null && seconds > slowestSec + 1e-9) return false;
    return true;
  });
}

// ---------------------------------------------------------------------------
// Conseils
// ---------------------------------------------------------------------------

export type AdviceLevel = 'good' | 'info' | 'warning' | 'danger';

export interface Advice {
  level: AdviceLevel;
  title: string;
  detail: string;
}

export interface AssistantInput {
  ev100: number;
  iso: number;
  aperture: number;
  focal: number;
  distance: number;
  circleOfConfusion: number;
  handheld: boolean;
  /** Vitesses réellement disponibles sur le boîtier. */
  availableShutters: string[];
  /** Ouvertures réellement disponibles sur l'objectif. */
  availableApertures: number[];
  reciprocity?: ReciprocityModel;
  /** Vitesse que l'intention cherche à obtenir, si elle en vise une. */
  desiredShutterSeconds?: number;
}

export interface AssistantResult {
  /** Temps de pose théorique, avant calage sur la graduation. */
  idealSeconds: number;
  /** Vitesse retenue sur le boîtier, ou null si la scène sort de sa plage. */
  shutter: string | null;
  shutterSeconds: number | null;
  /** Écart d'exposition dû au calage sur la graduation, en IL. */
  snapErrorStops: number;
  /** Vrai quand la scène est trop lumineuse pour l'obturateur le plus rapide. */
  tooBright: boolean;
  /** Vrai quand elle est trop sombre pour la vitesse la plus lente. */
  tooDark: boolean;
  dof: DepthOfFieldResult | null;
  hyperfocal: number;
  reciprocity: ReciprocityResult | null;
  /**
   * Ouverture à adopter pour ramener la pose dans la plage du boîtier.
   * Absente quand le réglage courant convient déjà, ou qu'aucune ouverture ne
   * suffit — auquel cas il faut un filtre ou un autre film.
   */
  suggestedAperture?: number;
  advice: Advice[];
}

/**
 * Vitesse plancher pour tenir l'appareil à la main : l'inverse de la focale.
 * Règle empirique, mais elle a fait ses preuves sur trois générations de
 * photographes, et elle reste juste tant qu'on ne tire pas en très grand.
 */
export const handheldLimitSeconds = (focal: number): number => 1 / Math.max(focal, 1);

export function advise(input: AssistantInput): AssistantResult {
  const {
    ev100, iso, aperture, focal, distance, circleOfConfusion,
    handheld, availableShutters, availableApertures, reciprocity, desiredShutterSeconds,
  } = input;

  const idealSeconds = shutterForAperture(ev100, iso, aperture);
  const shutter = nearestShutter(availableShutters, idealSeconds);
  const shutterSeconds = shutterToSeconds(shutter ?? undefined);

  // Les bornes de la graduation disponible disent si la scène sort de la
  // plage du boîtier : trop claire, ou trop sombre.
  const allSeconds = availableShutters
    .map((label) => shutterToSeconds(label))
    .filter((value): value is number => value != null);
  const fastestSec = allSeconds.length > 0 ? Math.min(...allSeconds) : null;
  const slowestSec = allSeconds.length > 0 ? Math.max(...allSeconds) : null;

  const tooBright = fastestSec != null && idealSeconds < fastestSec / 1.5;
  const tooDark = slowestSec != null && idealSeconds > slowestSec * 1.5;

  const snapErrorStops =
    shutterSeconds != null ? Math.log2(shutterSeconds / idealSeconds) : 0;

  // Dire « impossible » ne sert à rien sans dire quoi faire : on cherche
  // l'ouverture la plus proche qui ramène la pose dans la plage du boîtier.
  //
  // La tolérance vaut un tiers de diaphragme : sur un négatif, ce tiers ne se
  // voit pas, et il évite de conseiller f/16 quand f/11 suffisait — ce qui
  // ruinerait le flou d'arrière-plan qu'on cherchait justement.
  const THIRD_STOP = Math.pow(2, 1 / 6);
  let suggestedAperture: number | undefined;
  if (tooBright && fastestSec != null) {
    const needed = Math.pow(2, (evAtIso(ev100, iso) + Math.log2(fastestSec)) / 2);
    suggestedAperture = availableApertures.find((value) => value >= needed / THIRD_STOP);
  } else if (tooDark && slowestSec != null) {
    const limit = Math.pow(2, (evAtIso(ev100, iso) + Math.log2(slowestSec)) / 2);
    suggestedAperture = [...availableApertures]
      .reverse()
      .find((value) => value <= limit * THIRD_STOP);
  }

  const dof = depthOfField(focal, aperture, distance, circleOfConfusion);
  const hyperfocal = hyperfocalDistance(focal, aperture, circleOfConfusion);

  const effectiveSeconds = shutterSeconds ?? idealSeconds;
  const reciprocityResult =
    reciprocity && effectiveSeconds >= reciprocity.thresholdSec
      ? correctReciprocity(effectiveSeconds, reciprocity)
      : null;

  const advice: Advice[] = [];

  // --- Sortie de plage : le plus grave, donc en tête ---
  if (tooBright) {
    advice.push({
      level: 'danger',
      title: 'Trop de lumière pour ce réglage',
      detail: suggestedAperture
        ? `À ${formatApertureShort(aperture)}, il faudrait poser plus court que le ` +
          `${secondsToShutter(fastestSec ?? 0)} du boîtier. Fermez à ` +
          `${formatApertureShort(suggestedAperture)}.`
        : `Même au plus fermé, la scène est trop lumineuse pour cet obturateur. ` +
          `Il faut un filtre gris neutre, ou un film moins sensible.`,
    });
  }
  if (tooDark) {
    advice.push({
      level: 'danger',
      title: 'Pas assez de lumière',
      detail: suggestedAperture
        ? `À ${formatApertureShort(aperture)}, la pose dépasserait la vitesse la plus lente ` +
          `du boîtier. Ouvrez à ${formatApertureShort(suggestedAperture)}.`
        : `Même à pleine ouverture, il faudrait poser plus longtemps que le boîtier ne le ` +
          `permet. Passez en pose B sur trépied, ou chargez un film plus sensible.`,
    });
  }

  // --- L'intention vise une vitesse que la lumière ne permet pas ---
  // Seulement quand la pose tient dans la plage du boîtier : hors plage,
  // l'écart ne vient pas de la lumière mais des limites de l'obturateur, et
  // l'avertissement précédent le dit déjà — plus justement. Sans ce garde-fou,
  // un boîtier qui plafonne à la seconde affichait « pas assez de lumière » et
  // « trop de lumière pour poser aussi longtemps » côte à côte.
  if (!tooBright && !tooDark && desiredShutterSeconds != null && shutterSeconds != null) {
    const gap = Math.log2(shutterSeconds / desiredShutterSeconds);
    if (gap < -1) {
      advice.push({
        level: 'warning',
        title: 'Trop de lumière pour poser aussi longtemps',
        detail:
          `Cette intention vise ${secondsToShutter(desiredShutterSeconds)} ; même à ` +
          `${formatApertureShort(Math.max(...availableApertures))}, la scène impose ` +
          `${secondsToShutter(shutterSeconds)}. Il faut un filtre gris neutre, ou attendre ` +
          `que la lumière baisse.`,
      });
    } else if (gap > 1) {
      advice.push({
        level: 'warning',
        title: 'Pas assez de lumière pour cette vitesse',
        detail:
          `Cette intention vise ${secondsToShutter(desiredShutterSeconds)} ; la scène ne ` +
          `permet que ${secondsToShutter(shutterSeconds)} à pleine ouverture. Montez en ` +
          `sensibilité, ou acceptez le flou.`,
      });
    }
  }

  // --- Flou de bougé ---
  if (handheld && shutterSeconds != null) {
    const limit = handheldLimitSeconds(focal);
    if (shutterSeconds > limit * 2) {
      advice.push({
        level: 'danger',
        title: 'Flou de bougé quasi certain',
        detail:
          `À ${focal} mm, on ne tient guère en dessous du ${secondsToShutter(limit)}. ` +
          `Cherchez un appui, ou un trépied.`,
      });
    } else if (shutterSeconds > limit * 1.05) {
      advice.push({
        level: 'warning',
        title: 'Risque de flou de bougé',
        detail:
          `La règle du 1/focale conseille au moins le ${secondsToShutter(limit)} à ${focal} mm. ` +
          `Calez vos coudes et déclenchez en fin d’expiration.`,
      });
    }
  }

  // --- Calage sur la graduation ---
  // Sans objet quand la scène sort déjà de la plage du boîtier : l'écart ne
  // vient alors pas d'un arrondi mais d'un réglage irréalisable, déjà signalé.
  if (!tooBright && !tooDark && Math.abs(snapErrorStops) > 0.34) {
    advice.push({
      level: 'info',
      title: 'Exposition arrondie',
      detail:
        `La graduation du boîtier tombe à ${Math.abs(Math.round(snapErrorStops * 10) / 10)} IL ` +
        `de l’exposition idéale, ${snapErrorStops > 0 ? 'en excès' : 'en défaut'}. ` +
        `Sans conséquence sur un négatif, à surveiller sur une diapositive.`,
    });
  }

  // --- Réciprocité ---
  if (reciprocityResult && !reciprocityResult.belowThreshold) {
    advice.push({
      level: 'warning',
      title: 'Défaut de réciprocité',
      detail:
        `Sur une pose de cette durée, l’émulsion perd en sensibilité : posez plutôt ` +
        `${formatSeconds(reciprocityResult.correctedSec)}.` +
        (reciprocityResult.colorShiftNote ? ` ${reciprocityResult.colorShiftNote}` : ''),
    });
  }

  // --- Le film est trop sensible pour la lumière ---
  // Fermer n'est qu'un pis-aller : ce qui empêche d'ouvrir en plein soleil,
  // c'est d'avoir chargé un film rapide. Le dire vaut mieux que le taire.
  if (tooBright && suggestedAperture != null && suggestedAperture >= 11 && iso >= 400) {
    advice.push({
      level: 'info',
      title: 'Film un peu rapide pour cette lumière',
      detail:
        `À ${iso} ISO en pleine lumière, il faut fermer beaucoup, et l’arrière-plan reste ` +
        `net malgré vous. Un film de 100 ISO, ou un filtre gris neutre, rendrait les ` +
        `grandes ouvertures accessibles.`,
    });
  }

  // --- Diffraction ---
  if (aperture >= 16) {
    advice.push({
      level: 'info',
      title: 'Diffraction',
      detail:
        `Au-delà de f/11, la profondeur de champ gagne encore, mais l’image perd en finesse. ` +
        `Sur un tirage moyen, cela reste invisible.`,
    });
  }

  // --- Pleine ouverture ---
  const widest = Math.min(...availableApertures);
  if (aperture <= widest + 0.05 && availableApertures.length > 1) {
    advice.push({
      level: 'info',
      title: 'Pleine ouverture',
      detail:
        `La plupart des objectifs anciens manquent un peu de piqué et vignettent à pleine ` +
        `ouverture. Fermer d’un diaphragme suffit souvent à tout rattraper.`,
    });
  }

  // --- Zone de netteté, quand elle est remarquable ---
  if (dof) {
    if (dof.farIsInfinite && distance >= hyperfocal * 0.9) {
      advice.push({
        level: 'good',
        title: 'Net jusqu’à l’infini',
        detail:
          `Mise au point à l’hyperfocale : tout est net de ${formatMeters(dof.near)} à l’infini. ` +
          `Vous pouvez déclencher sans refaire le point.`,
      });
    } else if (dof.total < 0.35) {
      advice.push({
        level: 'info',
        title: 'Zone de netteté très mince',
        detail:
          `Moins de ${Math.round(dof.total * 100)} cm de net. Superbe pour isoler un regard, ` +
          `impitoyable si la mise au point dérape.`,
      });
    }
  }

  return {
    idealSeconds,
    shutter,
    shutterSeconds,
    snapErrorStops,
    tooBright,
    tooDark,
    dof,
    hyperfocal,
    reciprocity: reciprocityResult,
    suggestedAperture,
    advice,
  };
}

/**
 * Ouverture de départ pour une intention, ramenée à ce que l'objectif permet.
 *
 * Quand l'intention pilote la vitesse — figer un mouvement, filer, poser
 * longuement — c'est l'ouverture qui doit s'y plier : on la déduit de la
 * lumière et du temps visé. Le résultat est ensuite calé sur la graduation de
 * l'objectif, et borné à ses ouvertures extrêmes : en plein jour, une pose de
 * quatre secondes reste hors d'atteinte sans filtre, et l'assistant le dira.
 */
export function apertureForIntent(
  spec: IntentSpec,
  availableApertures: number[],
  ev100: number,
  iso: number,
): number {
  if (availableApertures.length === 0) return 8;
  if (spec.target === 'widest') return Math.min(...availableApertures);

  if (spec.drives === 'aperture') return nearestValue(availableApertures, spec.target);

  const wanted = apertureForShutter(ev100, iso, spec.target as number);
  const widest = Math.min(...availableApertures);
  const narrowest = Math.max(...availableApertures);
  return nearestValue(availableApertures, Math.min(Math.max(wanted, widest), narrowest));
}

/** Distance de mise au point conseillée par l'intention. */
export function distanceForIntent(
  spec: IntentSpec,
  focal: number,
  aperture: number,
  circleOfConfusion: number,
): number {
  if (spec.distance === 'hyperfocal') {
    return hyperfocalDistance(focal, aperture, circleOfConfusion);
  }
  return spec.distance;
}

const formatApertureShort = (aperture: number): string =>
  `f/${Number.isInteger(aperture) ? aperture : Math.round(aperture * 10) / 10}`;

const formatSeconds = (seconds: number): string =>
  seconds >= 60
    ? `${Math.floor(seconds / 60)} min ${String(Math.round(seconds % 60)).padStart(2, '0')} s`
    : `${(Math.round(seconds * 10) / 10).toLocaleString('fr-FR')} s`;

const formatMeters = (meters: number): string =>
  meters < 1 ? `${Math.round(meters * 100)} cm` : `${(Math.round(meters * 10) / 10).toLocaleString('fr-FR')} m`;
