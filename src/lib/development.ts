/**
 * Correction des temps de développement.
 *
 * Deux corrections se combinent : la température du bain et l'écart de
 * sensibilité (push/pull). Les modèles retenus reproduisent à quelques
 * pourcents près les tables publiées par Kodak et Ilford, mais chaque
 * couple film/révélateur a ses habitudes — le résultat est un point de
 * départ à ajuster au fil des rouleaux.
 */

/**
 * Coefficient de température. Un facteur 2,5 par tranche de 10 °C reproduit
 * les tables classiques : la référence D-76 de 7 min à 20 °C tombe bien à
 * 5 min à 24 °C et remonte à 8 min 30 à 18 °C.
 */
const TEMP_Q10 = 2.5;

/** Température de référence des notices, en degrés Celsius. */
export const REFERENCE_TEMP_C = 20;

/**
 * Multiplicateur à appliquer pour développer à une autre température que
 * celle de la notice. Au-dessus de 20 °C il est inférieur à 1.
 */
export function temperatureFactor(tempC: number, referenceTempC = REFERENCE_TEMP_C): number {
  if (!Number.isFinite(tempC)) return 1;
  return Math.pow(TEMP_Q10, (referenceTempC - tempC) / 10);
}

/**
 * Multiplicateur lié au push/pull.
 *
 * Un diaphragme poussé rallonge d'environ 35 %, un diaphragme retenu raccourcit
 * d'un quart ; on prolonge continûment ces deux règles empiriques.
 */
export function pushPullFactor(stops: number): number {
  if (!Number.isFinite(stops) || stops === 0) return 1;
  return stops > 0 ? Math.pow(1.35, stops) : Math.pow(0.75, -stops);
}

export interface DevTimeResult {
  /** Temps de la notice, en secondes. */
  baseSec: number;
  /** Temps corrigé à appliquer, en secondes. */
  correctedSec: number;
  temperatureFactor: number;
  pushPullFactor: number;
  /** Avertissements à afficher à l'utilisateur. */
  warnings: string[];
}

export function developmentTime(
  baseSec: number,
  options: {
    tempC?: number;
    referenceTempC?: number;
    pushPullStops?: number;
  } = {},
): DevTimeResult {
  const { tempC = REFERENCE_TEMP_C, referenceTempC = REFERENCE_TEMP_C, pushPullStops = 0 } = options;

  const tFactor = temperatureFactor(tempC, referenceTempC);
  const ppFactor = pushPullFactor(pushPullStops);
  const correctedSec = baseSec * tFactor * ppFactor;

  const warnings: string[] = [];
  // En dessous de cinq minutes, la moindre irrégularité d'agitation ou de
  // versement se voit sur le négatif.
  if (correctedSec > 0 && correctedSec < 300) {
    warnings.push(
      'Sous 5 minutes, le développement devient difficile à rendre homogène : ' +
        'préférer une dilution plus forte ou une température plus basse.',
    );
  }
  if (tempC > 24) {
    warnings.push('Au-delà de 24 °C, le grain se creuse et l’émulsion se ramollit.');
  }
  if (tempC < 18) {
    warnings.push('Sous 18 °C, la plupart des révélateurs deviennent paresseux et irréguliers.');
  }
  if (pushPullStops >= 3) {
    warnings.push('Au-delà de +2 IL, le contraste grimpe fortement et les ombres se bouchent.');
  }

  return { baseSec, correctedSec, temperatureFactor: tFactor, pushPullFactor: ppFactor, warnings };
}

/** Formate une durée de développement en « 9 min 45 s ». */
export function formatDevTime(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return '—';
  const total = Math.round(seconds);
  const minutes = Math.floor(total / 60);
  const secs = total % 60;
  if (minutes === 0) return `${secs} s`;
  return secs === 0 ? `${minutes} min` : `${minutes} min ${String(secs).padStart(2, '0')} s`;
}

/** Analyse une saisie libre de durée : « 9:45 », « 9 min 45 », « 585 ». */
export function parseDevTime(input: string): number | null {
  const text = input.trim().toLowerCase();
  if (!text) return null;

  const colon = text.match(/^(\d+)\s*[:’']\s*(\d{1,2})$/);
  if (colon) return Number(colon[1]) * 60 + Number(colon[2]);

  const written = text.match(/^(\d+)\s*(?:min|m)\s*(\d{1,2})?\s*(?:s|sec)?$/);
  if (written) return Number(written[1]) * 60 + Number(written[2] ?? 0);

  const seconds = text.match(/^(\d+)\s*(?:s|sec)$/);
  if (seconds) return Number(seconds[1]);

  const bare = Number(text);
  return Number.isFinite(bare) && bare > 0 ? bare : null;
}

/** Révélateurs courants, proposés en autocomplétion du journal de développement. */
export const COMMON_DEVELOPERS = [
  'Kodak D-76',
  'Kodak HC-110',
  'Kodak XTOL',
  'Ilford ID-11',
  'Ilford DD-X',
  'Ilford Ilfosol 3',
  'Ilford Microphen',
  'Adox Rodinal',
  'Adox XT-3',
  'Bellini Eco Film',
  'Foma Fomadon',
  'Cinestill Df96 (monobain)',
];

/** Dilutions habituelles, proposées à la saisie. */
export const COMMON_DILUTIONS = ['Pur', '1+1', '1+2', '1+3', '1+4', '1+9', '1+25', '1+50', '1+100'];
