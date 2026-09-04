/**
 * Profondeur de champ et hyperfocale, formules classiques de l'optique
 * géométrique. Distances en mètres, focales en millimètres.
 *
 * Le cercle de confusion par défaut vaut 0,03 mm, la valeur retenue pour le
 * 24×36 : c'est le diamètre du plus petit point encore perçu comme net sur un
 * tirage 20×25 cm observé à distance normale. Un tirage plus grand, ou un
 * examen à la loupe du négatif, demande une valeur plus sévère.
 */

export interface DepthOfFieldResult {
  /** Distance hyperfocale en mètres. */
  hyperfocal: number;
  /** Limite de netteté la plus proche, en mètres. */
  near: number;
  /** Limite de netteté la plus lointaine, en mètres. Infinity le cas échéant. */
  far: number;
  /** Étendue de la zone nette en mètres. Infinity si `far` est infini. */
  total: number;
  /** Vrai quand la mise au point atteint ou dépasse l'hyperfocale. */
  farIsInfinite: boolean;
}

export function depthOfField(
  focalMm: number,
  aperture: number,
  subjectDistanceM: number,
  circleOfConfusionMm = 0.03,
): DepthOfFieldResult | null {
  if (
    !Number.isFinite(focalMm) || focalMm <= 0 ||
    !Number.isFinite(aperture) || aperture <= 0 ||
    !Number.isFinite(subjectDistanceM) || subjectDistanceM <= 0 ||
    !Number.isFinite(circleOfConfusionMm) || circleOfConfusionMm <= 0
  ) {
    return null;
  }

  // Tout le calcul se fait en millimètres, puis on revient aux mètres.
  const f = focalMm;
  const s = subjectDistanceM * 1000;
  const hyperfocalMm = (f * f) / (aperture * circleOfConfusionMm) + f;

  const nearMm = (s * (hyperfocalMm - f)) / (hyperfocalMm + s - 2 * f);

  // Au-delà de l'hyperfocale, la limite lointaine part à l'infini : le
  // dénominateur s'annule puis change de signe.
  const denominator = hyperfocalMm - s;
  const farIsInfinite = denominator <= 0;
  const farMm = farIsInfinite ? Infinity : (s * (hyperfocalMm - f)) / denominator;

  const near = nearMm / 1000;
  const far = farIsInfinite ? Infinity : farMm / 1000;

  return {
    hyperfocal: hyperfocalMm / 1000,
    near,
    far,
    total: farIsInfinite ? Infinity : far - near,
    farIsInfinite,
  };
}

/** Distance hyperfocale seule, en mètres. */
export function hyperfocalDistance(
  focalMm: number,
  aperture: number,
  circleOfConfusionMm = 0.03,
): number {
  return ((focalMm * focalMm) / (aperture * circleOfConfusionMm) + focalMm) / 1000;
}

/** Affiche une distance avec une précision adaptée à sa grandeur. */
export function formatDistance(meters: number): string {
  if (!Number.isFinite(meters)) return '∞';
  if (meters < 1) return `${Math.round(meters * 100)} cm`;
  if (meters < 10) return `${(Math.round(meters * 10) / 10).toLocaleString('fr-FR')} m`;
  return `${Math.round(meters).toLocaleString('fr-FR')} m`;
}

/**
 * Facteur de tirage (compensation de soufflet).
 *
 * En macro, l'objectif s'éloigne du plan film et l'éclairement chute. La
 * correction dépend du rapport de grandissement m : le facteur vaut (1+m)²,
 * soit 2·log2(1+m) en IL. Négligeable en dessous de 1:10, décisif au rapport 1:1
 * (deux diaphragmes).
 */
export function bellowsCompensationStops(magnification: number): number {
  if (!Number.isFinite(magnification) || magnification < 0) return 0;
  return 2 * Math.log2(1 + magnification);
}

/** Grandissement déduit de la focale et de la distance de mise au point. */
export function magnificationFrom(focalMm: number, subjectDistanceM: number): number {
  const s = subjectDistanceM * 1000;
  if (s <= focalMm) return 0;
  return focalMm / (s - focalMm);
}
