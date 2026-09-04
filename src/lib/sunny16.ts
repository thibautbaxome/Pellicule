/**
 * Règle du f/16 (« Sunny 16 »), le posemètre de secours qui ne tombe jamais
 * en panne de pile.
 *
 * En plein soleil, à f/16, le temps de pose correct vaut l'inverse de la
 * sensibilité du film : 1/125 s à f/16 pour du 125 ISO. Chaque condition de
 * lumière moins favorable ouvre d'un diaphragme.
 */

import { APERTURES_FULL, secondsToShutter } from './exposure';

export interface LightCondition {
  id: string;
  label: string;
  /** Ouverture à employer quand le temps vaut 1/ISO. */
  aperture: number;
  description: string;
  /** Indice de lumination à 100 ISO, à titre de repère. */
  ev100: number;
}

export const LIGHT_CONDITIONS: LightCondition[] = [
  {
    id: 'snow-sand',
    label: 'Neige ou sable',
    aperture: 22,
    description: 'Surface très réfléchissante en plein soleil, ombres dures et découpées.',
    ev100: 16,
  },
  {
    id: 'sunny',
    label: 'Plein soleil',
    aperture: 16,
    description: 'Ciel dégagé, ombres nettes aux contours francs.',
    ev100: 15,
  },
  {
    id: 'slight-overcast',
    label: 'Soleil voilé',
    aperture: 11,
    description: 'Ombres présentes mais aux bords adoucis.',
    ev100: 14,
  },
  {
    id: 'overcast',
    label: 'Nuageux',
    aperture: 8,
    description: 'Ombres à peine perceptibles.',
    ev100: 13,
  },
  {
    id: 'heavy-overcast',
    label: 'Très couvert',
    aperture: 5.6,
    description: 'Plus aucune ombre portée, lumière parfaitement diffuse.',
    ev100: 12,
  },
  {
    id: 'open-shade',
    label: 'Ombre ouverte',
    aperture: 4,
    description: 'À l’ombre d’un bâtiment sous un ciel clair, ou coucher de soleil.',
    ev100: 11,
  },
];

export interface Sunny16Suggestion {
  aperture: number;
  shutter: string;
  seconds: number;
}

/**
 * Décline une condition de lumière en tous les couples vitesse/ouverture
 * équivalents, pour choisir celui qui convient à la scène.
 */
export function sunny16Suggestions(
  iso: number,
  condition: LightCondition,
  exposureCompStops = 0,
): Sunny16Suggestion[] {
  if (!Number.isFinite(iso) || iso <= 0) return [];

  // Point de départ : 1/ISO à l'ouverture de la condition, décalé de la
  // correction demandée.
  const baseSeconds = (1 / iso) * Math.pow(2, exposureCompStops);

  return APERTURES_FULL.filter((a) => a >= 1.4 && a <= 32).map((aperture) => {
    // Fermer d'un diaphragme depuis l'ouverture de référence double le temps.
    const stopsFromReference = Math.log2((aperture * aperture) / (condition.aperture * condition.aperture));
    const seconds = baseSeconds * Math.pow(2, stopsFromReference);
    return { aperture, seconds, shutter: secondsToShutter(seconds) };
  });
}

/** Indice de lumination d'une condition pour une sensibilité donnée. */
export function evForCondition(condition: LightCondition, iso: number): number {
  return condition.ev100 + Math.log2(iso / 100);
}
