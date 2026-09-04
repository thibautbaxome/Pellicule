/**
 * Correction de réciprocité (défaut de Schwarzschild).
 *
 * En pose longue, l'émulsion perd en sensibilité : doubler le temps ne double
 * plus la densité. La correction usuelle, publiée telle quelle par Ilford et
 * approchée à partir des tables des autres fabricants, s'écrit
 *
 *     t_corrigé = t_mesuré ^ p
 *
 * avec t en secondes et p l'exposant propre à l'émulsion. En dessous du seuil
 * du film, la correction est négligeable et n'est pas appliquée.
 */

import type { ReciprocityModel } from '../db/types';
import { secondsToShutter } from './exposure';

export interface ReciprocityResult {
  /** Temps mesuré par la cellule, en secondes. */
  measuredSec: number;
  /** Temps réellement à appliquer, en secondes. */
  correctedSec: number;
  /** Supplément d'exposition, en IL. */
  extraStops: number;
  /** Vrai si la pose est trop courte pour que la correction s'applique. */
  belowThreshold: boolean;
  colorShiftNote?: string;
}

export function correctReciprocity(
  measuredSec: number,
  model: ReciprocityModel,
): ReciprocityResult {
  if (!Number.isFinite(measuredSec) || measuredSec <= 0) {
    return { measuredSec: 0, correctedSec: 0, extraStops: 0, belowThreshold: true };
  }

  const belowThreshold = measuredSec < model.thresholdSec || model.exponent <= 1;
  const correctedSec = belowThreshold
    ? measuredSec
    : Math.pow(measuredSec, model.exponent);

  return {
    measuredSec,
    correctedSec,
    extraStops: Math.log2(correctedSec / measuredSec),
    belowThreshold,
    colorShiftNote: model.colorShiftNote,
  };
}

/**
 * Met une durée sous une forme lisible sur le terrain : on ne déclenche pas
 * une pose de 754 secondes, on déclenche « 12 min 34 s ».
 */
export function formatDuration(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return '—';
  if (seconds < 1) return secondsToShutter(seconds);
  if (seconds < 60) {
    return `${seconds < 10 ? Math.round(seconds * 10) / 10 : Math.round(seconds)} s`;
  }

  const total = Math.round(seconds);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const secs = total % 60;

  if (hours > 0) return `${hours} h ${String(minutes).padStart(2, '0')} min`;
  return secs === 0 ? `${minutes} min` : `${minutes} min ${String(secs).padStart(2, '0')} s`;
}
