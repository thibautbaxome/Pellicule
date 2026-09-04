/**
 * Modèle de données de Pellicule.
 *
 * Tout est stocké en local (IndexedDB). Aucune donnée ne quitte le téléphone.
 * Les identifiants sont des chaînes (crypto.randomUUID) pour que les exports
 * JSON restent réimportables tels quels sur un autre appareil.
 */

export type ID = string;

/** Toutes les dates sont sérialisées en ISO 8601 (UTC). */
export type ISODate = string;

// ---------------------------------------------------------------------------
// Matériel
// ---------------------------------------------------------------------------

export interface Camera {
  id: ID;
  /** Nom affiché, ex. « Nikon FM2 ». */
  name: string;
  make?: string;
  model?: string;
  /** Numéro de série, utile pour l'assurance et les EXIF. */
  serial?: string;
  /** Monture, sert à filtrer les objectifs compatibles. */
  mount?: string;
  /** Décalage systématique du posemètre du boîtier, en IL. */
  meterBiasStops?: number;
  notes?: string;
  archived: boolean;
  createdAt: ISODate;
  updatedAt: ISODate;
}

export interface Lens {
  id: ID;
  /** Nom affiché, ex. « Nikkor 50mm f/1.4 ». */
  name: string;
  make?: string;
  model?: string;
  serial?: string;
  mount?: string;
  /** Focale mini en mm. Égale à focalMax pour une focale fixe. */
  focalMin: number;
  /** Focale maxi en mm. */
  focalMax: number;
  /** Ouverture maximale (le plus petit nombre), ex. 1.4. */
  maxAperture?: number;
  /** Ouverture minimale (le plus grand nombre), ex. 16. */
  minAperture?: number;
  /** Diamètre de filtre en mm, ex. 52. */
  filterThread?: number;
  notes?: string;
  archived: boolean;
  createdAt: ISODate;
  updatedAt: ISODate;
}

export const isPrime = (lens: Lens): boolean => lens.focalMin === lens.focalMax;

// ---------------------------------------------------------------------------
// Pellicules
// ---------------------------------------------------------------------------

export type FilmType = 'bw' | 'color_neg' | 'slide';

export type FilmProcess = 'N&B' | 'C-41' | 'E-6' | 'ECN-2';

/**
 * Correction de réciprocité (loi de Schwarzschild).
 *
 * Sous `thresholdSec`, aucune correction n'est appliquée. Au-delà, le temps
 * corrigé vaut `t^exponent` (t en secondes), la formulation publiée par Ilford
 * et reprise par la plupart des fabricants.
 */
export interface ReciprocityModel {
  /** Exposant de la loi de puissance. 1.0 = film sans défaut de réciprocité. */
  exponent: number;
  /** Seuil en secondes en dessous duquel on ne corrige pas. */
  thresholdSec: number;
  /** Dérive colorimétrique connue, à titre indicatif. */
  colorShiftNote?: string;
}

export interface FilmStock {
  id: ID;
  brand: string;
  name: string;
  /** Sensibilité nominale (ISO boîte). */
  iso: number;
  type: FilmType;
  process: FilmProcess;
  /** Nombre de poses le plus courant pour ce film en 135. */
  defaultExposures: number;
  reciprocity: ReciprocityModel;
  /** Temps de développement de référence, par révélateur. */
  devTimes?: DevTimeReference[];
  notes?: string;
  /** Faux pour les entrées du catalogue livré, vrai pour les ajouts perso. */
  isCustom: boolean;
  discontinued?: boolean;
  createdAt: ISODate;
  updatedAt: ISODate;
}

export interface DevTimeReference {
  developer: string;
  dilution: string;
  /** Sensibilité à laquelle ce temps s'applique. */
  iso: number;
  timeSec: number;
  tempC: number;
}

// ---------------------------------------------------------------------------
// Rouleaux
// ---------------------------------------------------------------------------

/**
 * Cycle de vie d'un rouleau. L'ordre du tableau `ROLL_STATUSES` est celui de
 * la progression normale, ce dont se sert l'interface pour proposer l'étape
 * suivante d'un seul geste.
 */
export type RollStatus =
  | 'loaded'
  | 'shooting'
  | 'finished'
  | 'at_lab'
  | 'developed'
  | 'scanned'
  | 'archived';

export const ROLL_STATUSES: RollStatus[] = [
  'loaded',
  'shooting',
  'finished',
  'at_lab',
  'developed',
  'scanned',
  'archived',
];

export const ROLL_STATUS_LABELS: Record<RollStatus, string> = {
  loaded: 'Chargé',
  shooting: 'En cours',
  finished: 'Terminé',
  at_lab: 'Au labo',
  developed: 'Développé',
  scanned: 'Scanné',
  archived: 'Archivé',
};

/** Un rouleau est « ouvert » tant qu'on peut encore y ajouter des vues. */
export const isRollOpen = (status: RollStatus): boolean =>
  status === 'loaded' || status === 'shooting';

export interface Development {
  /** Développé par soi-même plutôt qu'au labo. */
  self: boolean;
  developer?: string;
  dilution?: string;
  timeSec?: number;
  tempC?: number;
  agitation?: string;
  developedAt?: ISODate;
  notes?: string;
}

export interface RollCosts {
  film?: number;
  development?: number;
  scan?: number;
  prints?: number;
}

export interface Roll {
  id: ID;
  /** Libellé libre, ex. « Week-end à Belle-Île ». Facultatif. */
  label?: string;
  filmStockId: ID;
  cameraId: ID;
  /**
   * Sensibilité réellement utilisée à la prise de vue. Si elle diffère de
   * l'ISO nominal du film, le rouleau est poussé ou retenu et le
   * développement devra être adapté.
   */
  shotIso: number;
  /** Nombre de poses prévues (24, 36...). */
  exposures: number;
  loadedAt: ISODate;
  finishedAt?: ISODate;
  status: RollStatus;
  /** Référence de classement une fois archivé, ex. « 2026-014 ». */
  archiveRef?: string;
  lab?: string;
  development?: Development;
  costs?: RollCosts;
  notes?: string;
  createdAt: ISODate;
  updatedAt: ISODate;
}

// ---------------------------------------------------------------------------
// Vues
// ---------------------------------------------------------------------------

export interface GeoLocation {
  lat: number;
  lon: number;
  /** Précision horizontale en mètres, telle que rendue par le GPS. */
  accuracy?: number;
  altitude?: number;
  /** Libellé saisi ou résolu, ex. « Pointe du Raz ». */
  label?: string;
}

export interface FilterUsed {
  name: string;
  /** Facteur du filtre exprimé en IL (diaphragmes). */
  factorStops: number;
}

export type FrameStatus = 'shot' | 'keep' | 'reject' | 'printed';

export const FRAME_STATUS_LABELS: Record<FrameStatus, string> = {
  shot: 'Prise',
  keep: 'À tirer',
  reject: 'Ratée',
  printed: 'Tirée',
};

export interface Frame {
  id: ID;
  rollId: ID;
  /** Numéro de vue sur le rouleau, à partir de 1. */
  number: number;
  shotAt: ISODate;

  /** Vitesse sous forme canonique, ex. « 1/125 », « 2s », « B ». */
  shutter?: string;
  /** Ouverture numérique, ex. 5.6. */
  aperture?: number;
  lensId?: ID;
  /** Focale utilisée en mm (utile sur un zoom). */
  focal?: number;

  /** Correction d'exposition appliquée, en IL. */
  exposureComp?: number;
  meteringNote?: string;
  filter?: FilterUsed;
  flash?: boolean;
  /** Distance de mise au point en mètres. */
  focusDistance?: number;

  subject?: string;
  notes?: string;
  tags: string[];
  location?: GeoLocation;
  /** Conditions de lumière, ex. « plein soleil », « couvert ». */
  lightNote?: string;

  /** Référence vers une photo de repérage prise avec l'iPhone. */
  refPhotoId?: ID;

  status: FrameStatus;
  /** Note de 0 à 5, attribuée après développement. */
  rating?: number;

  createdAt: ISODate;
  updatedAt: ISODate;
}

/**
 * Photo de repérage stockée en binaire dans IndexedDB. Séparée de `Frame`
 * pour que les listes de vues restent légères à charger.
 */
export interface Attachment {
  id: ID;
  blob: Blob;
  mime: string;
  width?: number;
  height?: number;
  createdAt: ISODate;
}

// ---------------------------------------------------------------------------
// Réglages
// ---------------------------------------------------------------------------

export type ThemeMode = 'auto' | 'light' | 'dark' | 'darkroom';

/** Finesse des sélecteurs de vitesse et d'ouverture. */
export type StopIncrement = 'full' | 'half' | 'third';

export interface Settings {
  /** Table à ligne unique : la clé vaut toujours « app ». */
  id: 'app';
  theme: ThemeMode;
  currency: string;
  stopIncrement: StopIncrement;
  /** Géolocaliser automatiquement chaque nouvelle vue. */
  autoGeolocate: boolean;
  defaultCameraId?: ID;
  defaultLensId?: ID;
  defaultFilmStockId?: ID;
  defaultExposures: number;
  defaultLab?: string;
  /** Cercle de confusion en mm pour les calculs de profondeur de champ. */
  circleOfConfusion: number;
  updatedAt: ISODate;
}

export const DEFAULT_SETTINGS: Settings = {
  id: 'app',
  // Sombre par défaut plutôt qu'automatique : une application de prise de vue
  // s'utilise autant au crépuscule qu'en plein jour, et le fond noir chaud est
  // le registre de l'objet lui-même. Le mode clair reste accessible.
  theme: 'dark',
  currency: 'EUR',
  stopIncrement: 'full',
  autoGeolocate: true,
  defaultExposures: 36,
  circleOfConfusion: 0.03,
  updatedAt: '1970-01-01T00:00:00.000Z',
};
