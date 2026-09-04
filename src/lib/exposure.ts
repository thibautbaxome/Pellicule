/**
 * Échelles d'exposition argentiques.
 *
 * Tout le raisonnement passe par l'IL (indice de lumination, « stop » en
 * anglais) : une valeur en IL vaut log2 du temps ou du carré de l'ouverture,
 * ce qui rend les additions triviales et évite de manipuler des fractions.
 */

import type { StopIncrement } from '../db/types';

// ---------------------------------------------------------------------------
// Vitesses d'obturation
// ---------------------------------------------------------------------------

/**
 * Vitesses de la graduation normalisée, de la plus lente à la plus rapide.
 * Les valeurs sont les libellés canoniques stockés dans `Frame.shutter`.
 */
export const SHUTTER_SPEEDS_FULL = [
  '30s', '15s', '8s', '4s', '2s', '1s',
  '1/2', '1/4', '1/8', '1/15', '1/30', '1/60', '1/125', '1/250',
  '1/500', '1/1000', '1/2000', '1/4000', '1/8000',
] as const;

/** Demi-valeurs intercalées entre les vitesses pleines. */
export const SHUTTER_SPEEDS_HALF = [
  '45s', '30s', '20s', '15s', '10s', '8s', '6s', '4s', '3s', '2s', '1.5s', '1s',
  '1/1.5', '1/2', '1/3', '1/4', '1/6', '1/8', '1/10', '1/15', '1/20', '1/30',
  '1/45', '1/60', '1/90', '1/125', '1/180', '1/250', '1/350', '1/500',
  '1/750', '1/1000', '1/1500', '1/2000', '1/3000', '1/4000', '1/6000', '1/8000',
] as const;

/** Tiers de valeur, la graduation des boîtiers électroniques. */
export const SHUTTER_SPEEDS_THIRD = [
  '30s', '25s', '20s', '15s', '13s', '10s', '8s', '6s', '5s', '4s', '3.2s',
  '2.5s', '2s', '1.6s', '1.3s', '1s', '1/1.3', '1/1.6', '1/2', '1/2.5',
  '1/3', '1/4', '1/5', '1/6', '1/8', '1/10', '1/13', '1/15', '1/20', '1/25',
  '1/30', '1/40', '1/50', '1/60', '1/80', '1/100', '1/125', '1/160', '1/200',
  '1/250', '1/320', '1/400', '1/500', '1/640', '1/800', '1/1000', '1/1250',
  '1/1600', '1/2000', '1/2500', '1/3200', '1/4000', '1/5000', '1/6400', '1/8000',
] as const;

/** Pose B (bulb) : le temps dépend du photographe, pas de la graduation. */
export const BULB = 'B';

export function shutterScale(increment: StopIncrement): string[] {
  switch (increment) {
    case 'half':
      return [...SHUTTER_SPEEDS_HALF];
    case 'third':
      return [...SHUTTER_SPEEDS_THIRD];
    default:
      return [...SHUTTER_SPEEDS_FULL];
  }
}

/**
 * Convertit un libellé de vitesse en secondes.
 * Rend `null` pour la pose B et pour tout libellé non reconnu.
 */
export function shutterToSeconds(shutter: string | undefined): number | null {
  if (!shutter) return null;
  const s = shutter.trim();
  if (s.toUpperCase() === BULB || s === '') return null;

  if (s.startsWith('1/')) {
    const denom = Number(s.slice(2));
    return Number.isFinite(denom) && denom > 0 ? 1 / denom : null;
  }
  const value = Number(s.replace(/s$/i, '').replace(',', '.'));
  return Number.isFinite(value) && value > 0 ? value : null;
}

/**
 * Met un nombre de secondes sous forme de libellé lisible, en visant la
 * graduation habituelle (1/125 plutôt que 0,008 s).
 */
export function secondsToShutter(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return '';
  if (seconds >= 1) {
    const rounded = seconds >= 10 ? Math.round(seconds) : Math.round(seconds * 10) / 10;
    return `${rounded}s`;
  }
  const denom = 1 / seconds;
  // Les dénominateurs sous 10 gardent une décimale (1/1,6 est une vraie
  // graduation), au-delà on arrondit à l'entier.
  const shown = denom < 10 ? Math.round(denom * 10) / 10 : Math.round(denom);
  return `1/${shown}`;
}

// ---------------------------------------------------------------------------
// Ouvertures
// ---------------------------------------------------------------------------

export const APERTURES_FULL = [
  1, 1.4, 2, 2.8, 4, 5.6, 8, 11, 16, 22, 32, 45, 64,
];

export const APERTURES_HALF = [
  1, 1.2, 1.4, 1.7, 2, 2.4, 2.8, 3.3, 4, 4.8, 5.6, 6.7, 8, 9.5, 11, 13,
  16, 19, 22, 27, 32, 38, 45, 54, 64,
];

export const APERTURES_THIRD = [
  1, 1.1, 1.2, 1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5, 4, 4.5, 5, 5.6,
  6.3, 7.1, 8, 9, 10, 11, 13, 14, 16, 18, 20, 22, 25, 29, 32, 36, 40, 45,
  51, 57, 64,
];

export function apertureScale(increment: StopIncrement): number[] {
  switch (increment) {
    case 'half':
      return [...APERTURES_HALF];
    case 'third':
      return [...APERTURES_THIRD];
    default:
      return [...APERTURES_FULL];
  }
}

/** Affiche une ouverture sans décimale inutile : f/5.6, f/8, f/1.4. */
export function formatAperture(aperture: number | undefined): string {
  if (aperture == null || !Number.isFinite(aperture)) return '—';
  const shown = Number.isInteger(aperture) ? aperture : Math.round(aperture * 10) / 10;
  return `f/${shown}`;
}

/**
 * Restreint une échelle d'ouvertures à ce qu'un objectif permet réellement.
 * Une tolérance d'un dixième absorbe les valeurs nominales arrondies des
 * fabricants (un 50/1,8 vaut 1,78 en réalité).
 */
export function aperturesForLens(
  scale: number[],
  maxAperture?: number,
  minAperture?: number,
): number[] {
  return scale.filter(
    (a) =>
      (maxAperture == null || a >= maxAperture - 0.1) &&
      (minAperture == null || a <= minAperture + 0.1),
  );
}

// ---------------------------------------------------------------------------
// Conversions en IL
// ---------------------------------------------------------------------------

/** Valeur d'ouverture Av = 2·log2(N). f/1 vaut 0, f/1,4 vaut 1, f/2 vaut 2... */
export const apertureToAv = (aperture: number): number => 2 * Math.log2(aperture);

/** Valeur de temps Tv = −log2(t). 1 s vaut 0, 1/2 s vaut 1, 1/125 s vaut ~7. */
export const secondsToTv = (seconds: number): number => -Math.log2(seconds);

/**
 * Indice de lumination d'un couple vitesse/ouverture, à ISO 100 par
 * convention. EV = Av + Tv, décalé de log2(ISO/100) pour une autre
 * sensibilité.
 */
export function exposureValue(aperture: number, seconds: number, iso = 100): number {
  return apertureToAv(aperture) + secondsToTv(seconds) - Math.log2(iso / 100);
}

/** Écart en IL entre la sensibilité employée et l'ISO nominal du film. */
export function pushPullStops(shotIso: number, boxIso: number): number {
  if (!shotIso || !boxIso) return 0;
  return Math.log2(shotIso / boxIso);
}

/** Met un écart en IL sous forme lisible : « +2 IL », « −1,5 IL ». */
export function formatStops(stops: number, unit = 'IL'): string {
  const rounded = Math.round(stops * 10) / 10;
  if (Math.abs(rounded) < 0.05) return `0 ${unit}`;
  const sign = rounded > 0 ? '+' : '−';
  return `${sign}${Math.abs(rounded).toLocaleString('fr-FR')} ${unit}`;
}

/** Étiquette courte du push/pull d'un rouleau, ou null s'il est exposé nominal. */
export function pushPullLabel(shotIso: number, boxIso: number): string | null {
  const stops = pushPullStops(shotIso, boxIso);
  if (Math.abs(stops) < 0.05) return null;
  const rounded = Math.round(stops * 10) / 10;
  return rounded > 0 ? `push +${rounded}` : `pull ${rounded}`;
}
